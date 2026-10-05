class_name PhotoCamera
extends Camera3D
## First-person photo camera: exposure triangle, focal length, and focus.
## What the player sees (depth of field, brightness) and what gets scored come
## from the same numbers, so the two never disagree.

signal shot_taken(shot: ShotData)
## A setting value or the selected setting changed.
signal settings_changed

## Ordered left to right as the HUD dials appear.
enum Setting { ISO, SHUTTER, APERTURE, FOCAL_LENGTH }

const SETTING_NAMES := ["ISO", "SHUTTER", "APERTURE", "ZOOM"]

const APERTURES := [1.4, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0, 22.0]
const SHUTTERS := [1.0 / 15.0, 1.0 / 30.0, 1.0 / 60.0, 1.0 / 125.0, 1.0 / 250.0, 1.0 / 500.0, 1.0 / 1000.0, 1.0 / 2000.0, 1.0 / 4000.0]
const ISOS := [100.0, 200.0, 400.0, 800.0, 1600.0, 3200.0]
const FOCAL_LENGTHS := [18.0, 24.0, 35.0, 50.0, 85.0, 135.0, 200.0]
const MIN_FOCUS_M := 0.3
const MAX_FOCUS_M := 200.0
const FOCUS_STEP := 1.06

## Correct exposure for the scene at ISO 100. Set by whoever owns the scene.
@export var scene_ev := 13.0:
	set(value):
		scene_ev = value
		_apply()

var selected := Setting.APERTURE
var focus_distance := 3.0

var aperture: float:
	get: return APERTURES[_aperture_i]
var shutter_s: float:
	get: return SHUTTERS[_shutter_i]
var iso: float:
	get: return ISOS[_iso_i]
var focal_length_mm: float:
	get: return FOCAL_LENGTHS[_focal_i]

var _aperture_i := 4  # f/5.6
var _shutter_i := 4  # 1/250
var _iso_i := 0  # ISO 100
var _focal_i := 3  # 50mm
var _exclude: Array[RID] = []


func _ready() -> void:
	if not attributes is CameraAttributesPhysical:
		attributes = CameraAttributesPhysical.new()
	# Don't let autofocus or visibility rays hit whoever is holding the camera.
	var node := get_parent()
	while node:
		if node is CollisionObject3D:
			_exclude.append(node.get_rid())
			break
		node = node.get_parent()
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	# A click while the mouse is free is for grabbing the mouse, not shooting.
	if event is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event.is_action_pressed("shoot"):
		shot_taken.emit(capture(pick_subject()))
	elif event.is_action_pressed("autofocus"):
		autofocus()
	elif event.is_action_pressed("focus_far"):
		set_focus(focus_distance * FOCUS_STEP)
	elif event.is_action_pressed("focus_near"):
		set_focus(focus_distance / FOCUS_STEP)
	elif event.is_action_pressed("setting_next"):
		select_offset(1)
	elif event.is_action_pressed("setting_prev"):
		select_offset(-1)
	elif event.is_action_pressed("value_up"):
		step_selected(1)
	elif event.is_action_pressed("value_down"):
		step_selected(-1)


## Moves the selection left (-1) or right (+1) across the dials, wrapping around.
func select_offset(offset: int) -> void:
	selected = wrapi(selected + offset, 0, Setting.size()) as Setting
	settings_changed.emit()


func step_selected(direction: int) -> void:
	match selected:
		Setting.APERTURE:
			_aperture_i = clampi(_aperture_i + direction, 0, APERTURES.size() - 1)
		Setting.SHUTTER:
			_shutter_i = clampi(_shutter_i + direction, 0, SHUTTERS.size() - 1)
		Setting.ISO:
			_iso_i = clampi(_iso_i + direction, 0, ISOS.size() - 1)
		Setting.FOCAL_LENGTH:
			_focal_i = clampi(_focal_i + direction, 0, FOCAL_LENGTHS.size() - 1)
	_apply()


func set_focus(distance_m: float) -> void:
	focus_distance = clampf(distance_m, MIN_FOCUS_M, MAX_FOCUS_M)
	_apply()


## Single-shot autofocus on whatever sits under the center of the frame.
func autofocus() -> void:
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position - global_basis.z * MAX_FOCUS_M)
	query.exclude = _exclude
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		set_focus(view_depth(hit.position))


