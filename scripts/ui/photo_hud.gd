class_name PhotoHud
extends Control
## Viewfinder overlay: rule-of-thirds guides, placement targets, settings, and
## the breakdown of the last shot.

@export var show_guides := true
@export var guide_color := Color(1, 1, 1, 0.35)

var placement_targets := PackedVector2Array():
	set(value):
		placement_targets = value
		queue_redraw()

@onready var _settings_label: Label = $SettingsLabel
@onready var _result_label: Label = $ResultLabel
@onready var _flash: ColorRect = $Flash


func _ready() -> void:
	resized.connect(queue_redraw)
	_result_label.text = "Take a photo! (LMB / Space / A)"


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


func show_settings(camera_line: String, focus_m: float, subject_m: float) -> void:
	var subject_text := "%.1f m" % subject_m if subject_m > 0.0 else "--"
	_settings_label.text = "%s\nFocus %.1f m   |   Subject %s\nQ/E pick setting · R/F change · wheel or Z/X focus · RMB/T autofocus · Esc frees mouse" % [
		camera_line, focus_m, subject_text,
	]


func show_result(result: Dictionary) -> void:
	var stars: int = result.stars
	_result_label.text = "%s%s   %.2f\nFocus %.2f   Exposure %.2f   Placement %.2f   Visible %d%%\nBest: %s   Worst: %s\n%s" % [
		"★".repeat(stars), "☆".repeat(5 - stars), result.score,
		result.focus, result.exposure, result.placement, roundi(result.gate * 100.0),
		result.best, result.worst, result.tip,
	]
	_flash.modulate.a = 0.8
	create_tween().tween_property(_flash, "modulate:a", 0.0, 0.25)
