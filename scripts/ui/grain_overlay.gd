class_name GrainOverlay
extends CanvasLayer
## High-ISO grain drawn over the 3D view and under the HUD. It sits outside the
## HUD overlay, so PhotoHud's frame grab (which hides only the overlay) keeps
## the grain on the polaroid. Strength comes from the noise pillar.

const SHADER := preload("res://resources/shaders/grain.gdshader")

## 0 hides the grain (your own eyes aren't grainy), 1 is full strength. Set to
## how far the camera is raised.
var view_amount := 1.0:
	set(value):
		view_amount = value
		_push()

var _amount := 0.0
var _chroma := 0.0
var _rect: ColorRect
var _material: ShaderMaterial


func _init() -> void:
	layer = 0  # above the 3D view, below the HUD (layer 1)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	add_child(_rect)
	_push()


## Sets the grain for an ISO using the same curve as the noise pillar.
func set_iso(iso: float, cfg: ScoringConfig) -> void:
	_amount = 1.0 - PhotoScoring.noise_score(iso, cfg)
	_chroma = clampf(PhotoScoring.log2(iso / 100.0) - cfg.noise_bad_stops, 0.0, 1.0)
	_push()


## Current grain strength before view_amount, 0-1.
func amount() -> float:
	return _amount


func _push() -> void:
	if _material == null:
		return
	var strength := _amount * view_amount
	_material.set_shader_parameter("amount", strength)
	_material.set_shader_parameter("chroma", _chroma * view_amount)
	# Skip the full-screen pass entirely when there's nothing to draw.
	_rect.visible = strength > 0.001
