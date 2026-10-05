class_name PhotoCoach
extends RefCounted
## Live "fix your camera" advice for the tutorial. Feed it the score of what the
## camera would capture right now and it returns one line per pillar, phrased
## around the dial the player has selected. Pure functions, no scene access.

## A pillar at or above this counts as fixed.
const GOOD := 0.8


## One entry per pillar: { "pillar": String, "ok": bool, "text": String }.
## `subject_found` is false when no subject is in view at all.
static func advice(result: Dictionary, shot: ShotData, selected: PhotoCamera.Setting, subject_found: bool) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	if not subject_found:
		lines.append(_line("gate", false, "Find the wanderer (the orange capsule)"))
		lines.append(_line("exposure", result.exposure >= GOOD, "Exposure" if result.exposure >= GOOD else exposure_hint(result.ev_error, selected)))
		return lines

	lines.append(_line("exposure", result.exposure >= GOOD,
		"Exposure" if result.exposure >= GOOD else exposure_hint(result.ev_error, selected)))
	lines.append(_line("focus", result.focus >= GOOD,
		"Focus" if result.focus >= GOOD else focus_hint(shot)))
	lines.append(_line("placement", result.placement >= GOOD,
		"Framing" if result.placement >= GOOD else "Framing: put the wanderer's head inside one of the circles"))
	lines.append(_line("gate", result.gate >= GOOD,
		"In view" if result.gate >= GOOD else "In view: part of the wanderer is hidden or out of frame"))
	return lines


static func all_ok(lines: Array[Dictionary]) -> bool:
	for line in lines:
		if not line.ok:
			return false
	return true


## What to do about exposure with the dial that's selected. R turns a dial up
## (next value), F turns it down. Up on ISO is brighter; up on SHUTTER (faster)
## and APERTURE (bigger f-number) is darker.
static func exposure_hint(ev_error: float, selected: PhotoCamera.Setting) -> String:
	var too_bright := ev_error < 0.0
	var problem := "Exposure: %.1f stops too %s" % [absf(ev_error), "bright" if too_bright else "dark"]
	match selected:
		PhotoCamera.Setting.ISO:
			return problem + (" · turn ISO down (F)" if too_bright else " · turn ISO up (R)")
		PhotoCamera.Setting.SHUTTER:
			return problem + (" · make SHUTTER faster (R)" if too_bright else " · make SHUTTER slower (F)")
		PhotoCamera.Setting.APERTURE:
			return problem + (" · close the APERTURE (R)" if too_bright else " · open the APERTURE (F)")
	return problem + " · pick ISO, SHUTTER or APERTURE with Q/E"


static func focus_hint(shot: ShotData) -> String:
	return "Focus: at %.1f m, but the wanderer is %.1f m away · aim at them and right-click (autofocus)" % [
		shot.focus_distance_m, shot.subject_distance_m,
	]


static func _line(pillar: String, ok: bool, text: String) -> Dictionary:
	return {"pillar": pillar, "ok": ok, "text": text}
