extends CanvasLayer

# Coin flip popup shown at the end of a wave by mod_main.gd.
# Runs while the game is paused (pause_mode = PROCESS).
#
#   choose   -> buttons Heads / Tails / Skip
#   flipping -> coin spins for FLIP_DURATION seconds
#   result   -> win (+amount) or lose (-amount) is applied, "Continue" button

signal finished

const FLIP_DURATION := 1.6
const SPINS_PER_SECOND := 3.5
const COIN_RADIUS := 80.0

const COLOR_GREEN := Color("76ff76")
const COLOR_RED := Color("ff5d5d")
const COLOR_OUTLINE := Color(0.06, 0.05, 0.05, 1.0)
const COLOR_COIN := Color("5cc858")
const COLOR_COIN_EDGE := Color("349637")
const COLOR_COIN_LIGHT := Color("9cf58f")
const COLOR_PANEL := Color(0.08, 0.08, 0.08, 0.96)

var amount := 0
var player_index := 0

var _state := "choose"
var _choice := ""          # "heads" / "tails"
var _result := ""          # "heads" / "tails"
var _flip_time := 0.0

var _coin: Control = null
var _info: Label = null
var _buttons_row: HBoxContainer = null
var _heads_button: Button = null
var _continue_button: Button = null


func setup(p_amount: int, p_player_index: int) -> void:
	amount = p_amount
	player_index = p_player_index


func _ready() -> void:
	layer = 100
	pause_mode = PAUSE_MODE_PROCESS

	var root := Control.new()
	root.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var theme = load("res://resources/themes/base_theme.tres")
	if theme != null:
		root.theme = theme
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = COLOR_GREEN
	style.set_border_width_all(4)
	style.set_corner_radius_all(12)
	style.content_margin_left = 48
	style.content_margin_right = 48
	style.content_margin_top = 32
	style.content_margin_bottom = 32
	panel.add_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_constant_override("separation", 24)
	vbox.alignment = BoxContainer.ALIGN_CENTER
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "MOD_COINFLIP_TITLE"
	title.align = Label.ALIGN_CENTER
	title.add_color_override("font_color", COLOR_GREEN)
	vbox.add_child(title)

	_info = Label.new()
	_info.text = tr("MOD_COINFLIP_QUESTION").format({"amount": amount})
	_info.align = Label.ALIGN_CENTER
	_info.rect_min_size = Vector2(760, 0)
	_info.autowrap = true
	vbox.add_child(_info)

	_coin = Control.new()
	_coin.rect_min_size = Vector2(COIN_RADIUS * 2.0 + 20.0, COIN_RADIUS * 2.0 + 20.0)
	_coin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var _e = _coin.connect("draw", self, "_draw_coin")
	vbox.add_child(_coin)

	_buttons_row = HBoxContainer.new()
	_buttons_row.alignment = BoxContainer.ALIGN_CENTER
	_buttons_row.add_constant_override("separation", 24)
	vbox.add_child(_buttons_row)

	_heads_button = _make_button("MOD_COINFLIP_HEADS", "_on_choice", ["heads"])
	_buttons_row.add_child(_heads_button)
	_buttons_row.add_child(_make_button("MOD_COINFLIP_TAILS", "_on_choice", ["tails"]))
	_buttons_row.add_child(_make_button("MOD_COINFLIP_SKIP", "_on_skip", []))

	_continue_button = _make_button("MOD_COINFLIP_CONTINUE", "_on_continue", [])
	_continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_continue_button.visible = false
	vbox.add_child(_continue_button)

	_heads_button.call_deferred("grab_focus")


func _make_button(text_key: String, method: String, binds: Array) -> Button:
	var button := Button.new()
	button.text = text_key
	button.rect_min_size = Vector2(230, 70)
	button.focus_mode = Control.FOCUS_ALL
	var _e = button.connect("pressed", self, method, binds)
	return button


# ---------------------------------------------------------------- flow

func _on_choice(choice: String) -> void:
	if _state != "choose":
		return
	_choice = choice
	_state = "flipping"
	_flip_time = 0.0
	_buttons_row.visible = false
	_info.text = "MOD_COINFLIP_FLIPPING"
	_info.add_color_override("font_color", Color.white)


