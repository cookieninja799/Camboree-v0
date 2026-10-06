class_name PhotoHud
extends Control
## Overlay for both modes. Exploring: a center dot and compact setting dials.
## Viewfinder: thirds guides, framing zones, the focus bracket, and full-size dials.
## Plus the round brief, the coach, and the shot reveal (polaroid, stars, bars, tip).

## Pillar keys from PhotoScoring.score() and their plain-language names.
const PILLARS := [["focus", "Focus"], ["exposure", "Exposure"], ["placement", "Framing"], ["gate", "In view"]]
const GOOD := Color(0.45, 0.85, 0.4)
const OKAY := Color(0.95, 0.8, 0.3)
const BAD := Color(0.95, 0.4, 0.35)
const PHOTO_WIDTH := 480
const COMPACT_DIAL_SCALE := 0.55
const BRACKET_SIZE := Vector2(70, 46)

@export var show_guides := true
@export var guide_color := Color(1, 1, 1, 0.35)

var placement_targets := PackedVector2Array():
	set(value):
		placement_targets = value
		queue_redraw()
## Framing scores full marks inside this radius of a target (normalized screen units).
var placement_ok_radius := 0.05:
	set(value):
		placement_ok_radius = value
		queue_redraw()

var _camera: PhotoCamera
var _dials: Array[SettingDial] = []
var _bars := {}  # pillar key -> ProgressBar
var _bar_names := {}  # pillar key -> Label
var _reveal: Tween
var _shot_id := 0
var _viewfinder := true
var _focus_state := PhotoCamera.FocusState.IDLE
var _dial_tween: Tween

@onready var _settings_label: Label = $SettingsLabel
@onready var _dial_row: HBoxContainer = $Dials
@onready var _brief_label: Label = $BriefLabel
@onready var _result: Control = $Result
@onready var _bar_grid: GridContainer = $Result/Bars
@onready var _tip_label: Label = $Result/TipLabel
@onready var _polaroid: Control = $Polaroid
@onready var _photo: TextureRect = $Polaroid/VBox/Photo
@onready var _stars: StarRow = $Polaroid/VBox/Stars
@onready var _flash: ColorRect = $Flash
@onready var _coach: RichTextLabel = $Coach
@onready var _nudge_label: Label = $NudgeLabel


func _ready() -> void:
	resized.connect(queue_redraw)
	resized.connect(_update_dial_pivot)
	_build_bars()
	clear_result()
	_nudge_label.modulate.a = 0.0


func _draw() -> void:
	var s := size
	var c := s * 0.5
	if not _viewfinder:
		# Exploring: just a small aim dot, so you can pre-aim before raising.
		draw_circle(c, 3.0, Color(1, 1, 1, 0.8))
		draw_arc(c, 3.5, 0.0, TAU, 16, Color(0, 0, 0, 0.5), 1.0, true)
		return
	_draw_focus_bracket(c)
	if not show_guides:
		return
	for i in [1, 2]:
		draw_line(Vector2(s.x * i / 3.0, 0), Vector2(s.x * i / 3.0, s.y), guide_color)
		draw_line(Vector2(0, s.y * i / 3.0), Vector2(s.x, s.y * i / 3.0), guide_color)
	# The full-marks framing zones: ellipses because the radius is in normalized
	# units, so it stretches with the screen's aspect ratio.
	for target in placement_targets:
		var zone := PackedVector2Array()
		for i in 33:
			var angle := TAU * i / 32.0
			zone.append(target * s + Vector2(cos(angle) * s.x, sin(angle) * s.y) * placement_ok_radius)
		draw_polyline(zone, guide_color, 1.5, true)
		draw_circle(target * s, 2.5, guide_color)


