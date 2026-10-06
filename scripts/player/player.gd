class_name Player
extends CharacterBody3D
## The photographer. Explore in third person with an over-the-shoulder orbit
## camera; the body always faces where the crosshair points (Fortnite-style), so
## movement strafes and the head tilts with your aim. Hold "raise_camera" to bring
## the camera to your eye, ADS-style. The
## view blends from the shoulder into the PhotoCamera while the FOV narrows to
## the lens, and aim carries over so raising never jolts the view.

signal mode_changed(mode: Mode)

enum Mode { EXPLORE, VIEWFINDER }

@export var speed := 4.0
## Upward speed when jumping (m/s). ~4.5 gives a hop of about 1 m.
@export var jump_velocity := 4.5
## Movement multiplier while the camera is up (slow walk, like ADS).
@export var aim_speed_mult := 0.35
## Seconds for the camera to come up to the eye (and back down).
@export var ads_time := 0.15
@export var explore_fov := 70.0
@export var mouse_sensitivity := 0.0025
@export var stick_look_speed := 2.5
@export var stick_deadzone := 0.2
## How quickly the body turns to face the crosshair while exploring.
@export var turn_speed := 18.0
## How much of the aim pitch shows as the head tilting up/down (visual only).
@export var head_tilt_amount := 0.6
@export_group("Orbit")
@export var orbit_pitch_min := -1.2
@export var orbit_pitch_max := 0.9

var mode := Mode.EXPLORE
## Held state of the raise button. Tests can set it directly.
var raise_held := false

var _jump_queued := false

var _ads := 0.0  # 0 = shoulder view, 1 = through the camera
var _rig_yaw := 0.0
var _rig_pitch := -0.2

@onready var _head: Node3D = $Head
@onready var _photo_camera: PhotoCamera = $Head/PhotoCamera
@onready var _rig: Node3D = $CameraRig
@onready var _spring_arm: SpringArm3D = $CameraRig/SpringArm3D
@onready var _orbit_anchor: Node3D = $CameraRig/SpringArm3D/OrbitAnchor
@onready var _view_camera: Camera3D = $ViewCamera
@onready var _camera_prop: Node3D = $Body/CameraProp
@onready var _head_mesh: Node3D = $Body/HeadMesh

var _prop_chest: Transform3D
var _prop_eye: Transform3D


func _ready() -> void:
	SandboxInput.ensure_actions()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_spring_arm.add_excluded_object(get_rid())
	_rig_yaw = rotation.y
	_prop_chest = _camera_prop.transform
	_prop_eye = Transform3D(_prop_chest.basis, Vector3(0.0, _head.position.y, -0.32))
	_view_camera.fov = explore_fov
	_view_camera.make_current()
	_photo_camera.raised = false
	_update_rig()
	_update_view(0.0)


func is_viewfinder() -> bool:
	return mode == Mode.VIEWFINDER


## 0 when exploring, 1 when looking through the camera, in between mid-raise.
func ads_amount() -> float:
	return _ads


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		_jump_queued = true
	if event.is_action_pressed("raise_camera"):
		raise_held = true
	elif event.is_action_released("raise_camera"):
		raise_held = false

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(event.relative * mouse_sensitivity)
	elif event.is_action_pressed("toggle_mouse"):
		var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if captured else Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() > stick_deadzone:
		_look(stick * stick_look_speed * delta)

	if not is_on_floor():
		velocity += get_gravity() * delta
	# Jump like a traditional FPS: only from the ground, and it works with the camera up too.
	if _jump_queued and is_on_floor():
		velocity.y = jump_velocity
	_jump_queued = false
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var aiming := _ads > 0.0
	# Explore: move relative to where the orbit camera looks. Aiming: relative to the body.
	var yaw := rotation.y if aiming else _rig_yaw
	var direction := Basis(Vector3.UP, yaw) * Vector3(input.x, 0.0, input.y)
	var move_speed := speed * (aim_speed_mult if aiming else 1.0)
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	move_and_slide()


func _process(delta: float) -> void:
	var was := _ads
	if raise_held and was == 0.0:
		_align_to_aim()
	_ads = move_toward(_ads, 1.0 if raise_held else 0.0, delta / ads_time)
	if _ads > 0.0:
		# The body owns the aim while the camera is up; keep the orbit behind it
		# so lowering the camera returns to the same direction.
		_rig_yaw = rotation.y
		_rig_pitch = clampf(_head.rotation.x, orbit_pitch_min, orbit_pitch_max)
	else:
		# Exploring: the body turns to face the crosshair and the head follows its pitch.
		rotation.y = lerp_angle(rotation.y, _rig_yaw, minf(1.0, turn_speed * delta))
		_head.rotation.x = _rig_pitch
	_head_mesh.rotation.x = _head.rotation.x * head_tilt_amount
	_update_rig()
	_update_view(_ads)

	if _ads >= 1.0 and mode != Mode.VIEWFINDER:
		_set_mode(Mode.VIEWFINDER)
	elif _ads < 1.0 and mode != Mode.EXPLORE:
		_set_mode(Mode.EXPLORE)
	if was == 0.0 and _ads > 0.0:
		Sfx.play(self, Sfx.click())


func _set_mode(new_mode: Mode) -> void:
	mode = new_mode
	_photo_camera.raised = new_mode == Mode.VIEWFINDER
	if new_mode == Mode.VIEWFINDER:
		_photo_camera.make_current()
	else:
		_view_camera.make_current()
	mode_changed.emit(new_mode)


func _look(amount: Vector2) -> void:
	if _ads > 0.0:
		# Through the lens, sensitivity scales with zoom so long lenses aren't twitchy.
		amount *= _photo_camera.fov / explore_fov
		rotate_y(-amount.x)
		_head.rotate_x(-amount.y)
		_head.rotation.x = clampf(_head.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))
	else:
		_rig_yaw -= amount.x
		_rig_pitch = clampf(_rig_pitch - amount.y, orbit_pitch_min, orbit_pitch_max)


## Points the body and head at whatever the shoulder camera's crosshair is on,
## so the viewfinder opens exactly where you were aiming.
func _align_to_aim() -> void:
	var from := _view_camera.global_position
	var forward := -_view_camera.global_basis.z
	var query := PhysicsRayQueryParameters3D.create(from, from + forward * 200.0)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	look_at_point(hit.position if not hit.is_empty() else from + forward * 200.0)


## Turns the body and tilts the head so the PhotoCamera looks at `target`.
func look_at_point(target: Vector3) -> void:
	var to_target := target - _head.global_position
	rotation.y = atan2(-to_target.x, -to_target.z)
	var flat := Vector2(to_target.x, to_target.z).length()
	_head.rotation.x = clampf(atan2(to_target.y, flat), deg_to_rad(-85.0), deg_to_rad(85.0))


func _update_rig() -> void:
	_rig.global_position = global_position + Vector3(0.0, _head.position.y, 0.0)
	_rig.global_rotation = Vector3(_rig_pitch, _rig_yaw, 0.0)


func _update_view(amount: float) -> void:
	var t := smoothstep(0.0, 1.0, amount)
	_view_camera.global_transform = _orbit_anchor.global_transform.interpolate_with(_photo_camera.global_transform, t)
	_view_camera.fov = lerpf(explore_fov, _photo_camera.fov, t)
	# Stop drawing our own body once the view is nearly inside the head.
	_view_camera.set_cull_mask_value(2, t < 0.7)
	_camera_prop.transform = _prop_chest.interpolate_with(_prop_eye, t)
