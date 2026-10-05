class_name ScoringConfig
extends Resource
## Every tunable number in scoring v0. Edit the .tres in the inspector rather
## than changing code. See docs/design/scoring-v0.md.

@export_group("Weights")
@export var focus_weight := 0.5
@export var exposure_weight := 0.3
@export var placement_weight := 0.2

@export_group("Focus")
## Circle of confusion in mm. 0.03 is the full-frame convention.
@export var coc_mm := 0.03
## Blur at or below coc_mm * this is perfectly sharp.
@export var sharp_coc_mult := 0.5
## Blur at or above coc_mm * this scores zero.
@export var soft_coc_mult := 3.0

@export_group("Exposure")
## Errors up to this many stops still score 1.
@export var exposure_ok_stops := 0.5
## Errors at or beyond this many stops score 0.
@export var exposure_bad_stops := 2.5

@export_group("Placement")
## Within this distance of a target (normalized screen units) framing scores 1,
## like the "close enough" zones focus and exposure have.
@export var placement_ok_radius := 0.06
## At or beyond this distance from every target, framing scores 0.
@export var placement_bad_radius := 0.25
## Rule-of-thirds intersections plus the center.
@export var placement_targets := PackedVector2Array([
	Vector2(1.0 / 3.0, 1.0 / 3.0),
	Vector2(2.0 / 3.0, 1.0 / 3.0),
	Vector2(1.0 / 3.0, 2.0 / 3.0),
	Vector2(2.0 / 3.0, 2.0 / 3.0),
	Vector2(0.5, 0.5),
])

@export_group("Stars")
## One star is earned per threshold reached. Array[float] (64-bit), not
## PackedFloat32Array, so a score of exactly 0.2 reaches the 0.2 threshold.
@export var star_thresholds: Array[float] = [0.2, 0.4, 0.6, 0.8, 0.9]
