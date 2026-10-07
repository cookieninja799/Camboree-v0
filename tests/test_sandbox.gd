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
	await _test_velocity(scene, camera, subject)

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
	scene.runner.restart()  # undo the test shot's effect on the round
	subject_of(scene).wander_range = 0.0  # the brief set it wandering again

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
	var runner := scene.runner
	var hud: PhotoHud = scene.get_node("HUD/Overlay")
	var camera: PhotoCamera = scene.get_node("Player/Head/PhotoCamera")
	var subject: PhotoSubject = subject_of(scene)
	runner.restart()
	_check("three briefs load", runner.briefs.size() == 3 and runner.briefs.all(func(b: Brief) -> bool: return b != null and b.config != null))
	_check("brief 1 starts with a full roll", runner.index == 0 and runner.state == RoundRunner.State.PLAYING and runner.shots_left == 5)
	_check("brief 1 is the wanderer in daylight", camera.scene_ev == 13.0 and subject.behavior == PhotoSubject.Behavior.WANDER and scene.config.motion_weight == 0.0)

	scene._on_shot_taken(_perfect_shot())
	_check("a 5-star shot wins brief 1", runner.state == RoundRunner.State.WON)
	_check("the winning shot drops a polaroid", hud.is_polaroid_visible() and hud.is_result_visible())
	_check("the winning polaroid is stamped", hud.polaroid_stamp() == "BRIEF COMPLETE")
	scene._on_shot_taken(_perfect_shot())
	_check("a shot during the reveal doesn't skip it", runner.state == RoundRunner.State.WON and runner.index == 0)
	await create_timer(Sfx.reveal_time(5) + 0.6).timeout
	_check("stars fill in on the polaroid", hud.polaroid_stars() == 5)
	scene._on_shot_taken(_perfect_shot())
	var sun: DirectionalLight3D = scene.get_node("Sun")
	_check("the next shot moves on to the dusk brief", runner.index == 1 and runner.state == RoundRunner.State.PLAYING and runner.shots_left == 6)
	_check("moving on clears the last shot's polaroid, bars, and tip", not hud.is_polaroid_visible() and not hud.is_result_visible())
	_check("the dusk brief is coached too", scene.coach_active())
	_check("dusk dims the light and darkens the scene", camera.scene_ev == 2.0 and sun.light_energy < 0.5 and camera.render_gain > 1.0)
	_check("dusk grades noise and shows its bar", scene.config.noise_weight > 0.0 and hud.has_bar("noise") and hud.has_bar("motion"))
	_check("the dusk card shows its requirement", hud.is_card_visible() and "Dusk Portrait" in hud.card_text() and "Noise 0.5+" in hud.card_text())

	var grainy := _perfect_shot()
	grainy.iso = 6400.0
	grainy.scene_ev = PhotoScoring.exposure_value(grainy.aperture_n, grainy.shutter_s, grainy.iso)
	scene._on_shot_taken(grainy)
	_check("a shot that breaks a required rule doesn't count", runner.state == RoundRunner.State.PLAYING and runner.best_stars == 0 and runner.shots_left == 5)
	_check("a shot that doesn't count still shows its polaroid, marked", hud.is_polaroid_visible() and hud.polaroid_stamp() == "DOESN'T COUNT")
	await create_timer(Sfx.reveal_time(5) + 0.3).timeout
	# Noise 0 costs 0.1 of the dusk score, so this lands right on the 5-star line.
	_check("dusk polaroid shows its stars (%d) and why it didn't count" % hud.polaroid_stars(), hud.polaroid_stars() >= 4 and "Doesn't count" in scene.get_node("HUD/Overlay/Result/TipLabel").text)
	scene._on_shot_taken(_perfect_shot())
	_check("a clean 5-star shot wins dusk", runner.state == RoundRunner.State.WON)
	_check("the dusk win drops a stamped polaroid", hud.is_polaroid_visible() and hud.polaroid_stamp() == "BRIEF COMPLETE")
	await create_timer(Sfx.reveal_time(5) + 0.6).timeout
	_check("dusk win shows all its stars", hud.polaroid_stars() == 5)

	scene._on_shot_taken(_perfect_shot())
	_check("then the bird brief: a flyer, best of 8", runner.index == 2 and subject.behavior == PhotoSubject.Behavior.FLYER and runner.brief().win_mode == Brief.WinMode.BEST_OF)
	_check("the bird brief is coached too", scene.coach_active())
	scene._on_shot_taken(_perfect_shot())
	_check("best-of keeps going after a great shot", runner.state == RoundRunner.State.PLAYING and runner.shots_left == 7)
	_check("a mid-roll shot has a plain polaroid", hud.is_polaroid_visible() and hud.polaroid_stamp() == "")
	for i in 7:
		scene._on_shot_taken(_perfect_shot())
	_check("best-of wins once the roll is used, with the frozen-motion bonus", runner.state == RoundRunner.State.WON and runner.bonus_met)
	_check("the bird win is stamped with its bonus", hud.polaroid_stamp() == "BRIEF COMPLETE +BONUS")
	await create_timer(Sfx.reveal_time(5) + 0.6).timeout

	scene._on_shot_taken(_perfect_shot())
	_check("after the last brief: the summary", runner.state == RoundRunner.State.DONE and hud.is_card_visible() and "Total: 550" in hud.card_text())
	hud.set_viewfinder(true)
	_check("the summary stays up with the camera raised", hud.is_card_visible())
	scene._on_shot_taken(_perfect_shot())
	_check("shooting after the summary starts over", runner.index == 0 and runner.state == RoundRunner.State.PLAYING and runner.attempt == 1 and runner.results.is_empty())
	_check("raising the camera puts a brief card away", (func() -> bool: hud.set_viewfinder(true); return not hud.is_card_visible()).call())

	var miss := _perfect_shot()
	miss.visibility = 0.0
	for i in 5:
		scene._on_shot_taken(miss)
	_check("running out of shots loses", runner.state == RoundRunner.State.LOST and runner.best_stars == 0)

	# Let the photo grab, polaroid drop, and staggered reveal play out; script errors fail CI.
	await create_timer(Sfx.reveal_time(5) + 0.3).timeout
	_check("HUD is visible again after the photo grab", hud.visible)
	_check("brief shows the loss", "Out of shots" in scene.get_node("HUD/Overlay/BriefLabel").text)
	scene._on_shot_taken(miss)
	_check("shooting after a loss retries the same brief", runner.index == 0 and runner.attempt == 2 and runner.shots_left == 5)
	subject.behavior = PhotoSubject.Behavior.STAND


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


