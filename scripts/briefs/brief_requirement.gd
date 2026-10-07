class_name BriefRequirement
extends Resource
## One condition a brief puts on a shot, checked against PhotoScoring.score()'s
## result: "noise at least 0.5", "motion at least 0.8". Required ones decide
## whether a shot counts at all; optional ones earn the brief's bonus.

enum Op { AT_LEAST, AT_MOST }

## A key from PhotoScoring.score(): "stars", "score", "focus", "motion", "noise"...
@export var metric := "score"
@export var op := Op.AT_LEAST
@export var value := 0.0
@export var required := true
## What the player reads, e.g. "Keep the grain down (Noise 0.5+)". Generated if empty.
@export var label := ""


func evaluate(result: Dictionary) -> bool:
	if not result.has(metric):
		return false
	var actual := float(result[metric])
	return actual >= value if op == Op.AT_LEAST else actual <= value


func describe() -> String:
	if label != "":
		return label
	return "%s %s %s" % [metric.capitalize(), "≥" if op == Op.AT_LEAST else "≤", ("%.2f" % value).trim_suffix("0").trim_suffix(".0")]
