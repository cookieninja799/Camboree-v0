extends Node3D
## Scratchpad scene for scoring v0: one camera, one wandering subject.
## See docs/design/scoring-v0.md.

## Correct exposure at ISO 100. 15 is full sun ("sunny 16"); 13 is hazy sun.
@export var scene_ev := 13.0
@export var config: ScoringConfig

@onready var _camera: PhotoCamera = $Player/Head/PhotoCamera
@onready var _hud: PhotoHud = $HUD/Overlay


func _ready() -> void:
	if config == null:
		config = ScoringConfig.new()
	_camera.scene_ev = scene_ev
	_camera.shot_taken.connect(_on_shot_taken)
	_hud.placement_targets = config.placement_targets


func _process(_delta: float) -> void:
	var subject := _camera.pick_subject()
	var subject_depth := _camera.view_depth(subject.key_point()) if subject else -1.0
	_hud.show_settings(_camera.describe(), _camera.focus_distance, subject_depth)


func _on_shot_taken(shot: ShotData) -> void:
	var result := PhotoScoring.score(shot, config)
	_hud.show_result(result)
	print("Shot: %.2f (%d stars) focus=%.2f exposure=%.2f placement=%.2f gate=%.2f blur=%.3fmm ev_err=%+.2f | %s" % [
		result.score, result.stars, result.focus, result.exposure, result.placement,
		result.gate, result.blur_mm, result.ev_error, result.tip,
	])
