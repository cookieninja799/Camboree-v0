class_name ScoringSandbox
extends Node3D
## Scratchpad scene for scoring v1, played as a run of Burst-style briefs (the
## wanderer, a dusk portrait, a bird in flight). RoundRunner keeps score; this
## scene sets up the light and subject for each brief and drives the HUD.
## See docs/design/scoring-v1.md.

const DEFAULT_BRIEFS: Array[String] = [
	"res://resources/briefs/r1_wanderer.tres",
	"res://resources/briefs/r2_dusk.tres",
	"res://resources/briefs/r3_bird.tres",
]

## Played in order. Empty loads DEFAULT_BRIEFS.
@export var briefs: Array[Brief] = []
## Lets briefs that ask for it start with the camera settings out of whack.
@export var scramble_on_start := true
## How many attempts at a coached brief show the live "fix your camera" coach.
## 0 = never, -1 = always.
@export var coach_rounds := 1

var runner: RoundRunner
## The current brief's grading.
var config: ScoringConfig
var grain: GrainOverlay
## Shots fired before this (ms) can't move past a finished brief, so a quick
## second press can't skip the reveal of the shot that finished it.
var _reveal_until_ms := 0

@onready var _player: Player = $Player
@onready var _camera: PhotoCamera = $Player/Head/PhotoCamera
@onready var _subject: PhotoSubject = $Subject
@onready var _sun: DirectionalLight3D = $Sun
@onready var _environment: Environment = ($WorldEnvironment as WorldEnvironment).environment
@onready var _hud: PhotoHud = $HUD/Overlay
@onready var _music: AudioStreamPlayer = $Music


func _ready() -> void:
	if briefs.is_empty():
		for path in DEFAULT_BRIEFS:
			briefs.append(load(path))
	_camera.shot_taken.connect(_on_shot_taken)
	grain = GrainOverlay.new()
	add_child(grain)
	_camera.settings_changed.connect(func() -> void: grain.set_iso(_camera.iso, config))
	_hud.bind_camera(_camera)
	_hud.set_viewfinder(_player.is_viewfinder())
	_player.mode_changed.connect(func(mode: Player.Mode) -> void: _hud.set_viewfinder(mode == Player.Mode.VIEWFINDER))
	_camera.focus_state_changed.connect(_hud.set_focus_state)
	_camera.needs_raise.connect(_hud.nudge.bind("Hold RMB (LT) to raise your camera"))
	runner = RoundRunner.new(briefs)
	runner.brief_started.connect(_on_brief_started)
	runner.restart()


func _process(_delta: float) -> void:
	grain.view_amount = _player.ads_amount()
	# Motion blur, like grain, only shows through the raised camera.
	for node in get_tree().get_nodes_in_group(PhotoSubject.GROUP):
		(node as PhotoSubject).trail.exposure_s = _camera.shutter_s * _player.ads_amount()
	var subject := _camera.pick_subject()
	var subject_depth := _camera.view_depth(subject.key_point()) if subject else -1.0
	_hud.show_focus(_camera.focus_distance, subject_depth)
	if coach_active():
		# Score what the camera would capture right now, without taking the shot.
		var shot := _camera.capture(subject)
		var brief := runner.brief()
		var lines := PhotoCoach.advice(PhotoScoring.score(shot, config), shot, _camera.selected, subject != null,
			_player.is_viewfinder(), config, brief.subject_name, brief.subject_behavior == PhotoSubject.Behavior.FLYER)
		_hud.show_coach(lines)


func coach_active() -> bool:
	return runner.state == RoundRunner.State.PLAYING and runner.brief().coach \
		and (coach_rounds < 0 or runner.attempt <= coach_rounds)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_music"):
		_music.stream_paused = not _music.stream_paused


## Sets the scene up for a brief: grading, light, subject, and the brief card.
func _on_brief_started(brief: Brief) -> void:
	config = brief.config if brief.config else ScoringConfig.new()
	_hud.set_config(config)
	_apply_light(brief)
	_subject.wander_range = brief.wander_range
	_subject.wander_speed = brief.wander_speed
	_subject.behavior = brief.subject_behavior  # also resets it to its start
	grain.set_iso(_camera.iso, config)
	if brief.scramble and scramble_on_start and runner.attempt == 1:
		_camera.scramble()
	# A fresh brief starts with a clean HUD: no polaroid, bars, or tip left over
	# from the last shot.
	_hud.clear_result()
	_hud.hide_coach()
	if runner.attempt == 1:
		_hud.show_card(_card_title(brief), _card_body(brief))
	_show_brief()