## Distance of a world point along the camera's view axis (what focus cares about).
func view_depth(world_point: Vector3) -> float:
	return -to_local(world_point).z


## The subject nearest the center of the frame, or null if none is in view.
func pick_subject() -> PhotoSubject:
	var best: PhotoSubject = null
	var best_dist := INF
	var center := get_viewport().get_visible_rect().size * 0.5
	for node in get_tree().get_nodes_in_group(PhotoSubject.GROUP):
		var subject := node as PhotoSubject
		if subject == null or not is_position_in_frustum(subject.key_point()):
			continue
		var dist := unproject_position(subject.key_point()).distance_to(center)
		if dist < best_dist:
			best = subject
			best_dist = dist
	return best


## Freezes the current settings and subject geometry into a ShotData.
func capture(subject: PhotoSubject) -> ShotData:
	var shot := ShotData.new()
	shot.focal_length_mm = focal_length_mm
	shot.aperture_n = aperture
	shot.shutter_s = shutter_s
	shot.iso = iso
	shot.focus_distance_m = focus_distance
	shot.scene_ev = scene_ev
	if subject == null:
		shot.visibility = 0.0
		return shot
	var key := subject.key_point()
	shot.subject_distance_m = maxf(view_depth(key), 0.01)
	shot.subject_screen_pos = unproject_position(key) / get_viewport().get_visible_rect().size
	shot.visibility = visibility_of(subject)
	return shot


## Fraction of the subject's sample points that are in frame and not blocked.
func visibility_of(subject: PhotoSubject) -> float:
	var points := subject.sample_points()
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = [subject.get_rid()]
	exclude.append_array(_exclude)
	var seen := 0
	for point in points:
		if not is_position_in_frustum(point):
			continue
		var query := PhysicsRayQueryParameters3D.create(global_position, point)
		query.exclude = exclude
		if space.intersect_ray(query).is_empty():
			seen += 1
	return float(seen) / points.size()


## Which entry of setting_labels() is currently set.
func setting_index(setting: Setting) -> int:
	match setting:
		Setting.ISO:
			return _iso_i
		Setting.SHUTTER:
			return _shutter_i
		Setting.APERTURE:
			return _aperture_i
	return _focal_i


## Short labels for the dial's tick marks, the way a camera dial prints them
## (shutter "250" means 1/250 s).
func setting_labels(setting: Setting) -> PackedStringArray:
	var labels := PackedStringArray()
	match setting:
		Setting.ISO:
			for value in ISOS:
				labels.append(str(int(value)))
		Setting.SHUTTER:
			for value in SHUTTERS:
				labels.append(PhotoScoring.format_shutter(value).trim_prefix("1/"))
		Setting.APERTURE:
			for value in APERTURES:
				labels.append(PhotoScoring.format_aperture(value).trim_prefix("f/"))
		Setting.FOCAL_LENGTH:
			for value in FOCAL_LENGTHS:
				labels.append(str(int(value)))
	return labels


## The current value, written out in full for the dial's center readout.
func setting_readout(setting: Setting) -> String:
	match setting:
		Setting.ISO:
			return str(int(iso))
		Setting.SHUTTER:
			return PhotoScoring.format_shutter(shutter_s)
		Setting.APERTURE:
			return PhotoScoring.format_aperture(aperture)
	return "%dmm" % focal_length_mm


func _apply() -> void:
	var attrs := attributes as CameraAttributesPhysical
	if attrs == null:
		return
	attrs.frustum_focal_length = focal_length_mm
	attrs.frustum_focus_distance = focus_distance
	attrs.exposure_aperture = aperture
	# Godot wants the shutter as a rate: 250 means 1/250 s.
	attrs.exposure_shutter_speed = 1.0 / shutter_s
	attrs.exposure_sensitivity = iso
	# Without physical light units Godot ignores aperture/shutter/ISO for brightness,
	# so drive brightness from the same EV error the scorer uses.
	var ev_err := PhotoScoring.ev_error(aperture, shutter_s, iso, scene_ev)
	attrs.exposure_multiplier = clampf(pow(2.0, -ev_err), 1.0 / 32.0, 32.0)
	settings_changed.emit()
