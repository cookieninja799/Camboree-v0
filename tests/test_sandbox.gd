extends SceneTree
## Headless smoke test for the scoring sandbox: loads the real scene, raises the
## camera, autofocuses on the subject, and checks that shots and occlusion score sensibly.
##   godot --headless --path . -s res://tests/test_sandbox.gd

const PASS_MARKER := "SANDBOX TESTS PASSED"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: ScoringSandbox = load("res://scenes/sandbox/scoring_sandbox.tscn").instantiate()
	scene.scramble_on_start = false  # the checks below start from known-good settings
	root.add_child(scene)
	var camera: PhotoCamera = scene.get_node("Player/Head/PhotoCamera")
	var subject: PhotoSubject = scene.get_node("Subject")
	var config: ScoringConfig = scene.config
	subject.wander_range = 0.0
	await _settle()

	var sun: Node3D = scene.get_node("Sun")
	_check("sun shines downward", -sun.global_basis.z.y < -0.5)

	await _test_ads(scene, camera)

	_check("camera picks the subject", camera.pick_subject() == subject)
	await _test_autofocus(camera, subject)

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
	await _test_coach(scene, camera)
	await _test_round(scene)
	_check("coach is gone after the first round", not scene.get_node("HUD/Overlay").is_coach_visible())
	_test_sfx()

	if _failures == 0:
		print(PASS_MARKER)
	else:
		printerr("%d sandbox test(s) failed" % _failures)
	quit(1 if _failures > 0 else 0)


func _test_ads(scene: ScoringSandbox, camera: PhotoCamera) -> void:
	var player: Player = scene.get_node("Player")
	var hud: PhotoHud = scene.get_node("HUD/Overlay")
	var view: Camera3D = scene.get_node("Player/ViewCamera")
	_check("starts exploring in third person", player.mode == Player.Mode.EXPLORE and view.current and not camera.raised)
	_check("HUD starts in explore mode", not hud.is_viewfinder())
	_check("view camera starts behind the player", view.global_position.z > player.global_position.z + 1.0)
	# Your eyes never see the camera's exposure: only the PhotoCamera carries it.
	_check("eye view has no camera exposure", view.attributes == null)
	_check("world environment carries no camera exposure", scene.get_node("WorldEnvironment").camera_attributes == null)
	_check("photo camera owns the exposure", camera.attributes is CameraAttributesPhysical)
	await process_frame
	_check("coach asks to raise the camera first", "Raise your camera" in scene.get_node("HUD/Overlay/Coach").text)

	# Fortnite-style: turning the crosshair turns the body.
	var yaw_before := player.rotation.y
	player._look(Vector2(0.6, -0.2))  # mouse right, slightly up
	await create_timer(0.4).timeout
	_check("body turns to follow the crosshair (%.2f -> %.2f)" % [yaw_before, player.rotation.y], absf(angle_difference(player.rotation.y, yaw_before + -0.6)) < 0.05)
	_check("head follows the aim pitch", absf(camera.get_parent().rotation.x - player._rig_pitch) < 1e-4)
	player._look(Vector2(-0.6, 0.2))
	await create_timer(0.4).timeout

	# Space jumps like a traditional FPS (and no longer shoots).
	var ground_y := player.global_position.y
	_press("jump")
	await create_timer(0.2).timeout
	_check("space makes the character jump (rose %.2f m)" % (player.global_position.y - ground_y), player.global_position.y > ground_y + 0.3)
	await create_timer(1.0).timeout
	_check("the character lands again", absf(player.global_position.y - ground_y) < 0.05 and player.is_on_floor())
	_check("space is not a shoot key", not InputMap.action_get_events("shoot").any(func(e: InputEvent) -> bool: return e is InputEventKey and e.physical_keycode == KEY_SPACE))

	var shots := [0]
	var count_shot := func(_shot: ShotData) -> void: shots[0] += 1
	camera.shot_taken.connect(count_shot)
	var nudged := [false]
	camera.needs_raise.connect(func() -> void: nudged[0] = true)
	_press("shoot")
	_check("shooting with the camera lowered takes no photo", shots[0] == 0 and nudged[0])

	player.raise_held = true
	await process_frame  # fires just before _process runs...
	await process_frame  # ...so wait one more to see the first blend step
	_check("raising blends rather than cuts (ads %.2f, view current %s)" % [player.ads_amount(), view.current], player.ads_amount() > 0.0 and player.ads_amount() < 1.0 and view.current)
	await create_timer(player.ads_time + 0.1).timeout
	_check("held raise reaches the viewfinder", player.mode == Player.Mode.VIEWFINDER and camera.current and camera.raised)
	_check("HUD switched to the viewfinder", hud.is_viewfinder())
	_check("viewfinder aims where the shoulder camera aimed (subject in view)", camera.pick_subject() == subject_of(scene))
	_press("shoot")
	_check("shooting with the camera raised takes a photo", shots[0] == 1)
	camera.shot_taken.disconnect(count_shot)
	scene.rounds_started = 0  # undo the test shot's effect on the round
	scene.start_round()

	player.raise_held = false
	await create_timer(player.ads_time + 0.1).timeout
	_check("releasing lowers the camera", player.mode == Player.Mode.EXPLORE and view.current and not camera.raised)
	player.raise_held = true
	await create_timer(player.ads_time + 0.1).timeout


