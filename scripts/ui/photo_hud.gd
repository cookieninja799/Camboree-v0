class_name PhotoHud
extends Control
## Viewfinder overlay: thirds guides, the round brief, the camera setting dials,
## and the shot reveal (polaroid of the photo, stars on the chimes, pillar bars, tip).

## Pillar keys from PhotoScoring.score() and their plain-language names.
const PILLARS := [["focus", "Focus"], ["exposure", "Exposure"], ["placement", "Framing"], ["gate", "In view"]]
const GOOD := Color(0.45, 0.85, 0.4)
const OKAY := Color(0.95, 0.8, 0.3)
const BAD := Color(0.95, 0.4, 0.35)
const PHOTO_WIDTH := 480

@export var show_guides := true
@export var guide_color := Color(1, 1, 1, 0.35)

var placement_targets := PackedVector2Array():
	set(value):
		placement_targets = value
		queue_redraw()

var _camera: PhotoCamera
var _dials: Array[SettingDial] = []
var _bars := {}  # pillar key -> ProgressBar
var _bar_names := {}  # pillar key -> Label
var _reveal: Tween
var _shot_id := 0

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


func _ready() -> void:
	resized.connect(queue_redraw)
	_build_bars()
	clear_result()


func _draw() -> void:
	if not show_guides:
		return
	var s := size
	for i in [1, 2]:
		draw_line(Vector2(s.x * i / 3.0, 0), Vector2(s.x * i / 3.0, s.y), guide_color)
		draw_line(Vector2(0, s.y * i / 3.0), Vector2(s.x, s.y * i / 3.0), guide_color)
	for target in placement_targets:
		draw_arc(target * s, 10.0, 0.0, TAU, 24, guide_color, 2.0)
	var c := s * 0.5
	draw_line(c - Vector2(6, 0), c + Vector2(6, 0), Color.WHITE)
	draw_line(c - Vector2(0, 6), c + Vector2(0, 6), Color.WHITE)


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
		dial.custom_minimum_size = Vector2(300, 165)
		dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dial.setup(PhotoCamera.SETTING_NAMES[setting], camera.setting_labels(setting),
			camera.setting_index(setting), camera.setting_readout(setting))
		_dial_row.add_child(dial)
		_dials.append(dial)
	camera.settings_changed.connect(_sync_dials)
	_sync_dials()


func dial(setting: PhotoCamera.Setting) -> SettingDial:
	return _dials[setting]


func show_focus(focus_m: float, subject_m: float) -> void:
	var subject_text := "%.1f m" % subject_m if subject_m > 0.0 else "--"
	_settings_label.text = "Focus %.1f m  ·  Subject %s\nQ/E pick dial  ·  R/F turn it\nWheel focus  ·  RMB autofocus  ·  Esc mouse" % [
		focus_m, subject_text,
	]


func _sync_dials() -> void:
	for setting in _dials.size():
		_dials[setting].set_value(_camera.setting_index(setting), _camera.setting_readout(setting))
		_dials[setting].set_selected(setting == _camera.selected)


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
