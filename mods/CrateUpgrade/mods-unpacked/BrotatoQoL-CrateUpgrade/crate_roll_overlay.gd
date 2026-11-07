extends CanvasLayer

# Suspense animation for a crate upgrade, shown on top of the crate screen.
#
#   roll   : the item shakes, a needle races over the chance bar
#            (success zone in the target rarity color, the rest red),
#            slows down with ticking sounds and stops on the pre-rolled result
#   result : success -> flash, star burst, the new item pops in
#            failure -> red flash, the item breaks apart into shards
#   fade   : overlay fades out, then "finished" is emitted
#
# Runs while the game is paused. The result is decided before the animation
# starts (by the crate screen), the animation only shows it.

signal finished

const ROLL_DURATION := 3.2
const RESULT_DURATION := 1.4
const FADE_DURATION := 0.3
const TRAVERSALS := 3            # full back-and-forth runs before stopping

const BAR_WIDTH := 760.0
const BAR_HEIGHT := 46.0
const ICON_SIZE := 150.0

const COLOR_OUTLINE := Color(0.06, 0.05, 0.05, 1.0)
const COLOR_FAIL_ZONE := Color(0.55, 0.12, 0.12, 1.0)
const COLOR_FAIL := Color("ff5d5d")
const COLOR_PANEL := Color(0.08, 0.08, 0.08, 0.96)

var chance := 0.5
var success := false
var old_icon: Texture = null
var new_icon: Texture = null
var old_color := Color.white
var new_color := Color.white
var title_text := ""
var success_text := ""
var fail_text := ""
var zone_success_text := ""
var zone_fail_text := ""

var _canvas: Control = null
var _font: Font = null
var _font_big: Font = null
var _phase := "roll"
var _time := 0.0
var _target := 0.0                # final needle position 0..1
var _needle := 0.0
var _last_tick := -1
var _particles := []              # [pos, vel, size, color, rot, spin]
var _shake := Vector2.ZERO
var _snd_tick = null
var _snd_success = null
var _snd_fail = null
var _snd_start = null


func _ready() -> void:
	layer = 120
	pause_mode = Node.PAUSE_MODE_PROCESS
	randomize()

	_canvas = Control.new()
	_canvas.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	var _e = _canvas.connect("draw", self, "_draw_all")
	add_child(_canvas)

	_font = load("res://resources/fonts/actual/base/font_32_outline.tres")
	_font_big = load("res://resources/fonts/actual/base/font_60_outline.tres")
	if _font == null:
		_font = _canvas.get_font("font", "Label")
	if _font_big == null:
		_font_big = _font

	_snd_tick = load("res://ui/sounds/clock_tick_01.wav")
	_snd_success = load("res://resources/sounds/level_up.wav")
	_snd_fail = load("res://ui/menus/ban_item.wav")
	_snd_start = load("res://ui/sounds/diceroll.wav")

	# Final needle position: inside the success zone [0, chance] or the fail
	# zone [chance, 1]. Sometimes it stops right next to the border.
	var margin := 0.012
	if success:
		if randf() < 0.35:
			_target = chance - rand_range(margin, min(0.05, chance * 0.3))
		else:
			_target = rand_range(margin, chance - margin)
	else:
		if randf() < 0.35:
			_target = chance + rand_range(margin, 0.05)
		else:
			_target = rand_range(chance + margin, 1.0 - margin)
	_target = clamp(_target, 0.005, 0.995)

	_play(_snd_start, -4.0, 1.0)


func _process(delta: float) -> void:
	_time += delta
	match _phase:
		"roll":
			_process_roll()
		"result":
			_process_result(delta)
		"fade":
			var a: float = clamp(1.0 - _time / FADE_DURATION, 0.0, 1.0)
			_canvas.modulate.a = a
			if _time >= FADE_DURATION:
				set_process(false)
				emit_signal("finished")
				queue_free()
				return
	_canvas.update()


# ---------------------------------------------------------------- roll

