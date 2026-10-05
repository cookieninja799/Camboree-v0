extends SceneTree
## Headless smoke test for the scoring sandbox: loads the real scene, autofocuses
## on the subject, and checks that shots and occlusion score sensibly.
##   godot --headless --path . -s res://tests/test_sandbox.gd

const PASS_MARKER := "SANDBOX TESTS PASSED"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: Node3D = load("res://scenes/sandbox/scoring_sandbox.tscn").instantiate()
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

	if _failures == 0:
		print(PASS_MARKER)
	else:
		printerr("%d sandbox test(s) failed" % _failures)
	quit(1 if _failures > 0 else 0)


func _settle() -> void:
	for i in 5:
		await physics_frame


func _check(label: String, ok: bool) -> void:
	if ok:
		print("ok    ", label)
	else:
		_failures += 1
		printerr("FAIL  ", label)
