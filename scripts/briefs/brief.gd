class_name Brief
extends Resource
## One job for the photographer: what the client asks for, how it's graded
## (its own ScoringConfig weights), how many shots you get, and the scene it's
## shot in (light and subject). RoundRunner plays a list of these in order.

## TARGET_STARS wins as soon as a shot reaches target_stars. BEST_OF plays out
## every shot, then wins if the best one reached target_stars.
enum WinMode { TARGET_STARS, BEST_OF }

@export var title := ""
## What the client wants, in their words. Shown on the brief card.
@export_multiline var ask := ""
@export_range(1, 5) var target_stars := 4
@export var shot_limit := 5
@export var win_mode := WinMode.TARGET_STARS
## Grading weights for this job. Null uses the default config.
@export var config: ScoringConfig
## Required ones must all pass for a shot to count; optional ones earn the bonus.
@export var requirements: Array[BriefRequirement] = []
@export var reward := 100
@export var bonus_reward := 50
## Show the live "fix your camera" coach (the tutorial brief).
@export var coach := false
## Start with the camera settings knocked out of whack.
@export var scramble := false

@export_group("Light")
## Correct exposure at ISO 100. 13 is hazy sun; 2 is deep dusk.
@export var scene_ev := 13.0
@export var sun_energy := 1.0
@export var sun_color := Color.WHITE
@export var sky_top_color := Color(0.32, 0.55, 0.9)
@export var sky_horizon_color := Color(0.75, 0.82, 0.92)
## Brightens the rendered image so a correct exposure of a dim scene doesn't
## look murky. Grading never sees it.
@export var render_gain := 1.0

@export_group("Subject")
## How the coach refers to the subject ("the wanderer", "the bird").
@export var subject_name := "the wanderer"
@export var subject_behavior := PhotoSubject.Behavior.WANDER
@export var wander_range := 3.0
@export var wander_speed := 0.6


## True if the shot passes every required requirement.
func meets_required(result: Dictionary) -> bool:
	for requirement in requirements:
		if requirement.required and not requirement.evaluate(result):
			return false
	return true


## True if the shot passes every optional requirement (the bonus).
func meets_optional(result: Dictionary) -> bool:
	for requirement in requirements:
		if not requirement.required and not requirement.evaluate(result):
			return false
	return true


func has_bonus() -> bool:
	return requirements.any(func(r: BriefRequirement) -> bool: return not r.required)


## The goal in one line: "Get a 4-star shot in 5" or "Best of 8: 3 stars or more".
func goal_text() -> String:
	if win_mode == WinMode.BEST_OF:
		return "Best of %d: %d stars or more" % [shot_limit, target_stars]
	return "Get a %d-star shot in %d" % [target_stars, shot_limit]
