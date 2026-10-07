class_name MotionTrail
extends Node3D
## Motion blur for one subject, as a ghost trail: see-through copies of the
## subject's meshes spread over where it travelled while the shutter was open
## (velocity * exposure_s behind it). That's the same v·t the motion pillar
## scores, so the blur you see matches the grade. It's drawn in the 3D view,
## so the viewfinder and the polaroid grab both show it.

## How long the shutter stays open, in seconds. 0 turns the trail off (your
## own eyes don't smear things; only the raised camera does).
var exposure_s := 0.0

## Trails shorter than this (meters) aren't worth drawing.
const MIN_LENGTH_M := 0.02
## Never stretch further than this, so a teleport doesn't paint a streak across the map.
const MAX_LENGTH_M := 4.0
## One copy per this many meters of trail, up to MAX_GHOSTS.
const GHOST_SPACING_M := 0.04
const MAX_GHOSTS := 16

var _subject: PhotoSubject
var _sources: Array[MeshInstance3D] = []
var _ghosts: Array[MeshInstance3D] = []  # MAX_GHOSTS per source, source-major


func _ready() -> void:
	_subject = get_parent() as PhotoSubject
	for child in _subject.get_children():
		if child is MeshInstance3D:
			_sources.append(child)
	for source in _sources:
		for i in MAX_GHOSTS:
			var ghost := MeshInstance3D.new()
			ghost.mesh = source.mesh
			ghost.material_override = source.material_override
			ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			ghost.top_level = true
			ghost.visible = false
			add_child(ghost)
			_ghosts.append(ghost)


## Length of the smear in meters for the current velocity and exposure.
func length_m() -> float:
	return minf(_subject.global_velocity.length() * exposure_s, MAX_LENGTH_M)


func _process(_delta: float) -> void:
	var length := length_m()
	var count := 0 if length < MIN_LENGTH_M else clampi(ceili(length / GHOST_SPACING_M), 2, MAX_GHOSTS)
	# Each copy (and the subject itself) covers 1/count of the exposure. Copies
	# overlap, so they can be a bit more solid than 1/count without washing out.
	var see_through := 0.0 if count == 0 else clampf(1.0 - 2.0 / count, 0.0, 0.92)
	var back := -_subject.global_velocity.normalized() * length
	for s in _sources.size():
		var source := _sources[s]
		source.transparency = see_through
		for i in MAX_GHOSTS:
			var ghost := _ghosts[s * MAX_GHOSTS + i]
			ghost.visible = i + 1 < count
			if not ghost.visible:
				continue
			ghost.transparency = see_through
			ghost.global_transform = source.global_transform.translated(back * float(i + 1) / float(count - 1))