func _on_skip() -> void:
	if _state != "choose":
		return
	_state = "done"
	emit_signal("finished")


func _on_continue() -> void:
	if _state != "result":
		return
	_state = "done"
	emit_signal("finished")


func _process(delta: float) -> void:
	if _state != "flipping":
		return
	_flip_time += delta
	_coin.update()
	if _flip_time >= FLIP_DURATION:
		_resolve()


func _resolve() -> void:
	randomize()
	_result = "heads" if randf() < 0.5 else "tails"
	var won := _result == _choice
	var side_name := tr("MOD_COINFLIP_HEADS" if _result == "heads" else "MOD_COINFLIP_TAILS")

	var run_data = get_node_or_null("/root/RunData")
	if run_data != null:
		if won:
			run_data.add_gold(amount, player_index)
		else:
			run_data.remove_gold(amount, player_index)

	if won:
		_info.text = tr("MOD_COINFLIP_WIN").format({"side": side_name, "amount": amount})
		_info.add_color_override("font_color", COLOR_GREEN)
	else:
		_info.text = tr("MOD_COINFLIP_LOSE").format({"side": side_name, "amount": amount})
		_info.add_color_override("font_color", COLOR_RED)

	ModLoaderLog.info("Coin flip: chose %s, got %s -> %s%s materials" % [_choice, _result, "+" if won else "-", amount], "BrotatoQoL-Coinflip:Popup")

	_state = "result"
	_coin.update()
	_continue_button.visible = true
	_continue_button.call_deferred("grab_focus")


# ---------------------------------------------------------------- coin drawing

func _draw_coin() -> void:
	var center: Vector2 = _coin.rect_size / 2.0
	var squash := 1.0
	var show_heads := true

	if _state == "flipping":
		# spins fast at first and slows down towards the end
		var t: float = clamp(_flip_time / FLIP_DURATION, 0.0, 1.0)
		var angle: float = (1.0 - pow(1.0 - t, 2.0)) * FLIP_DURATION * SPINS_PER_SECOND * TAU
		squash = abs(cos(angle))
		show_heads = cos(angle) >= 0.0
	elif _state == "result" or _state == "done":
		show_heads = _result == "heads"

	squash = max(squash, 0.06)
	# small hop while flipping
	if _state == "flipping":
		var t2: float = clamp(_flip_time / FLIP_DURATION, 0.0, 1.0)
		center.y -= sin(t2 * PI) * 10.0

	_draw_ellipse(center + Vector2(0, 6), COIN_RADIUS + 6.0, squash, COLOR_OUTLINE)    # outline + thickness
	_draw_ellipse(center + Vector2(0, 5), COIN_RADIUS, squash, COLOR_COIN_EDGE)         # edge
	_draw_ellipse(center, COIN_RADIUS + 6.0, squash, COLOR_OUTLINE)
	_draw_ellipse(center, COIN_RADIUS, squash, COLOR_COIN)
	_draw_ellipse(center + Vector2(-6 * squash, -8), COIN_RADIUS * 0.72, squash, COLOR_COIN_LIGHT)
	_draw_ellipse(center, COIN_RADIUS * 0.68, squash, COLOR_COIN)

	# Face: letter (K/Z or H/T)
	if squash > 0.35:
		var letter := tr("MOD_COINFLIP_HEADS_SHORT" if show_heads else "MOD_COINFLIP_TAILS_SHORT")
		var font = _coin.get_font("font", "Label")
		if font != null:
			var size: Vector2 = font.get_string_size(letter)
			var pos := center + Vector2(-size.x * squash / 2.0, size.y / 4.0)
			_coin.draw_set_transform(pos, 0.0, Vector2(squash, 1.0))
			_coin.draw_string(font, Vector2.ZERO, letter, COLOR_OUTLINE)
			_coin.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_ellipse(center: Vector2, radius: float, squash_x: float, color: Color) -> void:
	var points := PoolVector2Array()
	var steps := 48
	for i in steps:
		var a := float(i) / steps * TAU
		points.push_back(center + Vector2(cos(a) * radius * squash_x, sin(a) * radius))
	_coin.draw_colored_polygon(points, color)
