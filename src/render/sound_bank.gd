class_name SoundBank
extends Node
## Procedurally synthesised sound effects (no external audio assets). Sounds are
## generated once at startup as 16-bit mono PCM and played through a small pool of
## players. Presentation only: never read by the simulation.

const RATE := 22050
const POOL := 10
const MIN_GAP := {"hit": 0.12, "fire": 0.5, "click": 0.05, "build": 0.4, "horn": 1.5, "chime": 0.8, "dirt": 0.12, "spawn": 0.2, "rain": 0.6, "bubble": 0.4, "thunder": 0.25}

var volume := 0.8:
	set(v):
		volume = clampf(v, 0.0, 1.0)
		for p in _players:
			p.volume_db = linear_to_db(maxf(volume, 0.0001))
var muted := false
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _last: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _next := 0


func _ready() -> void:
	_rng.seed = 12345
	for k in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	volume = volume
	_streams["click"] = _make(0.05, _click)
	_streams["thunder"] = _make(1.3, _thunder)
	_streams["boom"] = _make(1.8, _boom)
	_streams["rumble"] = _make(2.2, _rumble)
	_streams["fire"] = _make(0.9, _fire)
	_streams["chime"] = _make(1.0, _chime)
	_streams["horn"] = _make(1.4, _horn)
	_streams["rain"] = _make(1.2, _rain)
	_streams["bubble"] = _make(0.6, _bubble)
	_streams["build"] = _make(0.18, _knock)
	_streams["hit"] = _make(0.08, _hit)
	_streams["spawn"] = _make(0.5, _spawn)
	_streams["dirt"] = _make(0.25, _dirt)


func play(id: String, pitch: float = 1.0, gain_db: float = 0.0) -> void:
	if muted or not _streams.has(id):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(id, -10.0)) < float(MIN_GAP.get(id, 0.03)):
		return
	_last[id] = now
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = _streams[id]
	p.pitch_scale = pitch * _rng.randf_range(0.95, 1.05)
	p.volume_db = linear_to_db(maxf(volume, 0.0001)) + gain_db
	p.play()


func _make(seconds: float, fn: Callable) -> AudioStreamWAV:
	var n := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(fn.get_method())
	var state := {"lp": 0.0, "lp2": 0.0, "rng": rng}
	for i in n:
		var t := float(i) / RATE
		var v := clampf(float(fn.call(t, seconds, state)), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


static func _env(t: float, attack: float, decay: float) -> float:
	return minf(1.0, t / maxf(attack, 0.0001)) * exp(-t / decay)


static func _noise(state: Dictionary) -> float:
	return (state["rng"] as RandomNumberGenerator).randf_range(-1.0, 1.0)


## One-pole low-pass on white noise; k in (0, 1], smaller = darker.
static func _lp(state: Dictionary, x: float, k: float, key: String = "lp") -> float:
	state[key] = float(state[key]) + (x - float(state[key])) * k
	return state[key]


func _click(t: float, _d: float, _s: Dictionary) -> float:
	return sin(TAU * 1200.0 * t) * _env(t, 0.002, 0.012) * 0.5


func _thunder(t: float, _d: float, s: Dictionary) -> float:
	var crack := _noise(s) * _env(t, 0.001, 0.06)
	var roll := _lp(s, _noise(s), 0.05) * _env(t, 0.05, 0.45) * (0.8 + 0.2 * sin(t * 23.0))
	return crack * 0.7 + roll * 3.4


func _boom(t: float, _d: float, s: Dictionary) -> float:
	var f := 110.0 * exp(-t * 2.0) + 35.0
	var body := sin(TAU * f * t) * _env(t, 0.004, 0.5)
	var debris := _lp(s, _noise(s), 0.12) * _env(t, 0.01, 0.35)
	return body * 0.62 + debris * 1.1


func _rumble(t: float, d: float, s: Dictionary) -> float:
	var shake := 0.6 + 0.4 * sin(t * 17.0) * sin(t * 5.3)
	var fade := minf(1.0, t / 0.2) * minf(1.0, (d - t) / 0.6)
	return _lp(s, _noise(s), 0.03) * 3.0 * shake * fade + sin(TAU * 42.0 * t) * 0.25 * fade


func _fire(t: float, d: float, s: Dictionary) -> float:
	var hiss := _lp(s, _noise(s), 0.25) * 0.25
	var rng: RandomNumberGenerator = s["rng"]
	var pop := 0.0
	if rng.randf() < 0.004:
		s["lp2"] = 1.0
	pop = float(s["lp2"]) * _noise(s)
	s["lp2"] = float(s["lp2"]) * 0.93
	var fade := minf(1.0, t / 0.1) * minf(1.0, (d - t) / 0.2)
	return (hiss + pop * 0.7) * fade


func _chime(t: float, _d: float, _s: Dictionary) -> float:
	var a := sin(TAU * 660.0 * t) * _env(t, 0.003, 0.45)
	var b := sin(TAU * 990.0 * t) * _env(maxf(0.0, t - 0.12), 0.003, 0.4) * (1.0 if t > 0.12 else 0.0)
	var c := sin(TAU * 1320.0 * t) * _env(t, 0.003, 0.2) * 0.3
	return (a + b + c) * 0.35


func _horn(t: float, d: float, _s: Dictionary) -> float:
	var vib := 1.0 + 0.012 * sin(TAU * 5.5 * t)
	var f := 196.0 * vib
	var tone := 0.0
	for h in [1, 2, 3, 4, 5]:
		tone += sin(TAU * f * h * t) / float(h * h) * (1.0 if h < 4 else 0.6)
	var env := minf(1.0, t / 0.15) * minf(1.0, (d - t) / 0.4)
	return tone * env * 0.45


func _rain(t: float, d: float, s: Dictionary) -> float:
	var hiss := _lp(s, _noise(s), 0.5) - _lp(s, _noise(s), 0.05, "lp2")
	var fade := minf(1.0, t / 0.2) * minf(1.0, (d - t) / 0.4)
	return hiss * 0.5 * fade


func _bubble(t: float, _d: float, _s: Dictionary) -> float:
	var out := 0.0
	for k in 3:
		var t0 := k * 0.15
		if t >= t0:
			var tt := t - t0
			out += sin(TAU * (300.0 + 600.0 * tt) * tt) * _env(tt, 0.005, 0.06)
	return out * 0.4


func _knock(t: float, _d: float, s: Dictionary) -> float:
	return (sin(TAU * 170.0 * t) * 0.7 + _noise(s) * 0.3) * _env(t, 0.001, 0.03)


func _hit(t: float, _d: float, s: Dictionary) -> float:
	return (_noise(s) * 0.5 + sin(TAU * 520.0 * t) * 0.3) * _env(t, 0.001, 0.015)


func _spawn(t: float, _d: float, _s: Dictionary) -> float:
	var f := 520.0 + 700.0 * t
	return sin(TAU * f * t) * _env(t, 0.01, 0.15) * 0.35


func _dirt(t: float, _d: float, s: Dictionary) -> float:
	return _lp(s, _noise(s), 0.2) * _env(t, 0.005, 0.07) * 1.2
