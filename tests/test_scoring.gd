extends SceneTree
## Headless checks for scoring v0. Run from the project root:
##   godot --headless --import --path .
##   godot --headless --path . -s res://tests/test_scoring.gd

const PASS_MARKER := "SCORING TESTS PASSED"

var _failures := 0
var _cfg := ScoringConfig.new()


func _initialize() -> void:
	_test_blur()
	_test_exposure()
	_test_placement()
	_test_stars()
	_test_full_shot()
	_test_coach()
	_test_focus_motor()

	if _failures == 0:
		print(PASS_MARKER)
	else:
		printerr("%d scoring test(s) failed" % _failures)
	quit(1 if _failures > 0 else 0)


func _test_blur() -> void:
	# 85mm f/1.8 focused at 3 m, subject at 3.5 m: clearly soft.
	var wide := PhotoScoring.blur_mm(85.0, 1.8, 3.0, 3.5)
	_near("blur 85mm f/1.8", wide, 0.1967, 0.001)
	_near("focus 85mm f/1.8", PhotoScoring.focus_score(wide, _cfg), 0.0, 0.001)

	# Same miss at f/8 is nearly acceptable.
	var stopped := PhotoScoring.blur_mm(85.0, 8.0, 3.0, 3.5)
	_near("blur 85mm f/8", stopped, 0.04426, 0.0005)
	_near("focus 85mm f/8", PhotoScoring.focus_score(stopped, _cfg), 0.662, 0.005)

	_near("blur on the focus plane", PhotoScoring.blur_mm(50.0, 1.4, 2.0, 2.0), 0.0, 1e-6)


func _test_exposure() -> void:
	_near("EV f/5.6 1/250 ISO 100", PhotoScoring.exposure_value(5.6, 1.0 / 250.0, 100.0), 12.937, 0.01)
	var iso_drop := PhotoScoring.exposure_value(5.6, 1.0 / 250.0, 100.0) - PhotoScoring.exposure_value(5.6, 1.0 / 250.0, 200.0)
	_near("doubling ISO is one stop", iso_drop, 1.0, 1e-4)
	_check("stopping down reads as too dark", PhotoScoring.ev_error(8.0, 1.0 / 250.0, 100.0, 13.0) > 0.0)
	_near("exposure 1 stop off", PhotoScoring.exposure_score(1.0, _cfg), 0.84375, 1e-4)
	_near("exposure 3 stops off", PhotoScoring.exposure_score(-3.0, _cfg), 0.0, 1e-6)


func _test_placement() -> void:
	_near("placement on a thirds point", PhotoScoring.placement_score(Vector2(2.0 / 3.0, 1.0 / 3.0), _cfg), 1.0, 1e-6)
	_near("placement dead center", PhotoScoring.placement_score(Vector2(0.5, 0.5), _cfg), 1.0, 1e-6)
	_check("placement in the corner is poor", PhotoScoring.placement_score(Vector2.ZERO, _cfg) < 0.01)
	_near("placement near a thirds point still scores full", PhotoScoring.placement_score(Vector2(1.0 / 3.0 + 0.04, 1.0 / 3.0), _cfg), 1.0, 1e-6)
	# Worst spot between the center and a thirds point is about 0.118 from both.
	var between := PhotoScoring.placement_score(Vector2(5.0 / 12.0, 5.0 / 12.0), _cfg)
	_check("placement between targets is middling (%.2f)" % between, between > 0.55 and between < 0.75)
	_check("placement off screen is zero", PhotoScoring.placement_score(Vector2(-1.0, -1.0), _cfg) == 0.0 and PhotoScoring.placement_score(Vector2(1.2, 0.5), _cfg) == 0.0)
	_check("placement near the edge is poor", PhotoScoring.placement_score(Vector2(0.05, 0.5), _cfg) < 0.05)


func _test_stars() -> void:
	_check("0.19 is 0 stars", PhotoScoring.stars(0.19, _cfg) == 0)
	_check("0.2 is 1 star", PhotoScoring.stars(0.2, _cfg) == 1)
	_check("0.85 is 4 stars", PhotoScoring.stars(0.85, _cfg) == 4)
	_check("0.9 is 5 stars", PhotoScoring.stars(0.9, _cfg) == 5)


