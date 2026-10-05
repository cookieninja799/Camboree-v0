class_name ScoringSandbox
extends Node3D
## Scratchpad scene for scoring v0, played as a tiny Burst-style round:
## get a `target_stars` shot of the wanderer within `shots_per_round` shots.
## See docs/design/scoring-v0.md.

enum RoundState { PLAYING, WON, LOST }

## Correct exposure at ISO 100. 15 is full sun ("sunny 16"); 13 is hazy sun.
@export var scene_ev := 13.0
@export var config: ScoringConfig
@export_range(1, 5) var target_stars := 4
@export var shots_per_round := 5

var round_state := RoundState.PLAYING
var shots_left := 0
var best_stars := 0

@onready var _camera: PhotoCamera = $Player/Head/PhotoCamera
@onready var _hud: PhotoHud = $HUD/Overlay


func _ready() -> void:
	if config == null:
		config = ScoringConfig.new()
	_camera.scene_ev = scene_ev
	_camera.shot_taken.connect(_on_shot_taken)
	_hud.placement_targets = config.placement_targets
	_hud.bind_camera(_camera)
	start_round()


func _process(_delta: float) -> void:
	var subject := _camera.pick_subject()
	var subject_depth := _camera.view_depth(subject.key_point()) if subject else -1.0
	_hud.show_focus(_camera.focus_distance, subject_depth)


func start_round() -> void:
	round_state = RoundState.PLAYING
	shots_left = shots_per_round
	best_stars = 0
	_hud.clear_result()
	_show_brief()


func _on_shot_taken(shot: ShotData) -> void:
	if round_state != RoundState.PLAYING:
		start_round()  # any shot after the round ends starts a new one
		return
	var result := PhotoScoring.score(shot, config)
	shots_left -= 1
	best_stars = maxi(best_stars, result.stars)
	if best_stars >= target_stars:
		round_state = RoundState.WON
	elif shots_left <= 0:
		round_state = RoundState.LOST

	Sfx.play_result(self, result.stars)
	_hud.present_shot(result)
	# Update the brief once the stars have finished popping, so it doesn't spoil them.
	get_tree().create_timer(Sfx.reveal_time(result.stars)).timeout.connect(_show_brief)
	print("Shot: %.2f (%d stars) focus=%.2f exposure=%.2f placement=%.2f gate=%.2f blur=%.3fmm ev_err=%+.2f | %s" % [
		result.score, result.stars, result.focus, result.exposure, result.placement,
		result.gate, result.blur_mm, result.ev_error, result.tip,
	])


func _show_brief() -> void:
	match round_state:
		RoundState.PLAYING:
			_hud.show_brief("Get a %d-star shot of the wanderer  ·  %d shot%s left" % [
				target_stars, shots_left, "" if shots_left == 1 else "s",
			])
		RoundState.WON:
			_hud.show_brief("YOU WIN!  Shoot to play again", PhotoHud.GOOD)
		RoundState.LOST:
			_hud.show_brief("Out of shots. Best: %d stars. Shoot to retry" % best_stars, PhotoHud.BAD)