func _process_roll() -> void:
	var t: float = clamp(_time / ROLL_DURATION, 0.0, 1.0)
	# fast start, long slow end
	var eased: float = 1.0 - pow(1.0 - t, 3.2)
	var distance: float = (TRAVERSALS * 2.0 + _target) * eased
	_needle = _pingpong(distance)

	# tick every 1/8 bar of travel -> ticks slow down with the needle
	var tick: int = int(distance * 8.0)
	if tick != _last_tick:
		_last_tick = tick
		_play(_snd_tick, -6.0, 0.9 + t * 0.5)

	# shaking grows towards the end
	var strength: float = 1.0 + 7.0 * t
	_shake = Vector2(rand_range(-strength, strength), rand_range(-strength, strength))

	if t >= 1.0:
		_needle = _target
		_start_result()


func _pingpong(x: float) -> float:
	var m := fmod(x, 2.0)
	return m if m <= 1.0 else 2.0 - m


func _start_result() -> void:
	_phase = "result"
	_time = 0.0
	_shake = Vector2.ZERO
	var center := _icon_center()
	if success:
		_play(_snd_success, 0.0, 1.0)
		for i in 46:
			var angle: float = rand_range(0.0, TAU)
			var speed: float = rand_range(380.0, 900.0)
			var color: Color = new_color if randf() < 0.7 else Color(1, 0.95, 0.6)
			_particles.push_back([center, Vector2(cos(angle), sin(angle)) * speed, rand_range(8.0, 18.0), color, rand_range(0.0, TAU), rand_range(-8.0, 8.0)])
	else:
		_play(_snd_fail, 0.0, 0.9)
		for i in 26:
			var angle: float = rand_range(0.0, TAU)
			var speed: float = rand_range(150.0, 520.0)
			var color: Color = old_color.darkened(rand_range(0.0, 0.4))
			_particles.push_back([center + Vector2(rand_range(-50, 50), rand_range(-50, 50)), Vector2(cos(angle), sin(angle) - 0.4) * speed, rand_range(10.0, 22.0), color, rand_range(0.0, TAU), rand_range(-10.0, 10.0)])


func _process_result(delta: float) -> void:
	for p in _particles:
		p[0] += p[1] * delta
		p[1] *= 0.92 if success else 0.97
		if not success:
			p[1].y += 900.0 * delta      # shards fall down
		p[4] += p[5] * delta
	if _time < 0.25:
		var s: float = 14.0 * (1.0 - _time / 0.25)
		_shake = Vector2(rand_range(-s, s), rand_range(-s, s))
	else:
		_shake = Vector2.ZERO
	if _time >= RESULT_DURATION:
		_phase = "fade"
		_time = 0.0


# ---------------------------------------------------------------- drawing

func _icon_center() -> Vector2:
	var size: Vector2 = _canvas.rect_size
	return Vector2(size.x / 2.0, size.y / 2.0 - 90.0)


func _draw_all() -> void:
	var size: Vector2 = _canvas.rect_size
	var center := _icon_center()
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.65))

	# panel
	var panel := Rect2(center.x - BAR_WIDTH / 2.0 - 60.0, center.y - 190.0, BAR_WIDTH + 120.0, 520.0)
	_canvas.draw_rect(panel.grow(4.0), new_color if _phase != "roll" and success else (COLOR_FAIL if _phase != "roll" else Color(0.4, 0.4, 0.4)))
	_canvas.draw_rect(panel, COLOR_PANEL)

	_draw_text_centered(_font, title_text, Vector2(center.x, panel.position.y + 48.0), Color.white)

	_draw_icon(center + _shake)
	_draw_bar(Vector2(center.x - BAR_WIDTH / 2.0, center.y + 125.0))
	_draw_particles()

	if _phase != "roll":
		var p: float = clamp(_time / 0.3, 0.0, 1.0)
		var scale: float = 1.0 + 0.4 * (1.0 - _ease_out(p))
		var color: Color = new_color if success else COLOR_FAIL
		var text: String = success_text if success else fail_text
		var pos := Vector2(center.x, panel.end.y - 40.0)
		_canvas.draw_set_transform(pos, 0.0, Vector2(scale, scale))
		_draw_text_centered(_font_big, text, Vector2.ZERO, color)
		_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# flash
		var flash_a: float = 0.55 * (1.0 - clamp(_time / 0.35, 0.0, 1.0))
		if flash_a > 0.0:
			var flash_color: Color = Color(1, 1, 1, flash_a) if success else Color(1, 0.15, 0.15, flash_a)
			_canvas.draw_rect(Rect2(Vector2.ZERO, size), flash_color)


