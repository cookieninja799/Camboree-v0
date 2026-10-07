class_name PhotoSubject
extends CharacterBody3D
## Something worth photographing. Child Marker3Ds are the visibility sample
## points, and the one named "Head" is the key point that focus is scored on.

const GROUP := &"photo_subject"

## WANDER slides back and forth (the Round 1 wanderer). STAND holds still.
## FLYER makes fast straight passes high across the field, with gaps between.
enum Behavior { WANDER, STAND, FLYER }

@export var behavior := Behavior.WANDER:
	set(value):
		behavior = value
		if is_node_ready():
			_start_behavior()

## Wandering: slides back and forth along this axis. 0 range = stand still.
## Peak speed is wander_range * wander_speed m/s, at the middle of the swing.
@export var wander_axis := Vector3.RIGHT
@export var wander_range := 3.0
@export var wander_speed := 0.6

@export_group("Flyer")
## Pass speed in m/s, picked per pass between x and y.
@export var fly_speed := Vector2(8.0, 12.0)
## Height above the starting point, in meters.
@export var fly_height := Vector2(4.0, 8.0)
## Seconds out of sight between passes.
@export var fly_gap := Vector2(2.0, 5.0)
## Each pass runs this far either side of the starting point along wander_axis.
@export var fly_half_span := 30.0
## Lane offset across wander_axis (toward the +Z side of it is positive).
@export var fly_lane := Vector2(-8.0, -2.0)
## Size of the flyer's body relative to the wanderer.
@export var fly_scale := 0.5

## World-space velocity in m/s, measured from how far the subject moved this
## physics frame. CharacterBody3D.velocity stays zero because the wander sets
## global_position directly.
var global_velocity := Vector3.ZERO
## Draws this subject's motion blur; whoever owns the camera sets trail.exposure_s.
var trail: MotionTrail

var rng := RandomNumberGenerator.new()

var _origin: Vector3
var _home_basis: Basis
var _home_layer := 0
var _time := 0.0
var _last_position: Vector3
# Flyer state: the current pass, or the wait before the next one.
var _pass_from: Vector3
var _pass_velocity: Vector3
var _pass_left := 0.0  # seconds of flight left in this pass
var _gap_left := 0.0  # seconds until the next pass


func _ready() -> void:
	add_to_group(GROUP)
	rng.randomize()
	_origin = global_position
	_home_basis = global_basis
	_home_layer = collision_layer
	_last_position = global_position
	trail = MotionTrail.new()
	trail.name = "MotionTrail"
	add_child(trail)
	_start_behavior()


## True while the subject can be seen and photographed (a flyer between passes can't).
func is_present() -> bool:
	return visible


func _physics_process(delta: float) -> void:
	match behavior:
		Behavior.WANDER:
			if wander_range > 0.0:
				_time += delta * wander_speed
				# sin() slows down at the ends, which gives the player a "moment" to catch.
				global_position = _origin + wander_axis.normalized() * sin(_time) * wander_range
		Behavior.FLYER:
			_fly(delta)
	# Measure after moving, against where we were after last frame's move, so
	# anything else that moved us in between (tests, other scripts) counts too.
	if delta > 0.0:
		global_velocity = (global_position - _last_position) / delta
	_last_position = global_position


func _start_behavior() -> void:
	_time = 0.0
	_set_present(true)
	if behavior == Behavior.FLYER:
		_set_present(false)
		_gap_left = rng.randf_range(0.5, 1.5)  # a short first wait
		return
	global_basis = _home_basis
	_teleport(_origin)


func _fly(delta: float) -> void:
	if _gap_left > 0.0:
		_gap_left -= delta
		if _gap_left <= 0.0:
			_begin_pass()
		return
	_pass_left -= delta
	if _pass_left <= 0.0:
		_set_present(false)
		_gap_left = rng.randf_range(fly_gap.x, fly_gap.y)
		return
	global_position += _pass_velocity * delta


func _begin_pass() -> void:
	var along := wander_axis.normalized() * (1.0 if rng.randf() < 0.5 else -1.0)
	var across := wander_axis.normalized().cross(Vector3.UP).normalized()
	var speed := rng.randf_range(fly_speed.x, fly_speed.y)
	_pass_from = _origin - along * fly_half_span \
		+ Vector3.UP * rng.randf_range(fly_height.x, fly_height.y) \
		+ across * rng.randf_range(fly_lane.x, fly_lane.y)
	_pass_velocity = along * speed
	_pass_left = 2.0 * fly_half_span / speed
	# Lie the body along the flight path, head first (the Head marker is +Y).
	global_basis = Basis(Vector3.UP, along, Vector3.UP.cross(along)) * Basis.from_scale(Vector3.ONE * fly_scale)
	_teleport(_pass_from)
	_set_present(true)


## Moves without the jump reading as speed.
func _teleport(position_m: Vector3) -> void:
	global_position = position_m
	_last_position = position_m
	global_velocity = Vector3.ZERO


## Hidden subjects can't be seen, photographed, or focused on.
func _set_present(present: bool) -> void:
	visible = present
	collision_layer = _home_layer if present else 0


func key_point() -> Vector3:
	var head := get_node_or_null("Head") as Node3D
	return head.global_position if head else global_position


func sample_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for child in get_children():
		if child is Marker3D:
			points.append(child.global_position)
	if points.is_empty():
		points.append(global_position)
	return points
