class_name SettingDial
extends Control
## A camera dial rising from the bottom of the screen. The current value sits
## under the pointer at 12 o'clock, and changing it turns the dial. The selected
## dial lifts up and shows curved "turn me" arrows.

const STEP := 0.4188790205  # 24 degrees between values
const VISIBLE_HALF_ANGLE := 1.25  # radians either side of 12 o'clock that show ticks
const LIFT_PX := 14.0

@export var radius := 130.0
@export var body_color := Color(0.1, 0.1, 0.13, 0.82)
@export var rim_color := Color(0.88, 0.87, 0.82)
@export var accent := Color(1.0, 0.78, 0.2)

var title := ""
## Quick-access key shown as a small badge next to the title (e.g. "1").
var hotkey := ""
var labels := PackedStringArray()
var readout := ""
var index := 0
var selected := false
## Don't click when the value changes (the focus ring moves continuously during
## autofocus; the camera plays its own click for manual turns).
var silent := false

# Animated: which value faces the pointer (fractional mid-turn), and how far the dial is lifted (0-1).
var _shown := 0.0:
	set(value):
		_shown = value
		queue_redraw()
var _lift := 0.0:
	set(value):
		_lift = value
		queue_redraw()
var _tweens := {}
var _target := 0.0


## `position` is an index into `p_labels`; fractional values sit between marks.
func setup(p_title: String, p_labels: PackedStringArray, position: float, p_readout: String) -> void:
	title = p_title
	labels = p_labels
	index = roundi(position)
	readout = p_readout
	_target = position
	_shown = position


## Turns the dial to a new position, with a click when it lands on a new mark.
func set_value(position: float, p_readout: String) -> void:
	readout = p_readout
	queue_redraw()
	if is_equal_approx(position, _target):
		return
	_target = position
	var new_index := roundi(position)
	var moved_mark := new_index != index
	index = new_index
	_animate("_shown", position, 0.16)
	if moved_mark and not silent:
		Sfx.play(self, Sfx.dial_tick())


func set_selected(on: bool) -> void:
	if on == selected:
		return
	selected = on
	_animate("_lift", 1.0 if on else 0.0, 0.12)


func _animate(property: String, target: float, duration: float) -> void:
	if _tweens.has(property):
		_tweens[property].kill()
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, property, target, duration)
	_tweens[property] = tween


func _draw() -> void:
	var font := get_theme_default_font()
	var alpha := lerpf(0.55, 1.0, _lift)
	var rim := Color(rim_color, alpha)
	var center := Vector2(size.x * 0.5, size.y + radius * 0.1 - _lift * LIFT_PX)

	draw_circle(center, radius, Color(body_color, body_color.a * lerpf(0.75, 1.0, _lift)))
	draw_arc(center, radius, PI, TAU, 64, rim, 3.0, true)
	draw_arc(center, radius - 18.0, PI, TAU, 64, Color(rim, alpha * 0.25), 1.0, true)

	# Knurled ticks: a major tick and label per value, a minor tick between values.
	for i in labels.size():
		var angle := -PI / 2.0 + (i - _shown) * STEP
		if absf(angle + PI / 2.0) <= VISIBLE_HALF_ANGLE:
			var dir := Vector2.from_angle(angle)
			var color := Color(accent, alpha) if i == index else rim
			draw_line(center + dir * (radius - 14.0), center + dir * radius, color, 2.0, true)
			draw_set_transform(center + dir * (radius - 30.0), angle + PI / 2.0)
			_draw_centered(font, labels[i], Vector2.ZERO, 15 if i == index else 13, color)
			draw_set_transform(Vector2.ZERO)
		var minor := angle + STEP * 0.5
		if i < labels.size() - 1 and absf(minor + PI / 2.0) <= VISIBLE_HALF_ANGLE:
			var minor_dir := Vector2.from_angle(minor)
			draw_line(center + minor_dir * (radius - 7.0), center + minor_dir * radius, rim, 1.0, true)

	# Fixed pointer at 12 o'clock.
	var top := center + Vector2(0.0, -radius)
	draw_colored_polygon(PackedVector2Array([top + Vector2(-8, -12), top + Vector2(8, -12), top + Vector2(0, -1)]), Color(accent, alpha))

	_draw_centered(font, readout, center + Vector2(0.0, -radius * 0.45), 26, Color(Color.WHITE, alpha), true)
	var title_pos := center + Vector2(0.0, -radius * 0.2)
	_draw_centered(font, title, title_pos, 13, rim)
	if hotkey != "":
		var half_width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x * 0.5
		var badge := Rect2(title_pos + Vector2(-half_width - 22.0, -8.0), Vector2(16.0, 16.0))
		draw_rect(badge, Color(accent if selected else rim_color, alpha * 0.9), false, 1.5)
		_draw_centered(font, hotkey, badge.get_center(), 11, Color(accent if selected else rim_color, alpha))

	if selected:
		_draw_turn_arrows(center)


## Curved double-headed arrow over the dial: "turn me".
func _draw_turn_arrows(center: Vector2) -> void:
	var r := radius + 20.0
	var spread := 0.55
	var color := Color(accent, _lift)
	draw_arc(center, r, -PI / 2.0 - spread, -PI / 2.0 + spread, 24, color, 3.0, true)
	for side: float in [-1.0, 1.0]:
		var angle := -PI / 2.0 + spread * side
		var tip := center + Vector2.from_angle(angle) * r
		var along := Vector2.from_angle(angle + PI / 2.0) * side  # tangent, pointing away from 12 o'clock
		var across := Vector2.from_angle(angle)
		draw_colored_polygon(PackedVector2Array([tip + along * 10.0, tip - along * 2.0 + across * 7.0, tip - along * 2.0 - across * 7.0]), color)


func _draw_centered(font: Font, text: String, pos: Vector2, font_size: int, color: Color, outline := false) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := pos + Vector2(-width * 0.5, font_size * 0.35)
	if outline:
		draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(0, 0, 0, color.a))
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
