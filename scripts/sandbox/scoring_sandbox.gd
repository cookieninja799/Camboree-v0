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
## Start with the camera settings out of whack so the player learns to fix them.
@export var scramble_on_start := true
## How many rounds show the live "fix your camera" coach. 0 = never, -1 = always.
@export var coach_rounds := 1

var round_state := RoundState.PLAYING
var shots_left := 0
var best_stars := 0
var rounds_started := 0

@onready var _player: Player = $Player
@onready var _camera: PhotoCamera = $Player/Head/PhotoCamera
@onready var _hud: PhotoHud = $HUD/Overlay
@onready var _music: AudioStreamPlayer = $Music


func _ready() -> void:
	if config == null:
		config = ScoringConfig.new()
	_camera.scene_ev = scene_ev
	_camera.shot_taken.connect(_on_shot_taken)
	_hud.placement_targets = config.placement_targets
	_hud.placement_ok_radius = config.placement_ok_radius
	if scramble_on_start:
		_camera.scramble()
	_hud.bind_camera(_camera)
	_hud.set_viewfinder(_player.is_viewfinder())
	_player.mode_changed.connect(func(mode: Player.Mode) -> void: _hud.set_viewfinder(mode == Player.Mode.VIEWFINDER))
	_camera.focus_state_changed.connect(_hud.set_focus_state)
	_camera.needs_raise.connect(_hud.nudge.bind("Hold RMB (LT) to raise your camera"))
	start_round()


func _process(_delta: float) -> void:
	var subject := _camera.pick_subject()
	var subject_depth := _camera.view_depth(subject.key_point()) if subject else -1.0
	_hud.show_focus(_camera.focus_distance, subject_depth)
	if coach_active():
		# Score what the camera would capture right now, without taking the shot.
		var shot := _camera.capture(subject)
		var lines := PhotoCoach.advice(PhotoScoring.score(shot, config), shot, _camera.selected, subject != null, _player.is_viewfinder())
		_hud.show_coach(lines)


func coach_active() -> bool:
	return round_state == RoundState.PLAYING and (coach_rounds < 0 or rounds_started <= coach_rounds)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_music"):
		_music.stream_paused = not _music.stream_paused


func start_round() -> void:
	round_state = RoundState.PLAYING
	shots_left = shots_per_round
	best_stars = 0
	rounds_started += 1
	_hud.clear_result()
	_hud.hide_coach()
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

	if not coach_active():
		_hud.hide_coach()
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
