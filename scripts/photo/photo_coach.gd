class_name PhotoCoach
extends RefCounted
## Live "fix your camera" advice for the tutorial. Feed it the score of what the
## camera would capture right now and it returns one line per pillar, phrased
## around the dial the player has selected. Pure functions, no scene access.

## A pillar at or above this counts as fixed.
const GOOD := 0.8


## One entry per pillar: { "pillar": String, "ok": bool, "text": String }.
## `subject_found` is false when no subject is in view at all. `raised` is false
## while the player is exploring with the camera lowered: then the coach asks them
## to raise it, but exposure can already be fixed ahead of time. With a `cfg`,
## motion and noise get lines too when the config weighs them. `subject` is
## how the brief names its subject, and `flyer` means it comes and goes, so
## when it's out of sight the coach says to wait rather than to look for it.
static func advice(result: Dictionary, shot: ShotData, selected: PhotoCamera.Setting, subject_found: bool, raised := true, cfg: ScoringConfig = null, subject := "the wanderer", flyer := false) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	if not raised:
		lines.append(_line("raise", false, "Raise your camera: hold RMB (LT)"))
		lines.append(_line("exposure", result.exposure >= GOOD, "Exposure" if result.exposure >= GOOD else exposure_hint(result.ev_error, selected, shot, cfg)))
		return lines
	if not subject_found:
		var find := "Wait for %s, it flies past every few seconds" % subject if flyer else "Find %s (the orange capsule)" % subject
		lines.append(_line("gate", false, find))
		lines.append(_line("exposure", result.exposure >= GOOD, "Exposure" if result.exposure >= GOOD else exposure_hint(result.ev_error, selected, shot, cfg)))
		return lines

	lines.append(_line("exposure", result.exposure >= GOOD,
		"Exposure" if result.exposure >= GOOD else exposure_hint(result.ev_error, selected, shot, cfg)))
	lines.append(_line("focus", result.focus >= GOOD,
		"Focus" if result.focus >= GOOD else focus_hint(shot, subject)))
	lines.append(_line("placement", result.placement >= GOOD,
		"Framing" if result.placement >= GOOD else "Framing: put %s's head inside one of the circles" % subject))
	if cfg and cfg.motion_weight > 0.0:
		lines.append(_line("motion", result.motion >= GOOD,
			"Motion" if result.motion >= GOOD else motion_hint(shot, selected, cfg)))
	if cfg and cfg.noise_weight > 0.0:
		lines.append(_line("noise", result.noise >= GOOD,
			"Noise" if result.noise >= GOOD else noise_hint(shot, selected, cfg)))
	lines.append(_line("gate", result.gate >= GOOD,
		"In view" if result.gate >= GOOD else "In view: part of %s is hidden or out of frame" % subject))
	return lines


static func all_ok(lines: Array[Dictionary]) -> bool:
	for line in lines:
		if not line.ok:
			return false
	return true


## What to do about exposure. Scrolling up turns a dial to its next value: up on
## ISO is brighter; up on SHUTTER (faster) and APERTURE (bigger f-number) is darker.
##
## With the `shot`, the advice looks at where every dial sits and picks the
## best one to turn, never one that's already at its end:
## - Too dark: open the aperture first, then slow the shutter (only while that
##   won't blur a moving subject), and raise ISO last, only up to the grain limit.
## - Too bright: lower ISO first (that also cuts grain), then a faster shutter,
##   then close the aperture.
## Without a shot it falls back to the selected dial.
static func exposure_hint(ev_error: float, selected: PhotoCamera.Setting, shot: ShotData = null, cfg: ScoringConfig = null) -> String:
	var too_bright := ev_error < 0.0
	var problem := "Exposure: %.1f stops too %s" % [absf(ev_error), "bright" if too_bright else "dark"]
	if shot == null:
		match selected:
			PhotoCamera.Setting.ISO, PhotoCamera.Setting.SHUTTER, PhotoCamera.Setting.APERTURE:
				return problem + _turn(selected, too_bright, true)
		return problem + " · pick ISO (1), SHUTTER (2) or APERTURE (3)"

	var options := _exposure_options(too_bright, shot, cfg)
	if options.is_empty():
		if too_bright:
			return problem + " · every dial is at its darkest"
		return problem + " · the aperture is wide open and the shutter is as slow as the subject allows; take it a bit dark, or accept more grain with a higher ISO"
	# Turning the dial that's already selected is fine if it's one of the good options.
	var pick: PhotoCamera.Setting = selected if options.has(selected) else options[0]
	return problem + _turn(pick, too_bright, pick == selected)


## Dials that can still fix the exposure, best first.
static func _exposure_options(too_bright: bool, shot: ShotData, cfg: ScoringConfig) -> Array:
	var options := []
	var widest: float = PhotoCamera.APERTURES[0]
	var narrowest: float = PhotoCamera.APERTURES[-1]
	var slowest: float = PhotoCamera.SHUTTERS[0]
	var fastest: float = PhotoCamera.SHUTTERS[-1]
	var lowest_iso: float = PhotoCamera.ISOS[0]
	if too_bright:
		if shot.iso > lowest_iso * 1.01:
			options.append(PhotoCamera.Setting.ISO)
		if shot.shutter_s > fastest * 1.01:
			options.append(PhotoCamera.Setting.SHUTTER)
		if shot.aperture_n < narrowest * 0.99:
			options.append(PhotoCamera.Setting.APERTURE)
		return options
	if shot.aperture_n > widest * 1.01:
		options.append(PhotoCamera.Setting.APERTURE)
	if shot.shutter_s * 1.9 <= minf(slowest, slowest_steady_shutter(shot, cfg)):
		options.append(PhotoCamera.Setting.SHUTTER)
	if shot.iso * 1.9 <= max_clean_iso(cfg):
		options.append(PhotoCamera.Setting.ISO)
	return options


