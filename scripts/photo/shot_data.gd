class_name ShotData
extends Resource
## Everything the scorer needs to know about one shutter press.
## World distances are meters; focal length is millimeters.

@export var focal_length_mm := 50.0
@export var aperture_n := 5.6
## Exposure time in seconds (1/250 s = 0.004).
@export var shutter_s := 1.0 / 250.0
@export var iso := 100.0
@export var focus_distance_m := 3.0
## Depth of the subject's key point (the eyes) along the camera's view axis.
@export var subject_distance_m := 3.0
## Key point on screen, normalized: (0, 0) is top-left, (1, 1) is bottom-right.
@export var subject_screen_pos := Vector2(0.5, 0.5)
## Fraction of the subject's sample points that are in frame and unobstructed.
@export_range(0.0, 1.0) var visibility := 1.0
## Correct exposure value for the scene at ISO 100.
@export var scene_ev := 13.0
