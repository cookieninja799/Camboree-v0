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
		lines.append(_line("exposure", result.exposure >= GOOD, "Exposure" if result.exposure >= GOOD else exposure_hint(result.ev_error, selected)))
		return lines
	if not subject_found:
		var find := "Wait for %s, it flies past every few seconds" % subject if flyer else "Find %s (the orange capsule)" % subject
		lines.append(_line("gate", false, find))
		lines.append(_line("exposure", result.exposure >= GOOD, "Exposure" if result.exposure >= GOOD else exposure_hint(result.ev_error, selected)))
		return lines

	lines.append(_line("exposure", result.exposure >= GOOD,
		"Exposure" if result.exposure >= GOOD else exposure_hint(result.ev_error, selected)))
	lines.append(_line("focus", result.focus >= GOOD,
		"Focus" if result.focus >= GOOD else focus_hint(shot, subject)))
	lines.append(_line("placement", result.placement >= GOOD,
		"Framing" if result.placement >= GOOD else "Framing: put %s's head inside one of the circles" % subject))
	if cfg and cfg.motion_weight > 0.0:
		lines.append(_line("motion", result.motion >= GOOD,
			"Motion" if result.motion >= GOOD else motion_hint(shot, selected, cfg)))
	if cfg and cfg.noise_weight > 0.0:
		lines.append(_line("noise", result.noise >= GOOD,
			"Noise" if result.noise >= GOOD else noise_hint(shot, selected)))
	lines.append(_line("gate", result.gate >= GOOD,
		"In view" if result.gate >= GOOD else "In view: part of %s is hidden or out of frame" % subject))
	return lines


static func all_ok(lines: Array[Dictionary]) -> bool:
	for line in lines:
		if not line.ok:
			return false
	return true


## What to do about exposure with the dial that's selected. Scrolling up turns a
## dial to its next value. Up on ISO is brighter; up on SHUTTER (faster) and
## APERTURE (bigger f-number) is darker.
static func exposure_hint(ev_error: float, selected: PhotoCamera.Setting) -> String:
	var too_bright := ev_error < 0.0
	var problem := "Exposure: %.1f stops too %s" % [absf(ev_error), "bright" if too_bright else "dark"]
	match selected:
		PhotoCamera.Setting.ISO:
			return problem + (" · scroll ISO down" if too_bright else " · scroll ISO up")
		PhotoCamera.Setting.SHUTTER:
			return problem + (" · scroll SHUTTER faster (up)" if too_bright else " · scroll SHUTTER slower (down)")
		PhotoCamera.Setting.APERTURE:
			return problem + (" · close the APERTURE (scroll up)" if too_bright else " · open the APERTURE (scroll down)")
	return problem + " · pick ISO (1), SHUTTER (2) or APERTURE (3)"


static func focus_hint(shot: ShotData, subject := "the wanderer") -> String:
	return "Focus: at %.1f m, but %s is %.1f m away · press Shift to autofocus, or turn the FOCUS dial" % [
		shot.focus_distance_m, subject, shot.subject_distance_m,
	]


## The subject is moving too fast for the shutter.
static func motion_hint(shot: ShotData, selected: PhotoCamera.Setting, cfg: ScoringConfig) -> String:
	var needed := PhotoScoring.dial_shutter_at_most(PhotoScoring.freeze_shutter_s(shot.focal_length_mm, shot.subject_distance_m, shot.subject_speed_mps, cfg))
	var problem := "Motion: subject is moving, it needs %s or faster" % PhotoScoring.format_shutter(needed)
	if selected == PhotoCamera.Setting.SHUTTER:
		return problem + " · scroll SHUTTER faster (up)"
	return problem + " · pick SHUTTER (2)"


## Too much ISO. Lowering it darkens the shot, so pair it with a wider aperture.
static func noise_hint(shot: ShotData, selected: PhotoCamera.Setting) -> String:
	var problem := "Noise: grainy at ISO %d" % roundi(shot.iso)
	match selected:
		PhotoCamera.Setting.ISO:
			return problem + " · scroll ISO down, then open the APERTURE to keep it bright"
		PhotoCamera.Setting.APERTURE:
			return problem + " · open the APERTURE (scroll down) so ISO can come down"
	return problem + " · pick ISO (1) and lower it"


static func _line(pillar: String, ok: bool, text: String) -> Dictionary:
	return {"pillar": pillar, "ok": ok, "text": text}
