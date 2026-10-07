class_name PhotoScoring
extends RefCounted
## Scoring v1: pure functions with no scene access, so they can be tested headless.
##
##   shot = gate * weighted mean of (focus, exposure, placement, motion, noise)
##
## Every pillar is a 0-1 float. The weights come from the ScoringConfig, so each
## brief decides what matters; a pillar with weight 0 is left out entirely (no
## best/worst, no tip). The default config weighs focus 0.5, exposure 0.3,
## placement 0.2. See docs/design/scoring-v1.md.

const LN2 := 0.6931471805599453
## Weighted pillars in the order ties are broken for "best".
const PILLARS := ["focus", "exposure", "placement", "motion", "noise"]


## Scores a shot and returns a breakdown:
## { score, stars, gate, focus, exposure, placement, motion, noise, blur_mm,
##   motion_blur_mm, ev_error, best, worst, tip }
static func score(shot: ShotData, cfg: ScoringConfig) -> Dictionary:
	var blur := blur_mm(shot.focal_length_mm, shot.aperture_n, shot.focus_distance_m, shot.subject_distance_m)
	var smear := motion_blur_mm(shot.focal_length_mm, shot.subject_distance_m, shot.subject_speed_mps, shot.shutter_s)
	var ev_err := ev_error(shot.aperture_n, shot.shutter_s, shot.iso, shot.scene_ev)

	var gate := clampf(shot.visibility, 0.0, 1.0)
	var values := {
		"focus": focus_score(blur, cfg),
		"exposure": exposure_score(ev_err, cfg),
		"placement": placement_score(shot.subject_screen_pos, cfg),
		"motion": motion_score(smear, cfg),
		"noise": noise_score(shot.iso, cfg),
	}

	var weight_sum := 0.0
	var weighted := 0.0
	var pillars := {}  # only the weighted ones take part in best/worst
	for key in PILLARS:
		var w := cfg.weight(key)
		if w <= 0.0:
			continue
		weight_sum += w
		weighted += w * values[key]
		pillars[key] = values[key]
	var total := gate * weighted / weight_sum if weight_sum > 0.0 else 0.0

	var best := ""
	for key in pillars:
		if best == "" or pillars[key] > pillars[best]:
			best = key
	# The gate can be the worst pillar but never the best: being visible isn't an achievement.
	pillars["gate"] = gate
	var worst := "gate"
	for key in pillars:
		if pillars[key] < pillars[worst]:
			worst = key

	var result := {
		"score": total,
		"stars": stars(total, cfg),
		"gate": gate,
		"blur_mm": blur,
		"motion_blur_mm": smear,
		"ev_error": ev_err,
		"best": best,
		"worst": worst,
		"tip": tip(worst, pillars[worst], shot, ev_err, cfg),
	}
	result.merge(values)
	return result


## Blur-circle diameter in mm for a point at subject_m when focused at focus_m (thin-lens model).
static func blur_mm(focal_length_mm: float, aperture_n: float, focus_m: float, subject_m: float) -> float:
	var f := focal_length_mm / 1000.0
	var s := maxf(focus_m, f + 0.001)
	var d := maxf(subject_m, 0.001)
	var n := maxf(aperture_n, 0.1)
	return (f * f * absf(d - s)) / (n * d * (s - f)) * 1000.0


static func focus_score(blur: float, cfg: ScoringConfig) -> float:
	return 1.0 - smoothstep(cfg.sharp_coc_mult * cfg.coc_mm, cfg.soft_coc_mult * cfg.coc_mm, blur)


## How far the subject's image smears across the sensor while the shutter is
## open, in mm: magnification m = f / (d - f) times speed times exposure time.
static func motion_blur_mm(focal_length_mm: float, subject_m: float, speed_mps: float, shutter_s: float) -> float:
	var f := focal_length_mm / 1000.0
	var d := maxf(subject_m, f + 0.001)
	return f / (d - f) * absf(speed_mps) * shutter_s * 1000.0


static func motion_score(smear_mm: float, cfg: ScoringConfig) -> float:
	return 1.0 - smoothstep(cfg.motion_tol_mm, 3.0 * cfg.motion_tol_mm, smear_mm)


## Slowest shutter (seconds) that keeps the smear within tolerance, or INF for a still subject.
static func freeze_shutter_s(focal_length_mm: float, subject_m: float, speed_mps: float, cfg: ScoringConfig) -> float:
	var smear_per_second := motion_blur_mm(focal_length_mm, subject_m, speed_mps, 1.0)
	return cfg.motion_tol_mm / smear_per_second if smear_per_second > 0.0 else INF