## Corner brackets at the focus point: white while the lens racks, green when
## focus locks, red when autofocus gives up.
func _draw_focus_bracket(c: Vector2) -> void:
	var color := Color(1, 1, 1, 0.9)
	match _focus_state:
		PhotoCamera.FocusState.LOCKED:
			color = GOOD
		PhotoCamera.FocusState.FAILED:
			color = BAD
	var h := BRACKET_SIZE * 0.5
	var arm := 12.0
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var p: Vector2 = c + h * corner
		draw_line(p, p - Vector2(arm * corner.x, 0), color, 2.0)
		draw_line(p, p - Vector2(0, arm * corner.y), color, 2.0)
	if _focus_state == PhotoCamera.FocusState.DRIVING:
		draw_circle(c, 2.0, color)


## Switches the overlay between exploring and looking through the camera.
func set_viewfinder(on: bool) -> void:
	_viewfinder = on
	queue_redraw()
	_update_dial_pivot()
	if _dial_tween:
		_dial_tween.kill()
	_dial_tween = create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var dial_scale := 1.0 if on else COMPACT_DIAL_SCALE
	_dial_tween.tween_property(_dial_row, "scale", Vector2(dial_scale, dial_scale), 0.15)
	_dial_tween.tween_property(_dial_row, "modulate:a", 1.0 if on else 0.75, 0.15)


func is_viewfinder() -> bool:
	return _viewfinder


func set_focus_state(state: PhotoCamera.FocusState) -> void:
	_focus_state = state
	queue_redraw()


## Shown when the player tries to shoot with the camera lowered.
func nudge(text: String) -> void:
	_nudge_label.text = text
	_nudge_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(0.9)
	tween.tween_property(_nudge_label, "modulate:a", 0.0, 0.4)


func _update_dial_pivot() -> void:
	_dial_row.pivot_offset = Vector2(_dial_row.size.x * 0.5, _dial_row.size.y)


func show_brief(text: String, color := Color.WHITE) -> void:
	_brief_label.text = text
	_brief_label.add_theme_color_override("font_color", color)


## Builds one dial per camera setting and keeps them in sync with the camera.
func bind_camera(camera: PhotoCamera) -> void:
	_camera = camera
	for child in _dial_row.get_children():
		child.queue_free()
	_dials.clear()
	for setting in PhotoCamera.Setting.values():
		var dial := SettingDial.new()
		dial.custom_minimum_size = Vector2(250, 165)
		dial.radius = 115.0
		dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dial.silent = setting == PhotoCamera.Setting.FOCUS
		dial.hotkey = str(setting + 1)
		dial.setup(PhotoCamera.SETTING_NAMES[setting], camera.setting_labels(setting),
			camera.setting_position(setting), camera.setting_readout(setting))
		_dial_row.add_child(dial)
		_dials.append(dial)
	camera.settings_changed.connect(_sync_dials)
	_sync_dials()


func dial(setting: PhotoCamera.Setting) -> SettingDial:
	return _dials[setting]


func show_focus(focus_m: float, subject_m: float) -> void:
	var subject_text := "%.1f m" % subject_m if subject_m > 0.0 else "--"
	var controls := "LMB shoot  ·  Shift autofocus (hold = track)\n1-5 or Q/E pick dial  ·  Wheel turns it  ·  release RMB to lower" if _viewfinder \
		else "Hold RMB raise camera  ·  WASD move\n1-5 or Q/E pick dial  ·  Wheel turns it  ·  M music  ·  Esc mouse"
	_settings_label.text = "Focus %.1f m  ·  Subject %s\n%s" % [focus_m, subject_text, controls]


func _sync_dials() -> void:
	for setting in _dials.size():
		_dials[setting].set_value(_camera.setting_position(setting), _camera.setting_readout(setting))
		_dials[setting].set_selected(setting == _camera.selected)


## The tutorial checklist: one line per pillar, green when fixed.
func show_coach(lines: Array[Dictionary]) -> void:
	var text := ""
	if PhotoCoach.all_ok(lines):
		text = "[color=#%s]All set! Take the shot.[/color]\n" % GOOD.to_html(false)
	else:
		text = "Fix your camera before you shoot:\n"
	for line in lines:
		if line.ok:
			text += "[color=#%s]OK[/color]   %s\n" % [GOOD.to_html(false), line.text]
		else:
			text += "[color=#%s]FIX[/color]  [color=#%s]%s[/color]\n" % [BAD.to_html(false), OKAY.to_html(false), line.text]
	text = text.strip_edges()
	if _coach.text != text:
		_coach.text = text
	_coach.visible = true


