class_name PhotoSubject
extends CharacterBody3D
## Something worth photographing. Child Marker3Ds are the visibility sample
## points, and the one named "Head" is the key point that focus is scored on.

const GROUP := &"photo_subject"

## Sandbox wandering: slides back and forth along this axis. 0 range = stand still.
@export var wander_axis := Vector3.RIGHT
@export var wander_range := 3.0
@export var wander_speed := 0.6

var _origin: Vector3
var _time := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	_origin = global_position


func _physics_process(delta: float) -> void:
	if wander_range <= 0.0:
		return
	_time += delta * wander_speed
	# sin() slows down at the ends, which gives the player a "moment" to catch.
	global_position = _origin + wander_axis.normalized() * sin(_time) * wander_range


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