func _test_full_shot() -> void:
	var shot := ShotData.new()
	shot.aperture_n = 5.6
	shot.shutter_s = 1.0 / 250.0
	shot.iso = 100.0
	shot.scene_ev = PhotoScoring.exposure_value(5.6, 1.0 / 250.0, 100.0)
	shot.focus_distance_m = 4.0
	shot.subject_distance_m = 4.0
	shot.subject_screen_pos = Vector2(1.0 / 3.0, 2.0 / 3.0)

	var perfect := PhotoScoring.score(shot, _cfg)
	_near("perfect shot score", perfect.score, 1.0, 1e-4)
	_check("perfect shot is 5 stars", perfect.stars == 5)
	_check("perfect shot tip", perfect.tip == "Nailed it.")

	# Scene 2 EV darker than the settings expect: the photo comes out too dark.
	shot.scene_ev -= 2.0
	var dark := PhotoScoring.score(shot, _cfg)
	_check("underexposed worst pillar is exposure", dark.worst == "exposure")
	_check("underexposed tip says too dark", dark.tip == "2.0 stops too dark.")

	shot.visibility = 0.0
	_near("hidden subject scores 0", PhotoScoring.score(shot, _cfg).score, 0.0, 1e-6)


func _test_coach() -> void:
	var shot := ShotData.new()
	shot.scene_ev = PhotoScoring.exposure_value(shot.aperture_n, shot.shutter_s, shot.iso) + 2.0  # 2 stops too bright
	shot.focus_distance_m = 0.5
	shot.subject_distance_m = 7.0
	shot.subject_screen_pos = Vector2(0.5, 0.5)
	var lines := PhotoCoach.advice(PhotoScoring.score(shot, _cfg), shot, PhotoCamera.Setting.SHUTTER, true)
	_check("coach gives one line per pillar", lines.size() == 4)
	_check("coach flags exposure with the selected dial", not lines[0].ok and "scroll SHUTTER faster (up)" in lines[0].text)
	_check("coach flags focus with distances", not lines[1].ok and "0.5 m" in lines[1].text and "7.0 m" in lines[1].text)
	_check("coach is happy with centered framing", lines[2].ok)
	_check("coach is not all ok yet", not PhotoCoach.all_ok(lines))

	_check("too dark on ISO says turn it up", "scroll ISO up" in PhotoCoach.exposure_hint(1.5, PhotoCamera.Setting.ISO))
	_check("too bright on aperture says close it", "close the APERTURE (scroll up)" in PhotoCoach.exposure_hint(-1.5, PhotoCamera.Setting.APERTURE))
	_check("zoom dial says pick another dial", "Q/E" in PhotoCoach.exposure_hint(-1.5, PhotoCamera.Setting.FOCAL_LENGTH))
	_check("focus dial says pick another dial", "Q/E" in PhotoCoach.exposure_hint(-1.5, PhotoCamera.Setting.FOCUS))

	shot.scene_ev -= 2.0
	shot.focus_distance_m = 7.0
	var fixed := PhotoCoach.advice(PhotoScoring.score(shot, _cfg), shot, PhotoCamera.Setting.SHUTTER, true)
	_check("coach is all ok once fixed", PhotoCoach.all_ok(fixed))
	var lowered := PhotoCoach.advice(PhotoScoring.score(shot, _cfg), shot, PhotoCamera.Setting.ISO, true, false)
	_check("lowered camera: coach asks to raise it first", lowered.size() == 2 and not lowered[0].ok and "Raise your camera" in lowered[0].text and lowered[1].pillar == "exposure")
	_check("coach asks to find the subject", PhotoCoach.advice(PhotoScoring.score(shot, _cfg), shot, PhotoCamera.Setting.ISO, false)[0].text.begins_with("Find"))


func _test_focus_motor() -> void:
	var focus := 0.5
	var steps := 0
	while absf(1.0 / focus - 1.0 / 7.0) > 1e-4 and steps < 200:
		var next := PhotoCamera.step_focus(focus, 7.0, 6.0, 1.0 / 60.0)
		_check_quiet(next >= focus and next <= 7.0 + 1e-4)
		focus = next
		steps += 1
	_check("focus motor reaches 7 m from 0.5 m without overshoot in %d frames" % steps, steps > 10 and steps < 40)
	_near("focus motor moves in diopters", 1.0 / PhotoCamera.step_focus(1.0, 0.5, 6.0, 0.1), 1.6, 1e-4)


func _check_quiet(ok: bool) -> void:
	if not ok:
		_check("focus motor step stays between start and target", false)


func _near(label: String, actual: float, expected: float, tolerance: float) -> void:
	_check("%s (expected %.4f, got %.4f)" % [label, expected, actual], absf(actual - expected) <= tolerance)


func _check(label: String, ok: bool) -> void:
	if ok:
		print("ok    ", label)
	else:
		_failures += 1
		printerr("FAIL  ", label)