## Subjects measure their own speed, and the camera keeps only the part across the frame.
func _test_velocity(scene: ScoringSandbox, camera: PhotoCamera, subject: PhotoSubject) -> void:
	var start := subject.global_position
	await _settle()
	_check("a still subject reports no speed", subject.global_velocity.length() < 0.01)

	var dt := 1.0 / Engine.physics_ticks_per_second
	var step := Vector3(4.0, 0.0, 0.0) * dt  # 4 m/s sideways
	for i in 4:
		subject.global_position += step
		await physics_frame
	var speed := subject.global_velocity.length()
	_check("a moving subject reports its speed (%.2f m/s)" % speed, absf(speed - 4.0) <= 0.2)

	var forward := -camera.global_basis.z.normalized()
	_check("speed across the frame ignores motion toward the camera", camera.cross_frame_speed(forward * 5.0) < 0.01)
	var side := camera.global_basis.x.normalized() * 3.0
	_check("speed across the frame counts sideways motion", is_equal_approx(camera.cross_frame_speed(side + forward * 2.0), 3.0))
	_check("capture fills in the subject's speed", camera.capture(subject).subject_speed_mps > 0.0)

	# The motion blur trail is v·t long: 4 m/s for 1/15 s is about 0.27 m.
	var trail := subject.trail
	trail.exposure_s = 1.0 / 15.0
	_check("trail length is speed times shutter (%.3f m)" % trail.length_m(), absf(trail.length_m() - 4.0 / 15.0) < 0.02)
	trail._process(0.0)
	var ghosts := trail.get_children().filter(func(g: Node3D) -> bool: return g.visible)
	_check("slow shutter draws a ghost trail (%d copies)" % ghosts.size(), ghosts.size() >= 4)
	_check("ghosts trail behind the subject", ghosts[-1].global_position.x < subject.global_position.x - 0.2)
	trail.exposure_s = 1.0 / 4000.0
	trail._process(0.0)
	_check("fast shutter freezes it: no ghosts", trail.get_children().all(func(g: Node3D) -> bool: return not g.visible))

	subject.global_position = start
	await _settle()

	await _test_grain(scene, camera)
	await _test_flyer(scene, camera, subject)
	_check("ISO dial reaches 12800", PhotoCamera.ISOS[-1] >= 12800.0 and PhotoCamera.SHUTTERS[-1] <= 1.0 / 4000.0)