## The slowest shutter that won't visibly blur the subject: its freeze speed
## when the brief scores motion and the subject moves, otherwise 1/30 s
## (hand-held). Never slower than that.
static func slowest_steady_shutter(shot: ShotData, cfg: ScoringConfig) -> float:
	var steady := 1.0 / 30.0
	if cfg and cfg.motion_weight > 0.0 and shot.subject_speed_mps > 0.0:
		steady = minf(steady, PhotoScoring.freeze_shutter_s(shot.focal_length_mm, shot.subject_distance_m, shot.subject_speed_mps, cfg))
	return steady


## The highest ISO the coach will suggest raising to: the highest dial ISO
## whose noise the coach still marks OK (ISO 800 by default). Going past it
## would just trade the exposure warning for a noise one.
static func max_clean_iso(cfg: ScoringConfig) -> float:
	var c := cfg if cfg else ScoringConfig.new()
	var best: float = PhotoCamera.ISOS[0]
	for iso in PhotoCamera.ISOS:
		if PhotoScoring.noise_score(iso, c) >= GOOD:
			best = iso
	return best


## " · scroll ISO up" when that dial is selected, else how to get to it.
static func _turn(setting: PhotoCamera.Setting, too_bright: bool, is_selected: bool) -> String:
	var action := ""
	var direction := ""
	match setting:
		PhotoCamera.Setting.ISO:
			action = "lower ISO" if too_bright else "raise ISO"
			direction = "down" if too_bright else "up"
			if is_selected:
				return " · scroll ISO %s" % direction
			return " · %s: pick ISO (1) and scroll %s" % [action, direction]
		PhotoCamera.Setting.SHUTTER:
			direction = "up" if too_bright else "down"
			if is_selected:
				return " · scroll SHUTTER %s (%s)" % ["faster" if too_bright else "slower", direction]
			return " · %s the SHUTTER: pick it (2) and scroll %s" % ["speed up" if too_bright else "slow down", direction]
		_:
			direction = "up" if too_bright else "down"
			if is_selected:
				return " · %s the APERTURE (scroll %s)" % ["close" if too_bright else "open", direction]
			return " · %s the APERTURE: pick it (3) and scroll %s" % ["close" if too_bright else "open", direction]


static func focus_hint(shot: ShotData, subject := "the wanderer") -> String:
	return "Focus: at %.1f m, but %s is %.1f m away · press Shift to autofocus, or turn the FOCUS dial" % [
		shot.focus_distance_m, subject, shot.subject_distance_m,
	]


## The subject is moving too fast for the shutter. Faster shutter first; if the
## dial is already at its fastest, a shorter lens shrinks the smear instead.
static func motion_hint(shot: ShotData, selected: PhotoCamera.Setting, cfg: ScoringConfig) -> String:
	var freeze := PhotoScoring.freeze_shutter_s(shot.focal_length_mm, shot.subject_distance_m, shot.subject_speed_mps, cfg)
	var needed := PhotoScoring.dial_shutter_at_most(freeze)
	var problem := "Motion: subject is moving, it needs %s or faster" % PhotoScoring.format_shutter(needed)
	if not at_fastest_shutter(shot):
		if selected == PhotoCamera.Setting.SHUTTER:
			return problem + " · scroll SHUTTER faster (up)"
		return problem + " · speed up the SHUTTER: pick it (2) and scroll up"
	problem = "Motion: the shutter is already at its fastest"
	if not at_widest_zoom(shot):
		if selected == PhotoCamera.Setting.FOCAL_LENGTH:
			return problem + " · scroll ZOOM out (down) so it smears less"
		return problem + " · zoom out so it smears less: pick ZOOM (4) and scroll down"
	return problem + " and fully zoomed out · wait for it to come by slower or farther away"


## Too much ISO. Lowering it darkens the shot, so the hint names what can make
## up the light: a wider aperture, else a slower shutter, else nothing.
static func noise_hint(shot: ShotData, selected: PhotoCamera.Setting, cfg: ScoringConfig = null) -> String:
	var problem := "Noise: grainy at ISO %d" % roundi(shot.iso)
	var lower := " · scroll ISO down" if selected == PhotoCamera.Setting.ISO else " · lower ISO: pick ISO (1) and scroll down"
	if not at_widest_aperture(shot):
		return problem + lower + ", then open the APERTURE (3) to keep it bright"
	if shot.shutter_s * 1.9 <= minf(PhotoCamera.SHUTTERS[0], slowest_steady_shutter(shot, cfg)):
		return problem + lower + ", then slow the SHUTTER (2) to keep it bright"
	return problem + lower + " · the aperture is wide open and the shutter can't go slower, so it'll come out darker"


static func at_fastest_shutter(shot: ShotData) -> bool:
	return shot.shutter_s <= PhotoCamera.SHUTTERS[-1] * 1.01


static func at_widest_aperture(shot: ShotData) -> bool:
	return shot.aperture_n <= PhotoCamera.APERTURES[0] * 1.01


static func at_widest_zoom(shot: ShotData) -> bool:
	return shot.focal_length_mm <= PhotoCamera.FOCAL_LENGTHS[0] + 0.5


static func _line(pillar: String, ok: bool, text: String) -> Dictionary:
	return {"pillar": pillar, "ok": ok, "text": text}