func hide_coach() -> void:
	_coach.visible = false


func is_coach_visible() -> bool:
	return _coach.visible


func clear_result() -> void:
	_shot_id += 1
	if _reveal:
		_reveal.kill()
	_result.visible = false
	_polaroid.visible = false


## Grabs the frame, drops it in as a polaroid, then reveals stars, bars, and tip
## on the same beat as Sfx.play_result().
func present_shot(result: Dictionary) -> void:
	_shot_id += 1
	var id := _shot_id
	var photo := await _grab_frame()
	if id != _shot_id:
		return  # a newer shot (or a reset) took over while we waited a frame
	_flash.modulate.a = 0.8
	create_tween().tween_property(_flash, "modulate:a", 0.0, 0.25)
	_drop_polaroid(photo)
	_reveal_result(result)


## The current frame without the HUD on it, downscaled. Null if there's no
## image to read (e.g. headless).
func _grab_frame() -> Texture2D:
	# The headless renderer never draws, so frame_post_draw would never fire.
	if DisplayServer.get_name() == "headless":
		return null
	visible = false
	await RenderingServer.frame_post_draw
	visible = true
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return null
	image.resize(PHOTO_WIDTH, roundi(float(PHOTO_WIDTH) * image.get_height() / image.get_width()), Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(image)


func _drop_polaroid(photo: Texture2D) -> void:
	_photo.texture = photo
	_stars.filled = 0
	_polaroid.visible = true
	_polaroid.pivot_offset = _polaroid.size * 0.5
	var rest := Vector2(size.x - _polaroid.size.x - 32.0, 72.0)
	_polaroid.position = Vector2(rest.x, -_polaroid.size.y - 40.0)
	_polaroid.rotation_degrees = randf_range(-14.0, 14.0)
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_polaroid, "position", rest, 0.4)
	tween.tween_property(_polaroid, "rotation_degrees", randf_range(-5.0, 5.0), 0.4)


func _reveal_result(result: Dictionary) -> void:
	if _reveal:
		_reveal.kill()
	_result.visible = true
	_tip_label.text = result.tip
	_tip_label.modulate.a = 0.0
	for key in _bars:
		var value: float = result[key]
		_bars[key].value = 0.0
		(_bars[key].get_theme_stylebox("fill") as StyleBoxFlat).bg_color = _bar_color(value)
		_bar_names[key].add_theme_color_override("font_color", OKAY if key == result.worst and value < 0.9 else Color.WHITE)

	var stars: int = result.stars
	_reveal = create_tween().set_parallel()
	for key in _bars:
		_reveal.tween_property(_bars[key], "value", float(result[key]), Sfx.reveal_time(stars)) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for i in stars:
		_reveal.tween_callback(_stars.add_star).set_delay(Sfx.star_time(i))
	_reveal.tween_property(_tip_label, "modulate:a", 1.0, 0.2).set_delay(Sfx.reveal_time(stars))


func _build_bars() -> void:
	for pillar in PILLARS:
		var name_label := Label.new()
		name_label.text = pillar[1]
		_outline(name_label)
		var bar := ProgressBar.new()
		bar.max_value = 1.0
		bar.step = 0.0
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(220, 14)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var background := StyleBoxFlat.new()
		background.bg_color = Color(0, 0, 0, 0.45)
		background.set_corner_radius_all(4)
		var fill := StyleBoxFlat.new()
		fill.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("background", background)
		bar.add_theme_stylebox_override("fill", fill)
		_bar_grid.add_child(name_label)
		_bar_grid.add_child(bar)
		_bars[pillar[0]] = bar
		_bar_names[pillar[0]] = name_label


static func _bar_color(value: float) -> Color:
	if value >= 0.75:
		return GOOD
	return OKAY if value >= 0.4 else BAD


static func _outline(label: Label) -> void:
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
