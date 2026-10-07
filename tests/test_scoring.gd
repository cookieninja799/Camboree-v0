extends SceneTree
## Headless checks for scoring v1. Run from the project root:
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
	_test_motion()
	_test_noise()
	_test_weights()
	_test_bird_sweep()
	_test_dusk_sweep()
	_test_briefs()
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


func _test_motion() -> void:
	# A 5 m/s runner at 10 m with an 85 mm lens (docs/design/scoring-v1.md).
	var slow := PhotoScoring.motion_blur_mm(85.0, 10.0, 5.0, 1.0 / 125.0)
	_near("motion blur at 1/125", slow, 0.3429, 0.0005)
	_near("motion at 1/125", PhotoScoring.motion_score(slow, _cfg), 0.0, 1e-6)
	var mid := PhotoScoring.motion_blur_mm(85.0, 10.0, 5.0, 1.0 / 250.0)
	_near("motion blur at 1/250", mid, 0.1715, 0.0005)
	_near("motion at 1/250", PhotoScoring.motion_score(mid, _cfg), 0.71, 0.01)
	var fast := PhotoScoring.motion_blur_mm(85.0, 10.0, 5.0, 1.0 / 500.0)
	_near("motion blur at 1/500", fast, 0.0857, 0.0005)
	_near("motion at 1/500", PhotoScoring.motion_score(fast, _cfg), 1.0, 1e-6)
	_near("a still subject doesn't smear", PhotoScoring.motion_blur_mm(200.0, 5.0, 0.0, 1.0), 0.0, 1e-9)
	_check("1/500 freezes the runner", PhotoScoring.dial_shutter_at_most(PhotoScoring.freeze_shutter_s(85.0, 10.0, 5.0, _cfg)) == 1.0 / 500.0)


func _test_noise() -> void:
	_near("noise at ISO 100", PhotoScoring.noise_score(100.0, _cfg), 1.0, 1e-6)
	_near("noise at ISO 400", PhotoScoring.noise_score(400.0, _cfg), 1.0, 1e-6)
	_near("noise at ISO 1600", PhotoScoring.noise_score(1600.0, _cfg), 0.5, 1e-4)
	_near("noise at ISO 6400", PhotoScoring.noise_score(6400.0, _cfg), 0.0, 1e-6)


func _test_weights() -> void:
	var shot := _reference_shot()
	shot.subject_speed_mps = 5.0
	shot.shutter_s = 1.0 / 30.0
	shot.iso = 6400.0
	shot.scene_ev = PhotoScoring.exposure_value(shot.aperture_n, shot.shutter_s, shot.iso)
	var unweighted := PhotoScoring.score(shot, _cfg)
	_check("motion and noise are reported even when unweighted", unweighted.motion == 0.0 and unweighted.noise == 0.0)
	_near("unweighted motion and noise don't cost anything", unweighted.score, 1.0, 1e-4)
	_check("unweighted pillars are never the worst", unweighted.worst != "motion" and unweighted.worst != "noise")

	var cfg := ScoringConfig.new()
	cfg.motion_weight = 0.5
	var weighted := PhotoScoring.score(shot, cfg)
	_near("weights are normalized (motion 0.5 of 1.5)", weighted.score, 1.0 / 1.5, 1e-4)
	_check("smeared shot's worst pillar is motion", weighted.worst == "motion")
	_check("motion tip names a dial shutter", weighted.tip.begins_with("Subject is moving") and "1/1000 or faster" in weighted.tip)

	cfg.motion_weight = 0.0
	cfg.noise_weight = 1.0
	var grainy := PhotoScoring.score(shot, cfg)
	_check("grainy shot's worst pillar is noise", grainy.worst == "noise" and grainy.tip.begins_with("Grainy at ISO 6400"))