func _draw_icon(center: Vector2) -> void:
	var half := ICON_SIZE / 2.0
	var rect := Rect2(center - Vector2(half, half), Vector2(ICON_SIZE, ICON_SIZE))

	if _phase == "roll":
		# pulsing glow in the target color, stronger near the end
		var t: float = clamp(_time / ROLL_DURATION, 0.0, 1.0)
		var glow := new_color
		glow.a = 0.15 + 0.25 * t * (0.5 + 0.5 * sin(_time * 18.0))
		_canvas.draw_rect(rect.grow(18.0 + 10.0 * t), glow)
		_frame(rect, old_color)
		if old_icon != null:
			_canvas.draw_texture_rect(old_icon, rect.grow(-10.0), false)
		return

	if success:
		var p: float = clamp(_time / 0.35, 0.0, 1.0)
		var scale: float = 0.6 + 0.4 * _ease_out_back(p)
		var r := Rect2(center - Vector2(half, half) * scale, Vector2(ICON_SIZE, ICON_SIZE) * scale)
		# rotating rays behind the new item
		for i in 12:
			var a: float = _time * 1.5 + i * TAU / 12.0
			var ray := new_color
			ray.a = 0.35 * (1.0 - clamp(_time / RESULT_DURATION, 0.0, 1.0)) + 0.1
			var pts := PoolVector2Array([center,
				center + Vector2(cos(a - 0.09), sin(a - 0.09)) * 260.0,
				center + Vector2(cos(a + 0.09), sin(a + 0.09)) * 260.0])
			_canvas.draw_colored_polygon(pts, ray)
		_frame(r, new_color)
		if new_icon != null:
			_canvas.draw_texture_rect(new_icon, r.grow(-10.0 * scale), false)
	else:
		# two halves drift apart and fade
		var p2: float = clamp(_time / 0.8, 0.0, 1.0)
		var a2: float = 1.0 - p2
		if a2 <= 0.0:
			return
		var offset: float = 60.0 * _ease_out(p2)
		var mod := Color(1, 1, 1, a2)
		for side in [-1, 1]:
			var shift: Vector2 = Vector2(side * offset, offset * 0.6)
			var src: Rect2 = Rect2(0, 0, 0.5, 1.0) if side < 0 else Rect2(0.5, 0, 0.5, 1.0)
			var dst: Rect2 = Rect2(rect.position + shift + Vector2(0 if side < 0 else half, 0), Vector2(half, ICON_SIZE))
			_canvas.draw_rect(dst, Color(old_color.r, old_color.g, old_color.b, a2))
			_canvas.draw_rect(dst.grow(-4.0), Color(0.12, 0.12, 0.12, a2))
			if old_icon != null:
				var tex_size: Vector2 = old_icon.get_size()
				var src_px: Rect2 = Rect2(src.position * tex_size, src.size * tex_size)
				_canvas.draw_texture_rect_region(old_icon, dst.grow(-6.0), src_px, mod)
		# crack line
		if p2 < 0.3:
			var c := Color(1, 1, 1, 1.0 - p2 / 0.3)
			_canvas.draw_line(center + Vector2(0, -half - 10), center + Vector2(-12, -20), c, 5.0)
			_canvas.draw_line(center + Vector2(-12, -20), center + Vector2(10, 25), c, 5.0)
			_canvas.draw_line(center + Vector2(10, 25), center + Vector2(0, half + 10), c, 5.0)


func _frame(rect: Rect2, color: Color) -> void:
	_canvas.draw_rect(rect.grow(6.0), COLOR_OUTLINE)
	_canvas.draw_rect(rect, color)
	_canvas.draw_rect(rect.grow(-6.0), Color(0.12, 0.12, 0.12, 1.0))


