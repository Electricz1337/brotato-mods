extends Node2D

# Crosshair marking where the artillery shell will land.
#
#   phase "aim"     (delay seconds): impact radius, a ring closing in on the
#                    center, pulsing crosshair; incoming whistle at the end
#   phase "explode" (EXPLODE_DURATION): own impact effect - fireball,
#                    shockwave ring, debris and smoke. The game's own explosion
#                    (damage + sound) is triggered via the "impact" signal; its
#                    visual is only a 0.05s flash, so this makes the hit visible.

signal impact(pos)

const COLOR_MAIN := Color(1.0, 0.25, 0.2, 0.95)
const COLOR_OUTLINE := Color(0.05, 0.03, 0.03, 0.9)
const COLOR_FILL := Color(1.0, 0.2, 0.15, 0.10)
const WHISTLE_LENGTH := 1.2

const EXPLODE_DURATION := 0.8
const COLOR_FLASH := Color(1.0, 0.97, 0.8)
const COLOR_FIRE_INNER := Color(1.0, 0.85, 0.35)
const COLOR_FIRE_OUTER := Color(1.0, 0.45, 0.12)
const COLOR_SMOKE := Color(0.18, 0.16, 0.15)
const COLOR_DEBRIS := Color(0.25, 0.2, 0.15)

var radius := 147.0
var delay := 3.0
var whistle_sound = null
var screenshaker = null

var _elapsed := 0.0
var _phase := "aim"
var _explode_time := 0.0
var _whistle_played := false
var _whistle_player: AudioStreamPlayer2D = null
var _debris := []        # [direction, speed, size]
var _smoke := []         # [offset, size, drift]


func _ready() -> void:
	z_index = 50
	if whistle_sound != null:
		_whistle_player = AudioStreamPlayer2D.new()
		_whistle_player.stream = whistle_sound
		_whistle_player.bus = "Sound"
		_whistle_player.volume_db = -4.0
		_whistle_player.max_distance = 4000.0
		add_child(_whistle_player)


func _process(delta: float) -> void:
	if _phase == "aim":
		_elapsed += delta
		if not _whistle_played and _whistle_player != null and _elapsed >= delay - WHISTLE_LENGTH:
			_whistle_played = true
			_whistle_player.play()
		if _elapsed >= delay:
			_start_explosion()
	elif _phase == "explode":
		_explode_time += delta
		if _explode_time >= EXPLODE_DURATION:
			set_process(false)
			queue_free()
			return
	update()


func _start_explosion() -> void:
	_phase = "explode"
	_explode_time = 0.0
	emit_signal("impact", global_position)

	randomize()
	for i in 14:
		var angle: float = rand_range(0.0, TAU)
		_debris.push_back([Vector2(cos(angle), sin(angle)), rand_range(0.7, 1.25), rand_range(5.0, 10.0)])
	for i in 9:
		var angle: float = rand_range(0.0, TAU)
		var dist: float = rand_range(0.15, 0.6) * radius
		_smoke.push_back([Vector2(cos(angle), sin(angle)) * dist, rand_range(0.28, 0.45) * radius, Vector2(cos(angle), sin(angle))])

	if screenshaker != null and is_instance_valid(screenshaker) and screenshaker.has_method("shake"):
		screenshaker.shake(10.0, 0.3)


func _draw() -> void:
	if _phase == "aim":
		_draw_aim()
	else:
		_draw_explosion()


# ---------------------------------------------------------------- aim

func _draw_aim() -> void:
	var t: float = clamp(_elapsed / delay, 0.0, 1.0)
	var pulse := 0.75 + 0.25 * sin(_elapsed * (6.0 + 14.0 * t))
	var main_color := COLOR_MAIN
	main_color.a *= pulse

	draw_circle(Vector2.ZERO, radius, COLOR_FILL)
	_ring(radius, 7.0, COLOR_OUTLINE)
	_ring(radius, 4.0, main_color)

	var inner := radius * (1.0 - t)
	if inner > 6.0:
		_ring(inner, 5.0, COLOR_OUTLINE)
		_ring(inner, 3.0, Color(1, 1, 1, 0.8))

	var gap := radius * 0.18
	var length := radius * 0.95
	for dir in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		draw_line(dir * gap, dir * length, COLOR_OUTLINE, 9.0, true)
		draw_line(dir * gap, dir * length, main_color, 5.0, true)
	draw_circle(Vector2.ZERO, 7.0, COLOR_OUTLINE)
	draw_circle(Vector2.ZERO, 4.0, main_color)


# ---------------------------------------------------------------- explosion

func _draw_explosion() -> void:
	var p: float = clamp(_explode_time / EXPLODE_DURATION, 0.0, 1.0)

	# smoke clouds: grow, drift outwards, fade
	for s in _smoke:
		var a: float = 0.55 * (1.0 - p)
		if a <= 0.01:
			continue
		var c := COLOR_SMOKE
		c.a = a
		var pos: Vector2 = s[0] + s[2] * radius * 0.25 * p
		draw_circle(pos, s[1] * (0.6 + 0.6 * p), c)

	# debris chunks flying outwards
	for d in _debris:
		var dist: float = radius * d[1] * _ease_out(p)
		var a2: float = 1.0 - p
		if a2 <= 0.02:
			continue
		var c2 := COLOR_DEBRIS
		c2.a = a2
		var pos2: Vector2 = d[0] * dist
		draw_circle(pos2, d[2] * (1.0 - p * 0.5) + 2.0, Color(0, 0, 0, a2))
		draw_circle(pos2, d[2] * (1.0 - p * 0.5), c2)

	# shockwave ring
	var ring_r := radius * (0.3 + 0.9 * _ease_out(p))
	var ring_a := 1.0 - p
	if ring_a > 0.02:
		_ring(ring_r, 10.0 * (1.0 - p) + 2.0, Color(1.0, 0.9, 0.7, ring_a * 0.9))

	# fireball: quick bloom then shrink
	var fire_p: float = clamp(p / 0.55, 0.0, 1.0)
	if fire_p < 1.0:
		var bloom: float = _ease_out(min(1.0, fire_p * 2.5))
		var shrink: float = 1.0 - max(0.0, fire_p - 0.4) / 0.6
		var fire_r: float = radius * 0.85 * bloom * shrink
		if fire_r > 2.0:
			var outer := COLOR_FIRE_OUTER
			outer.a = 0.85 * shrink
			draw_circle(Vector2.ZERO, fire_r, outer)
			var inner := COLOR_FIRE_INNER
			inner.a = 0.9 * shrink
			draw_circle(Vector2.ZERO, fire_r * 0.65, inner)

	# white flash in the first frames
	if p < 0.12:
		var flash := COLOR_FLASH
		flash.a = 1.0 - p / 0.12
		draw_circle(Vector2.ZERO, radius * (0.6 + p * 3.0), flash)

func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - clamp(x, 0.0, 1.0), 3.0)


func _ring(r: float, width: float, color: Color) -> void:
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, color, width, true)