## Round 3: a bird crossing at 10 m/s, 15 m out, on the 200 mm lens.
## Freezing it (motion >= 0.8) should need 1/1000 or faster.
func _test_bird_sweep() -> void:
	var cfg: ScoringConfig = load("res://resources/scoring/bird_scoring_config.tres")
	var at := func(shutter: float) -> float:
		return PhotoScoring.motion_score(PhotoScoring.motion_blur_mm(200.0, 15.0, 10.0, shutter), cfg)
	_check("bird at 1/500 is smeared (%.2f)" % at.call(1.0 / 500.0), at.call(1.0 / 500.0) < 0.8)
	_check("bird at 1/1000 is frozen (%.2f)" % at.call(1.0 / 1000.0), at.call(1.0 / 1000.0) >= 0.8)
	var shot := _reference_shot()
	shot.focal_length_mm = 200.0
	shot.subject_distance_m = 15.0
	shot.focus_distance_m = 15.0
	shot.subject_speed_mps = 10.0
	shot.shutter_s = 1.0 / 1000.0
	shot.scene_ev = PhotoScoring.exposure_value(shot.aperture_n, shot.shutter_s, shot.iso)
	_check("a frozen, framed bird is 5 stars", PhotoScoring.score(shot, cfg).stars == 5)
	shot.shutter_s = 1.0 / 125.0
	shot.scene_ev = PhotoScoring.exposure_value(shot.aperture_n, shot.shutter_s, shot.iso)
	var smeared: Dictionary = PhotoScoring.score(shot, cfg)
	_check("a smeared bird misses 4 stars (%d) and the tip says why" % smeared.stars, smeared.stars < 4 and smeared.worst == "motion")


## Round 2: a portrait at dusk (scene EV 2), the subject swaying at 0.4 m/s,
## 4 m out, with focus landing 0.15 m off. Sweeps every camera setting:
## at ISO 400 or lower nothing beats 3 stars, but 5 stars is in reach by
## accepting some grain or blur.
func _test_dusk_sweep() -> void:
	var cfg: ScoringConfig = load("res://resources/scoring/dusk_scoring_config.tres")
	var best_low := 0.0
	var best := {"score": 0.0}
	var shot := _reference_shot()
	shot.scene_ev = 2.0
	shot.subject_distance_m = 4.0
	shot.focus_distance_m = 4.15
	shot.subject_speed_mps = 0.4
	for focal in [50.0, 85.0, 135.0]:
		for n in PhotoCamera.APERTURES:
			for t in PhotoCamera.SHUTTERS:
				for iso in PhotoCamera.ISOS:
					shot.focal_length_mm = focal
					shot.aperture_n = n
					shot.shutter_s = t
					shot.iso = iso
					var result := PhotoScoring.score(shot, cfg)
					if iso <= 400.0:
						best_low = maxf(best_low, result.score)
					if result.score > best.score:
						best = result
	_check("dusk at ISO <= 400 tops out at 3 stars (%.3f)" % best_low, PhotoScoring.stars(best_low, cfg) <= 3)
	_check("dusk 5 stars is reachable (%.3f)" % best.score, best.stars == 5)
	_check("dusk 5 stars costs grain or blur", best.noise < 1.0 or best.motion < 1.0 or best.focus < 1.0)


func _test_briefs() -> void:
	var at_least := BriefRequirement.new()
	at_least.metric = "noise"
	at_least.value = 0.5
	_check("requirement passes at the line", at_least.evaluate({"noise": 0.5}))
	_check("requirement fails below it", not at_least.evaluate({"noise": 0.49}))
	_check("requirement fails on a missing metric", not at_least.evaluate({}))
	var at_most := BriefRequirement.new()
	at_most.metric = "motion_blur_mm"
	at_most.op = BriefRequirement.Op.AT_MOST
	at_most.value = 0.1
	_check("at-most requirement", at_most.evaluate({"motion_blur_mm": 0.05}) and not at_most.evaluate({"motion_blur_mm": 0.2}))

	var dusk: Brief = load("res://resources/briefs/r2_dusk.tres")
	_check("dusk brief loads with its requirement", dusk.requirements.size() == 1 and dusk.requirements[0].required and dusk.config.noise_weight > 0.0)
	_check("dusk: ISO 1600 counts, 3200 doesn't", dusk.meets_required({"noise": PhotoScoring.noise_score(1600.0, dusk.config)}) and not dusk.meets_required({"noise": PhotoScoring.noise_score(3200.0, dusk.config)}))
	var bird: Brief = load("res://resources/briefs/r3_bird.tres")
	_check("bird brief: best of 8 with an optional bonus", bird.win_mode == Brief.WinMode.BEST_OF and bird.shot_limit == 8 and bird.has_bonus() and bird.meets_required({}))

	var runner := RoundRunner.new([bird] as Array[Brief])
	runner.restart()
	for stars in [1, 3, 2, 1, 0, 0, 0]:
		runner.record({"stars": stars, "motion": 0.5})
	_check("best-of waits for the last frame", runner.state == RoundRunner.State.PLAYING and runner.best_stars == 3)
	runner.record({"stars": 0, "motion": 0.0})
	_check("best-of wins on the best frame, no bonus without a frozen one", runner.state == RoundRunner.State.WON and not runner.bonus_met and runner.total_reward() == bird.reward)
	runner.advance()
	_check("one brief done ends the run", runner.state == RoundRunner.State.DONE)


