extends SceneTree
## Headless smoke test for the scoring sandbox: loads the real scene, autofocuses
## on the subject, and checks that shots and occlusion score sensibly.
##   godot --headless --path . -s res://tests/test_sandbox.gd

const PASS_MARKER := "SANDBOX TESTS PASSED"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: ScoringSandbox = load("res://scenes/sandbox/scoring_sandbox.tscn").instantiate()
	root.add_child(scene)
	var camera: PhotoCamera = scene.get_node("Player/Head/PhotoCamera")
	var subject: PhotoSubject = scene.get_node("Subject")
	var config: ScoringConfig = scene.config
	subject.wander_range = 0.0
	await _settle()

	var sun: Node3D = scene.get_node("Sun")
	_check("sun shines downward", -sun.global_basis.z.y < -0.5)

	_check("camera picks the subject", camera.pick_subject() == subject)
	camera.autofocus()
	var depth := camera.view_depth(subject.key_point())
	_check("autofocus lands near the subject (%.2f m vs %.2f m)" % [camera.focus_distance, depth], absf(camera.focus_distance - depth) < 0.5)

	var shot := camera.capture(subject)
	_check("subject fully visible", is_equal_approx(shot.visibility, 1.0))
	var result := PhotoScoring.score(shot, config)
	print("      open shot: ", result)
	_check("open shot exposure is good", result.exposure > 0.9)
	_check("open shot scores > 0.5", result.score > 0.5)

	# Hide the subject behind PillarMid.
	subject.global_position = Vector3(3.0, 0.8, -6.0)
	await _settle()
	var hidden := camera.capture(subject)
	_check("pillar blocks the subject (visibility %.2f)" % hidden.visibility, hidden.visibility < 0.34)

	var music: AudioStreamPlayer = scene.get_node("Music")
	_check("background music autoplays and loops", music.autoplay and music.stream is AudioStreamMP3 and music.stream.loop)

	_test_dials(scene, camera)
	await _test_round(scene)
	_test_sfx()

	if _failures == 0:
		print(PASS_MARKER)
	else:
		printerr("%d sandbox test(s) failed" % _failures)
	quit(1 if _failures > 0 else 0)


func _test_round(scene: ScoringSandbox) -> void:
	scene.start_round()
	_check("round starts with a full roll", scene.round_state == ScoringSandbox.RoundState.PLAYING and scene.shots_left == scene.shots_per_round)

	scene._on_shot_taken(_perfect_shot())
	_check("a 5-star shot wins the round", scene.round_state == ScoringSandbox.RoundState.WON)
	scene._on_shot_taken(_perfect_shot())
	_check("shooting after the round restarts it", scene.round_state == ScoringSandbox.RoundState.PLAYING and scene.shots_left == scene.shots_per_round)

	var miss := _perfect_shot()
	miss.visibility = 0.0
	for i in scene.shots_per_round:
		scene._on_shot_taken(miss)
	_check("running out of shots loses", scene.round_state == ScoringSandbox.RoundState.LOST and scene.best_stars == 0)

	# Let the photo grab, polaroid drop, and staggered reveal play out; script errors fail CI.
	await create_timer(Sfx.reveal_time(5) + 0.3).timeout
	var hud: PhotoHud = scene.get_node("HUD/Overlay")
	_check("HUD is visible again after the photo grab", hud.visible)
	_check("brief shows the loss", "Out of shots" in scene.get_node("HUD/Overlay/BriefLabel").text)


func _test_dials(scene: ScoringSandbox, camera: PhotoCamera) -> void:
	var hud: PhotoHud = scene.get_node("HUD/Overlay")
	_check("one dial per setting", scene.get_node("HUD/Overlay/Dials").get_child_count() == PhotoCamera.Setting.size())
	_check("dials read ISO, SHUTTER, APERTURE, ZOOM", hud.dial(PhotoCamera.Setting.ISO).title == "ISO" and hud.dial(PhotoCamera.Setting.FOCAL_LENGTH).title == "ZOOM")
	_check("aperture dial starts selected", hud.dial(PhotoCamera.Setting.APERTURE).selected)

	camera.select_offset(1)
	_check("E moves the selection right to zoom", camera.selected == PhotoCamera.Setting.FOCAL_LENGTH and hud.dial(PhotoCamera.Setting.FOCAL_LENGTH).selected and not hud.dial(PhotoCamera.Setting.APERTURE).selected)
	camera.select_offset(1)
	_check("selection wraps around to ISO", camera.selected == PhotoCamera.Setting.ISO)

	camera.step_selected(1)
	var iso_dial := hud.dial(PhotoCamera.Setting.ISO)
	_check("turning ISO updates its dial (%s)" % iso_dial.readout, iso_dial.index == 1 and iso_dial.readout == "200")
	camera.step_selected(-1)
	camera.select_offset(-2)
	_check("back to aperture", camera.selected == PhotoCamera.Setting.APERTURE)
	_check("shutter ticks read like a camera dial", camera.setting_labels(PhotoCamera.Setting.SHUTTER)[4] == "250")


func _test_sfx() -> void:
	var chime := Sfx.tone(440.0, 0.25)
	_check("tone has the right length", chime.data.size() == int(Sfx.RATE * 0.25) * 2)
	_check("tones are cached", Sfx.tone(440.0, 0.25) == chime)
	_check("stars chime in order", Sfx.star_time(1) > Sfx.star_time(0))


func _perfect_shot() -> ShotData:
	var shot := ShotData.new()
	shot.scene_ev = PhotoScoring.exposure_value(shot.aperture_n, shot.shutter_s, shot.iso)
	shot.focus_distance_m = 4.0
	shot.subject_distance_m = 4.0
	shot.subject_screen_pos = Vector2(1.0 / 3.0, 1.0 / 3.0)
	return shot


func _settle() -> void:
	for i in 5:
		await physics_frame


func _check(label: String, ok: bool) -> void:
	if ok:
		print("ok    ", label)
	else:
		_failures += 1
		printerr("FAIL  ", label)