## Grain follows the ISO dial with the noise pillar's curve, and only shows through the viewfinder.
func _test_grain(scene: ScoringSandbox, camera: PhotoCamera) -> void:
	var grain := scene.grain
	var player: Player = scene.get_node("Player")
	camera.select_setting(PhotoCamera.Setting.ISO)
	var start_iso := camera.iso
	for i in PhotoCamera.ISOS.size():
		camera.step_selected(-1)
	var levels := {int(camera.iso): grain.amount()}
	for i in PhotoCamera.ISOS.size() - 1:
		camera.step_selected(1)
		levels[int(camera.iso)] = grain.amount()
	_check("no grain at ISO 100-400", levels[100] == 0.0 and levels[400] == 0.0)
	_check("grain grows with ISO (800 %.2f < 3200 %.2f < 12800 %.2f)" % [levels[800], levels[3200], levels[12800]], levels[800] > 0.0 and levels[800] < levels[3200] and levels[3200] < levels[12800])
	var hud: PhotoHud = scene.get_node("HUD/Overlay")
	_check("round 1 shows no motion or noise bars", hud.has_bar("focus") and hud.has_bar("gate") and not hud.has_bar("motion") and not hud.has_bar("noise"))
	var weighted := ScoringConfig.new()
	weighted.noise_weight = 0.3
	hud.set_config(weighted)
	_check("a brief that weighs noise shows its bar", hud.has_bar("noise") and not hud.has_bar("motion"))
	hud.set_config(scene.config)
	_check("grain is in its own layer under the HUD", grain.layer < (scene.get_node("HUD") as CanvasLayer).layer)
	await process_frame
	_check("grain fades in with the camera raise (%.2f)" % grain.view_amount, is_equal_approx(grain.view_amount, player.ads_amount()))
	while camera.iso > start_iso:
		camera.step_selected(-1)
	camera.select_setting(PhotoCamera.Setting.APERTURE)


## The flyer makes fast passes high up, and can't be photographed between them.
## Its clock is driven by hand here so the test doesn't wait out real passes.
func _test_flyer(scene: ScoringSandbox, camera: PhotoCamera, subject: PhotoSubject) -> void:
	var start := subject.global_position
	subject.set_physics_process(false)
	subject.rng.seed = 3
	subject.behavior = PhotoSubject.Behavior.FLYER
	_check("a flyer starts out of sight", not subject.is_present() and subject.collision_layer == 0)
	_check("nothing to shoot while the flyer is away", camera.pick_subject() == null)

	var dt := 1.0 / 60.0
	var speeds: Array[float] = []
	var heights: Array[float] = []
	var passes := 0
	var was_present := false
	for i in 60 * 30:
		subject._physics_process(dt)
		if subject.is_present() and was_present:
			speeds.append(subject.global_velocity.length())
			heights.append(subject.global_position.y - start.y)
		if subject.is_present() and not was_present:
			passes += 1
		was_present = subject.is_present()
	_check("the flyer makes several passes in 30 s (%d)" % passes, passes >= 3)
	_check("flyer speed stays within 8-12 m/s (%.1f-%.1f)" % [speeds.min(), speeds.max()], speeds.min() >= 7.9 and speeds.max() <= 12.1)
	_check("flyer stays 4-8 m up (%.1f-%.1f)" % [heights.min(), heights.max()], heights.min() >= 3.9 and heights.max() <= 8.1)

	subject.behavior = PhotoSubject.Behavior.WANDER
	subject.set_physics_process(true)
	_check("back to wandering: present, home, and upright", subject.is_present() and subject.global_position.is_equal_approx(subject._origin) and subject.global_basis.y.is_equal_approx(Vector3.UP))
	subject.global_position = start
	await _settle()


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
	# On a slow load the first frame catches up with several physics steps before
	# any _process runs, so physics frames alone don't mean the scene has updated.
	for i in 2:
		await process_frame


func _check(label: String, ok: bool) -> void:
	if ok:
		print("ok    ", label)
	else:
		_failures += 1
		printerr("FAIL  ", label)
