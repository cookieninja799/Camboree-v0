class_name PhotoScoring
extends RefCounted
## Scoring v0: pure functions with no scene access, so they can be tested headless.
##
##   shot = gate * (0.5 * focus + 0.3 * exposure + 0.2 * placement)
##
## Every pillar is a 0-1 float. See docs/design/scoring-v0.md.

const LN2 := 0.6931471805599453


## Scores a shot and returns a breakdown:
## { score, stars, gate, focus, exposure, placement, blur_mm, ev_error, best, worst, tip }
static func score(shot: ShotData, cfg: ScoringConfig) -> Dictionary:
	var blur := blur_mm(shot.focal_length_mm, shot.aperture_n, shot.focus_distance_m, shot.subject_distance_m)
	var ev_err := ev_error(shot.aperture_n, shot.shutter_s, shot.iso, shot.scene_ev)

	var gate := clampf(shot.visibility, 0.0, 1.0)
	var focus := focus_score(blur, cfg)
	var exposure := exposure_score(ev_err, cfg)
	var placement := placement_score(shot.subject_screen_pos, cfg)

	var weight_sum := cfg.focus_weight + cfg.exposure_weight + cfg.placement_weight
	var weighted := cfg.focus_weight * focus + cfg.exposure_weight * exposure + cfg.placement_weight * placement
	var total := gate * weighted / weight_sum if weight_sum > 0.0 else 0.0

	var pillars := {"focus": focus, "exposure": exposure, "placement": placement}
	var best := "focus"
	for key in pillars:
		if pillars[key] > pillars[best]:
			best = key
	# The gate can be the worst pillar but never the best: being visible isn't an achievement.
	pillars["gate"] = gate
	var worst := "gate"
	for key in pillars:
		if pillars[key] < pillars[worst]:
			worst = key

	return {
		"score": total,
		"stars": stars(total, cfg),
		"gate": gate,
		"focus": focus,
		"exposure": exposure,
		"placement": placement,
		"blur_mm": blur,
		"ev_error": ev_err,
		"best": best,
		"worst": worst,
		"tip": tip(worst, pillars[worst], shot, ev_err),
	}


## Blur-circle diameter in mm for a point at subject_m when focused at focus_m (thin-lens model).
static func blur_mm(focal_length_mm: float, aperture_n: float, focus_m: float, subject_m: float) -> float:
	var f := focal_length_mm / 1000.0
	var s := maxf(focus_m, f + 0.001)
	var d := maxf(subject_m, 0.001)
	var n := maxf(aperture_n, 0.1)
	return (f * f * absf(d - s)) / (n * d * (s - f)) * 1000.0


static func focus_score(blur: float, cfg: ScoringConfig) -> float:
	return 1.0 - smoothstep(cfg.sharp_coc_mult * cfg.coc_mm, cfg.soft_coc_mult * cfg.coc_mm, blur)


## Exposure value the camera settings call for, normalized to ISO 100.
static func exposure_value(aperture_n: float, shutter_s: float, iso: float) -> float:
	return log2(aperture_n * aperture_n / shutter_s) - log2(iso / 100.0)


## Stops of exposure error. Positive means the photo is too dark.
static func ev_error(aperture_n: float, shutter_s: float, iso: float, scene_ev: float) -> float:
	return exposure_value(aperture_n, shutter_s, iso) - scene_ev


static func exposure_score(error_stops: float, cfg: ScoringConfig) -> float:
	return 1.0 - smoothstep(cfg.exposure_ok_stops, cfg.exposure_bad_stops, absf(error_stops))


## Best Gaussian fit of the subject's screen position to any placement target.
static func placement_score(screen_pos: Vector2, cfg: ScoringConfig) -> float:
	var two_sigma_sq := 2.0 * cfg.placement_sigma * cfg.placement_sigma
	var best := 0.0
	for target in cfg.placement_targets:
		best = maxf(best, exp(-screen_pos.distance_squared_to(target) / two_sigma_sq))
	return best


static func stars(total: float, cfg: ScoringConfig) -> int:
	var count := 0
	for threshold in cfg.star_thresholds:
		if total >= threshold:
			count += 1
	return count


## A one-line coaching note for the weakest pillar.
static func tip(worst: String, worst_value: float, shot: ShotData, ev_err: float) -> String:
	if worst_value >= 0.9:
		return "Nailed it."
	match worst:
		"gate":
			return "Subject is %d%% hidden or out of frame." % roundi((1.0 - shot.visibility) * 100.0)
		"focus":
			var miss := absf(shot.subject_distance_m - shot.focus_distance_m)
			var side := "in front of" if shot.focus_distance_m < shot.subject_distance_m else "behind"
			var line := "Focus landed %.1f m %s the subject." % [miss, side]
			if shot.aperture_n <= 2.8:
				line += " Stop down for more depth of field."
			return line
		"exposure":
			return "%.1f stops too %s." % [absf(ev_err), "dark" if ev_err > 0.0 else "bright"]
		"placement":
			return "Try putting the subject on a rule-of-thirds intersection."
	return ""


static func log2(x: float) -> float:
	return log(x) / LN2


static func format_aperture(n: float) -> String:
	return "f/" + ("%.1f" % n).trim_suffix(".0")


static func format_shutter(seconds: float) -> String:
	if seconds >= 1.0:
		return ("%.1f" % seconds).trim_suffix(".0") + "s"
	return "1/%d" % roundi(1.0 / seconds)