func _test_autofocus(camera: PhotoCamera, subject: PhotoSubject) -> void:
	var player: Player = camera.get_parent().get_parent()
	player.look_at_point(subject.key_point() + Vector3(0.0, -0.3, 0.0))
	await process_frame
	camera.set_focus(0.5)
	camera.autofocus()
	_check("autofocus starts the lens motor", camera.focus_state == PhotoCamera.FocusState.DRIVING)
	await process_frame
	await process_frame
	var depth := camera.view_depth(subject.key_point())
	_check("autofocus takes time (%.2f m after 2 frames)" % camera.focus_distance, absf(camera.focus_distance - depth) > 1.0)
	await create_timer(0.6).timeout
	_check("autofocus locks near the subject (%.2f m vs %.2f m)" % [camera.focus_distance, depth],
		camera.focus_state == PhotoCamera.FocusState.LOCKED and absf(camera.focus_distance - depth) < 0.5)

	camera.autofocus()
	camera.set_focus(2.0)
	_check("manual focus cancels autofocus", camera.focus_state == PhotoCamera.FocusState.IDLE and is_equal_approx(camera.focus_distance, 2.0))

	# Aim at the empty sky: the lens hunts and gives up.
	var head: Node3D = camera.get_parent()
	var pitch := head.rotation.x
	head.rotation.x = deg_to_rad(60.0)
	camera.autofocus()
	await create_timer(1.5).timeout
	_check("autofocus on the sky fails", camera.focus_state == PhotoCamera.FocusState.FAILED)
	head.rotation.x = pitch
	player.look_at_point(subject.key_point())
	camera.autofocus()
	await create_timer(0.6).timeout


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _test_coach(scene: ScoringSandbox, camera: PhotoCamera) -> void:
	var hud: PhotoHud = scene.get_node("HUD/Overlay")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	camera.scramble(rng)
	var error := absf(PhotoScoring.ev_error(camera.aperture, camera.shutter_s, camera.iso, camera.scene_ev))
	_check("scramble knocks exposure 2-3.5 stops off (%.1f)" % error, error >= 2.0 and error <= 3.5)
	_check("scramble puts focus far too close", camera.focus_distance < 1.0)
	await process_frame
	_check("coach shows during the first round", hud.is_coach_visible())
	_check("coach asks for fixes", "FIX" in scene.get_node("HUD/Overlay/Coach").text)

	# Shooting with bad settings is allowed; it just scores badly.
	var bad := PhotoScoring.score(camera.capture(subject_of(scene)), scene.config)
	_check("a shot with scrambled settings scores poorly (%.2f)" % bad.score, bad.score < 0.6)


func subject_of(scene: ScoringSandbox) -> PhotoSubject:
	return scene.get_node("Subject")


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
	_check("dials read ISO, SHUTTER, APERTURE, ZOOM, FOCUS", hud.dial(PhotoCamera.Setting.ISO).title == "ISO" and hud.dial(PhotoCamera.Setting.FOCAL_LENGTH).title == "ZOOM" and hud.dial(PhotoCamera.Setting.FOCUS).title == "FOCUS")
	_check("aperture dial starts selected", hud.dial(PhotoCamera.Setting.APERTURE).selected)

	camera.select_offset(1)
	_check("E moves the selection right to zoom", camera.selected == PhotoCamera.Setting.FOCAL_LENGTH and hud.dial(PhotoCamera.Setting.FOCAL_LENGTH).selected and not hud.dial(PhotoCamera.Setting.APERTURE).selected)
	camera.select_offset(1)
	_check("E again reaches the focus ring", camera.selected == PhotoCamera.Setting.FOCUS)

	# The focus ring: the wheel turns it in fractions of a mark, cancelling autofocus.
	var focus_dial := hud.dial(PhotoCamera.Setting.FOCUS)
	camera.set_focus(2.0)
	_check("focus dial points at the 2 m mark (%s)" % focus_dial.readout, focus_dial.index == PhotoCamera.FOCUS_MARKS.find(2.0) and focus_dial.readout == "2.0 m")
	camera.autofocus()
	for i in 3:
		camera.step_selected(1)
	_check("three notches up turn focus one mark farther (%.2f m)" % camera.focus_distance, is_equal_approx(camera.focus_distance, 3.0))
	_check("turning the focus ring cancels autofocus", camera.focus_state == PhotoCamera.FocusState.IDLE)
	camera.step_selected(-3)
	_check("focus ring scale is spaced in diopters", is_equal_approx(PhotoCamera.focus_from_ring(PhotoCamera.focus_ring_position(4.0)), 4.0))
	_check("focus ring ends at infinity", camera.setting_labels(PhotoCamera.Setting.FOCUS)[-1] == "inf")

	camera.select_offset(1)
	_check("selection wraps around to ISO", camera.selected == PhotoCamera.Setting.ISO)

	camera.step_selected(1)
	var iso_dial := hud.dial(PhotoCamera.Setting.ISO)
	_check("turning ISO updates its dial (%s)" % iso_dial.readout, iso_dial.index == 1 and iso_dial.readout == "200")
	camera.step_selected(-1)
	camera.select_offset(-3)
	_check("back to aperture", camera.selected == PhotoCamera.Setting.APERTURE)
	# Number keys jump straight to a dial.
	_press("dial_5")
	_check("5 jumps to the focus dial", camera.selected == PhotoCamera.Setting.FOCUS and hud.dial(PhotoCamera.Setting.FOCUS).selected)
	_press("dial_1")
	_check("1 jumps to the ISO dial", camera.selected == PhotoCamera.Setting.ISO)
	_check("dials show their number keys", hud.dial(PhotoCamera.Setting.ISO).hotkey == "1" and hud.dial(PhotoCamera.Setting.FOCUS).hotkey == "5")
	_press("dial_3")
	_check("3 jumps back to aperture", camera.selected == PhotoCamera.Setting.APERTURE)
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