## The slowest shutter on the dial that is at least as fast as `seconds`
## (the fastest one if none is).
static func dial_shutter_at_most(seconds: float) -> float:
	for value in PhotoCamera.SHUTTERS:
		if value <= seconds:
			return value
	return PhotoCamera.SHUTTERS[-1]


## Sensor noise: free up to noise_ok_stops above ISO 100, gone by noise_bad_stops.
static func noise_score(iso: float, cfg: ScoringConfig) -> float:
	return 1.0 - smoothstep(cfg.noise_ok_stops, cfg.noise_bad_stops, log2(maxf(iso, 1.0) / 100.0))


## Exposure value the camera settings call for, normalized to ISO 100.
static func exposure_value(aperture_n: float, shutter_s: float, iso: float) -> float:
	return log2(aperture_n * aperture_n / shutter_s) - log2(iso / 100.0)


## Stops of exposure error. Positive means the photo is too dark.
static func ev_error(aperture_n: float, shutter_s: float, iso: float, scene_ev: float) -> float:
	return exposure_value(aperture_n, shutter_s, iso) - scene_ev


static func exposure_score(error_stops: float, cfg: ScoringConfig) -> float:
	return 1.0 - smoothstep(cfg.exposure_ok_stops, cfg.exposure_bad_stops, absf(error_stops))


## Framing: full marks inside the ok radius of the nearest target, easing to 0
## at the bad radius.
static func placement_score(screen_pos: Vector2, cfg: ScoringConfig) -> float:
	if not Rect2(0.0, 0.0, 1.0, 1.0).has_point(screen_pos):
		return 0.0  # the subject isn't in the frame at all
	var nearest := INF
	for target in cfg.placement_targets:
		nearest = minf(nearest, screen_pos.distance_to(target))
	return 1.0 - smoothstep(cfg.placement_ok_radius, cfg.placement_bad_radius, nearest)


static func stars(total: float, cfg: ScoringConfig) -> int:
	var count := 0
	for threshold in cfg.star_thresholds:
		if total >= threshold:
			count += 1
	return count


## A one-line coaching note for the weakest pillar.
static func tip(worst: String, worst_value: float, shot: ShotData, ev_err: float, cfg: ScoringConfig) -> String:
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
			return "%.1f stops too %s.%s" % [absf(ev_err), "dark" if ev_err > 0.0 else "bright", _exposure_next_time(ev_err, shot, cfg)]
		"placement":
			return "Try putting the subject on a rule-of-thirds intersection."
		"motion":
			if PhotoCoach.at_fastest_shutter(shot):
				if PhotoCoach.at_widest_zoom(shot):
					return "Subject is moving faster than the shutter can freeze. Wait for a slower pass."
				return "Subject is moving and the shutter is maxed out. Zoom out so it smears less."
			var needed := freeze_shutter_s(shot.focal_length_mm, shot.subject_distance_m, shot.subject_speed_mps, cfg)
			return "Subject is moving. Try a faster shutter (%s or faster)." % format_shutter(dial_shutter_at_most(needed))
		"noise":
			if not PhotoCoach.at_widest_aperture(shot):
				return "Grainy at ISO %d. Lower the ISO and open up the aperture to make up the light." % roundi(shot.iso)
			return "Grainy at ISO %d. Lower the ISO and use a slower shutter to make up the light." % roundi(shot.iso)
	return ""


## " Next time, open the aperture." using the coach's dial-aware order, or "".
static func _exposure_next_time(ev_err: float, shot: ShotData, cfg: ScoringConfig) -> String:
	var options := PhotoCoach._exposure_options(ev_err < 0.0, shot, cfg)
	if options.is_empty():
		return ""
	var too_bright := ev_err < 0.0
	match options[0]:
		PhotoCamera.Setting.ISO:
			return " Next time, %s the ISO." % ("lower" if too_bright else "raise")
		PhotoCamera.Setting.SHUTTER:
			return " Next time, use a %s shutter." % ("faster" if too_bright else "slower")
	return " Next time, %s the aperture." % ("close" if too_bright else "open")


static func log2(x: float) -> float:
	return log(x) / LN2


static func format_aperture(n: float) -> String:
	return "f/" + ("%.1f" % n).trim_suffix(".0")


static func format_shutter(seconds: float) -> String:
	if seconds >= 1.0:
		return ("%.1f" % seconds).trim_suffix(".0") + "s"
	return "1/%d" % roundi(1.0 / seconds)