func _draw_bar(pos: Vector2) -> void:
	var bar := Rect2(pos, Vector2(BAR_WIDTH, BAR_HEIGHT))
	var split: float = BAR_WIDTH * chance
	_canvas.draw_rect(bar.grow(5.0), COLOR_OUTLINE)
	_canvas.draw_rect(Rect2(pos, Vector2(split, BAR_HEIGHT)), new_color)
	_canvas.draw_rect(Rect2(pos + Vector2(split, 0), Vector2(BAR_WIDTH - split, BAR_HEIGHT)), COLOR_FAIL_ZONE)
	_canvas.draw_line(pos + Vector2(split, -5), pos + Vector2(split, BAR_HEIGHT + 5), COLOR_OUTLINE, 5.0)

	# zone labels below the bar
	var label_y := pos.y + BAR_HEIGHT + 34.0
	_draw_text_centered(_font, zone_success_text, Vector2(pos.x + max(split / 2.0, 70.0), label_y), new_color)
	_draw_text_centered(_font, zone_fail_text, Vector2(pos.x + split + (BAR_WIDTH - split) / 2.0, label_y), COLOR_FAIL)

	# needle
	var x: float = pos.x + BAR_WIDTH * _needle
	var needle_color := Color.white
	if _phase != "roll":
		needle_color = new_color if success else COLOR_FAIL
	_canvas.draw_line(Vector2(x, pos.y - 16), Vector2(x, pos.y + BAR_HEIGHT + 8), COLOR_OUTLINE, 10.0)
	_canvas.draw_line(Vector2(x, pos.y - 14), Vector2(x, pos.y + BAR_HEIGHT + 6), needle_color, 5.0)
	var tri := PoolVector2Array([Vector2(x - 16, pos.y - 34), Vector2(x + 16, pos.y - 34), Vector2(x, pos.y - 10)])
	_canvas.draw_colored_polygon(PoolVector2Array([Vector2(x - 21, pos.y - 37), Vector2(x + 21, pos.y - 37), Vector2(x, pos.y - 5)]), COLOR_OUTLINE)
	_canvas.draw_colored_polygon(tri, needle_color)


func _draw_particles() -> void:
	if _particles.empty():
		return
	var life: float = clamp(1.0 - _time / RESULT_DURATION, 0.0, 1.0)
	for p in _particles:
		var c: Color = p[3]
		c.a = life
		var s: float = p[2]
		if success:
			_draw_star(p[0], s, p[4], c)
		else:
			var pts := PoolVector2Array()
			for k in 3:
				var a: float = p[4] + k * TAU / 3.0 + (0.4 if k == 1 else 0.0)
				pts.push_back(p[0] + Vector2(cos(a), sin(a)) * s)
			_canvas.draw_colored_polygon(pts, c)


func _draw_star(pos: Vector2, size: float, rot: float, color: Color) -> void:
	var pts := PoolVector2Array()
	for k in 8:
		var r: float = size if k % 2 == 0 else size * 0.45
		var a: float = rot + k * TAU / 8.0
		pts.push_back(pos + Vector2(cos(a), sin(a)) * r)
	_canvas.draw_colored_polygon(pts, color)


func _draw_text_centered(font: Font, text: String, center: Vector2, color: Color) -> void:
	if font == null or text == "":
		return
	var size := font.get_string_size(text)
	_canvas.draw_string(font, center + Vector2(-size.x / 2.0, font.get_ascent() - size.y / 2.0), text, color)


# ---------------------------------------------------------------- helpers

func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - clamp(x, 0.0, 1.0), 3.0)


func _ease_out_back(x: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	var v := x - 1.0
	return 1.0 + c3 * v * v * v + c1 * v * v


func _play(stream, volume_db: float, pitch: float) -> void:
	if stream == null:
		return
	# one-shot player per sound, so ticks don't cut each other off
	var p := AudioStreamPlayer.new()
	p.bus = "Sound"
	p.pause_mode = Node.PAUSE_MODE_PROCESS
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	var _e = p.connect("finished", p, "queue_free")