func _reference_shot() -> ShotData:
	var shot := ShotData.new()
	shot.aperture_n = 5.6
	shot.shutter_s = 1.0 / 250.0
	shot.iso = 100.0
	shot.scene_ev = PhotoScoring.exposure_value(5.6, 1.0 / 250.0, 100.0)
	shot.focus_distance_m = 4.0
	shot.subject_distance_m = 4.0
	shot.subject_screen_pos = Vector2(1.0 / 3.0, 2.0 / 3.0)
	return shot


func _test_full_shot() -> void:
	var shot := _reference_shot()

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
	_check("zoom dial says pick another dial", "APERTURE (3)" in PhotoCoach.exposure_hint(-1.5, PhotoCamera.Setting.FOCAL_LENGTH))
	_check("focus dial says pick another dial", "ISO (1)" in PhotoCoach.exposure_hint(-1.5, PhotoCamera.Setting.FOCUS))

	shot.scene_ev -= 2.0
	shot.focus_distance_m = 7.0
	var fixed := PhotoCoach.advice(PhotoScoring.score(shot, _cfg), shot, PhotoCamera.Setting.SHUTTER, true)
	_check("coach is all ok once fixed", PhotoCoach.all_ok(fixed))
	var lowered := PhotoCoach.advice(PhotoScoring.score(shot, _cfg), shot, PhotoCamera.Setting.ISO, true, false)
	_check("lowered camera: coach asks to raise it first", lowered.size() == 2 and not lowered[0].ok and "Raise your camera" in lowered[0].text and lowered[1].pillar == "exposure")
	_check("default config: no motion or noise lines", PhotoCoach.advice(PhotoScoring.score(shot, _cfg), shot, PhotoCamera.Setting.ISO, true, true, _cfg).size() == 4)

	var bird := ScoringConfig.new()
	bird.motion_weight = 0.4
	bird.noise_weight = 0.2
	var fast := _reference_shot()
	fast.subject_speed_mps = 10.0
	fast.subject_distance_m = 20.0
	fast.focus_distance_m = 20.0
	fast.focal_length_mm = 200.0
	fast.iso = 3200.0
	fast.scene_ev = PhotoScoring.exposure_value(fast.aperture_n, fast.shutter_s, fast.iso)
	var bird_lines := PhotoCoach.advice(PhotoScoring.score(fast, bird), fast, PhotoCamera.Setting.SHUTTER, true, true, bird)
	_check("weighted motion and noise get coach lines", bird_lines.size() == 6 and bird_lines[3].pillar == "motion" and bird_lines[4].pillar == "noise")
	_check("motion line names the shutter to use (%s)" % bird_lines[3].text, not bird_lines[3].ok and "1/2000 or faster" in bird_lines[3].text and "scroll SHUTTER faster" in bird_lines[3].text)
	_check("noise line points at ISO", not bird_lines[4].ok and "ISO 3200" in bird_lines[4].text and "pick ISO (1)" in bird_lines[4].text)
	fast.shutter_s = 1.0 / 2000.0
	fast.iso = 400.0
	fast.scene_ev = PhotoScoring.exposure_value(fast.aperture_n, fast.shutter_s, fast.iso)
	var frozen := PhotoCoach.advice(PhotoScoring.score(fast, bird), fast, PhotoCamera.Setting.SHUTTER, true, true, bird)
	_check("motion and noise lines go green once fixed", frozen[3].ok and frozen[4].ok)
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
