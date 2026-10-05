class_name StarRow
extends Control
## Five drawn stars (no font glyphs needed). The newest filled star pops.

@export var fill_color := Color(1.0, 0.78, 0.2)
@export var empty_color := Color(0.55, 0.55, 0.55)

var filled := 0:
	set(value):
		filled = clampi(value, 0, 5)
		queue_redraw()
## Scale of the newest filled star; tweened from >1 back to 1 for a pop.
var pop := 1.0:
	set(value):
		pop = value
		queue_redraw()


## Fills one more star with a little pop.
func add_star() -> void:
	filled += 1
	pop = 1.5
	create_tween().tween_property(self, "pop", 1.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var cell := size.x / 5.0
	var radius := minf(cell, size.y) * 0.4
	for i in 5:
		var center := Vector2(cell * (i + 0.5), size.y * 0.5)
		if i < filled:
			var grow := pop if i == filled - 1 else 1.0
			draw_colored_polygon(_star(center, radius * grow), fill_color)
		else:
			var outline := _star(center, radius)
			outline.append(outline[0])
			draw_polyline(outline, empty_color, 2.0, true)


func _star(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 10:
		var angle := -PI / 2.0 + i * PI / 5.0
		var r := radius if i % 2 == 0 else radius * 0.45
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	return points
