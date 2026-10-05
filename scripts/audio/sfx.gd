class_name Sfx
extends RefCounted
## Placeholder sounds synthesized in code until real audio assets exist.

const RATE := 22050
const SCALE := [261.63, 293.66, 329.63, 392.0, 440.0, 523.25]  # C major pentatonic-ish
## Reveal timing. PhotoHud reads these too, so the stars pop in on the chimes.
const FIRST_STAR_DELAY := 0.15
const STAR_GAP := 0.12

static var _cache := {}


## When star `index` (0-based) chimes, in seconds after the shutter.
static func star_time(index: int) -> float:
	return FIRST_STAR_DELAY + STAR_GAP * index


## When the whole reveal for a shot is finished.
static func reveal_time(stars: int) -> float:
	return star_time(maxi(stars, 1)) + 0.1


static func tone(freq: float, length := 0.2, volume := 0.4) -> AudioStreamWAV:
	var key := "tone:%s:%s:%s" % [freq, length, volume]
	if _cache.has(key):
		return _cache[key]
	var count := int(RATE * length)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var env := minf(1.0, i / 200.0) * pow(1.0 - float(i) / count, 2.0)
		var sample := sin(TAU * freq * i / RATE) * env * volume
		data.encode_s16(i * 2, int(sample * 32767.0))
	_cache[key] = _wav(data)
	return _cache[key]


static func click() -> AudioStreamWAV:
	if _cache.has("click"):
		return _cache["click"]
	var count := int(RATE * 0.06)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var env := pow(1.0 - float(i) / count, 3.0)
		data.encode_s16(i * 2, int(randf_range(-1.0, 1.0) * env * 0.5 * 32767.0))
	_cache["click"] = _wav(data)
	return _cache["click"]


## A short, bright detent click for turning a dial.
static func dial_tick() -> AudioStreamWAV:
	return tone(2400.0, 0.03, 0.25)


static func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	return wav


static func play(host: Node, stream: AudioStream, delay := 0.0) -> void:
	if delay > 0.0:
		await host.get_tree().create_timer(delay).timeout
		if not is_instance_valid(host) or not host.is_inside_tree():
			return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	host.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


## Shutter click, then one rising chime per star. 0 stars gets a low "bwomp".
static func play_result(host: Node, stars: int) -> void:
	play(host, click())
	if stars == 0:
		play(host, tone(150.0, 0.35, 0.5), 0.1)
		return
	for i in stars:
		play(host, tone(SCALE[i], 0.25), star_time(i))
	if stars == 5:
		play(host, tone(SCALE[5] * 2.0, 0.5, 0.35), star_time(5))
