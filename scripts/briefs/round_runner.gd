class_name RoundRunner
extends RefCounted
## Plays a list of briefs in order: shoot until the brief is won or lost, then
## the next shot moves on (to the next brief after a win, a retry after a loss,
## and back to the start after the last one). Pure state, no scene access, so
## it can be tested headless. The scene listens to brief_started to set up the
## light and subject.

signal brief_started(brief: Brief)

## DONE: every brief was won; the summary is up.
enum State { PLAYING, WON, LOST, DONE }

var briefs: Array[Brief] = []
var index := 0
var state := State.PLAYING
var shots_left := 0
## Best stars this attempt among shots that pass the required requirements.
var best_stars := 0
## True once a shot reached the target and passed the optional requirements too.
var bonus_met := false
## Attempts at the current brief, 1 on the first try.
var attempt := 0
## Per brief, once finished: { title, best_stars, won, bonus, reward }.
var results: Array[Dictionary] = []


func _init(list: Array[Brief] = []) -> void:
	briefs = list


func brief() -> Brief:
	return briefs[index]


## Starts brief `i` (counts as another attempt if it's the current one).
func start(i: int) -> void:
	attempt = attempt + 1 if i == index and attempt > 0 else 1
	index = i
	state = State.PLAYING
	shots_left = brief().shot_limit
	best_stars = 0
	bonus_met = false
	brief_started.emit(brief())


## Back to the first brief with a clean slate.
func restart() -> void:
	results.clear()
	attempt = 0
	index = 0
	start(0)


## Counts a scored shot. Returns true if the shot counted toward the brief
## (it passed the required requirements).
func record(result: Dictionary) -> bool:
	if state != State.PLAYING:
		return false
	var b := brief()
	shots_left -= 1
	var counts := b.meets_required(result)
	if counts:
		best_stars = maxi(best_stars, result.stars)
		if result.stars >= b.target_stars and b.meets_optional(result):
			bonus_met = b.has_bonus()
	match b.win_mode:
		Brief.WinMode.TARGET_STARS:
			if best_stars >= b.target_stars:
				_finish(true)
			elif shots_left <= 0:
				_finish(false)
		Brief.WinMode.BEST_OF:
			if shots_left <= 0:
				_finish(best_stars >= b.target_stars)
	return counts


## The shot after a brief ends: next brief, retry, summary, or start over.
func advance() -> void:
	match state:
		State.WON:
			if index + 1 < briefs.size():
				start(index + 1)
			else:
				state = State.DONE
		State.LOST:
			start(index)
		State.DONE:
			restart()


## Total reward for every brief won so far.
func total_reward() -> int:
	var total := 0
	for result in results:
		total += result.reward
	return total


func _finish(won: bool) -> void:
	state = State.WON if won else State.LOST
	if not won:
		return
	var b := brief()
	var result := {
		"title": b.title,
		"best_stars": best_stars,
		"won": true,
		"bonus": bonus_met,
		"reward": b.reward + (b.bonus_reward if bonus_met else 0),
	}
	# Replace an earlier result for this brief (after a restart from the summary).
	results = results.filter(func(r: Dictionary) -> bool: return r.title != b.title)
	results.append(result)