func _apply_light(brief: Brief) -> void:
	_camera.scene_ev = brief.scene_ev
	_camera.render_gain = brief.render_gain
	_sun.light_energy = brief.sun_energy
	_sun.light_color = brief.sun_color
	var sky := _environment.sky.sky_material as ProceduralSkyMaterial
	if sky:
		sky.sky_top_color = brief.sky_top_color
		sky.sky_horizon_color = brief.sky_horizon_color
		sky.ground_horizon_color = brief.sky_horizon_color


func _on_shot_taken(shot: ShotData) -> void:
	if runner.state != RoundRunner.State.PLAYING:
		if Time.get_ticks_msec() < _reveal_until_ms:
			return  # still revealing the shot that ended the brief
		runner.advance()  # any shot after a brief ends moves on
		if runner.state == RoundRunner.State.DONE:
			_show_summary()
		return
	var brief := runner.brief()
	var result := PhotoScoring.score(shot, config)
	var stamp := ""
	if not runner.record(result):
		var missed: Array[String] = []
		for requirement in brief.requirements:
			if requirement.required and not requirement.evaluate(result):
				missed.append(requirement.describe())
		# The broken rule is the whole story; the general tip would just repeat it
		# and push the text into the controls hint below.
		result.tip = "Doesn't count: %s." % ", ".join(missed)
		stamp = "DOESN'T COUNT"
	if runner.state == RoundRunner.State.WON:
		stamp = "BRIEF COMPLETE" + (" +BONUS" if runner.bonus_met else "")

	if not coach_active():
		_hud.hide_coach()
	_hud.hide_card()
	Sfx.play_result(self, result.stars)
	_hud.present_shot(result, stamp)
	# Update the brief once the stars have finished popping, so it doesn't spoil them.
	var reveal_s := Sfx.reveal_time(result.stars)
	_reveal_until_ms = Time.get_ticks_msec() + int(reveal_s * 1000.0) + 300
	get_tree().create_timer(reveal_s).timeout.connect(_show_brief)
	print("Shot: %.2f (%d stars) focus=%.2f exposure=%.2f placement=%.2f motion=%.2f noise=%.2f gate=%.2f blur=%.3fmm smear=%.3fmm ev_err=%+.2f | %s" % [
		result.score, result.stars, result.focus, result.exposure, result.placement, result.motion, result.noise,
		result.gate, result.blur_mm, result.motion_blur_mm, result.ev_error, result.tip,
	])


func _show_brief() -> void:
	var brief := runner.brief()
	match runner.state:
		RoundRunner.State.PLAYING:
			_hud.show_brief("%s  ·  %s  ·  %d shot%s left" % [
				brief.title, brief.goal_text(), runner.shots_left, "" if runner.shots_left == 1 else "s",
			])
		RoundRunner.State.WON:
			var bonus := "  +BONUS" if runner.bonus_met else ""
			var next := "Shoot for the next brief" if runner.index + 1 < runner.briefs.size() else "Shoot to see your results"
			_hud.show_brief("BRIEF COMPLETE%s!  %s" % [bonus, next], PhotoHud.GOOD)
		RoundRunner.State.LOST:
			_hud.show_brief("Out of shots. Best: %d stars. Shoot to retry" % runner.best_stars, PhotoHud.BAD)
		RoundRunner.State.DONE:
			_hud.show_brief("All briefs done! Shoot to play again", PhotoHud.GOOD)


func _show_summary() -> void:
	_hud.clear_result()
	_hud.hide_coach()
	var lines := PackedStringArray()
	for result in runner.results:
		lines.append("%s   %s%s   +%d" % [
			result.title, "★".repeat(result.best_stars), "  bonus!" if result.bonus else "", result.reward,
		])
	lines.append("")
	lines.append("Total: %d" % runner.total_reward())
	_hud.show_card("Shoot complete", "\n".join(lines), true)
	_show_brief()


func _card_title(brief: Brief) -> String:
	return "Brief %d of %d: %s" % [runner.index + 1, runner.briefs.size(), brief.title]


func _card_body(brief: Brief) -> String:
	var lines := PackedStringArray([brief.ask, "", brief.goal_text()])
	for requirement in brief.requirements:
		lines.append(requirement.describe())
	lines.append("")
	lines.append("Raise your camera (hold RMB) to start")
	return "\n".join(lines)
