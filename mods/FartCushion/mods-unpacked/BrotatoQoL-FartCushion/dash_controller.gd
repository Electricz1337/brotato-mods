extends Node

# Attached to every wave scene (main.tscn) by mod_main.gd.
#
# Dash = a short, strong push in the movement direction. It uses the game's
# own knockback mechanic of the player (Unit.knockback_vector), so walls and
# map borders are respected and it fades out smoothly over ~0.15s.
#
# Cooldown display: a small bar below the potato that fills up while the dash
# recharges and disappears as soon as the dash is ready again.

# Key and joypad button are read directly: the game resets its InputMap
# (InputService -> InputMap.load_from_globals()), which would remove any
# custom input action added by a mod. The current bindings come from
# mod_main.gd ("settings": dash_scancode, dash_button), which follows the
# ModOptions dropdowns. Defaults: Shift and L3 (both unused by the game).
const DEFAULT_SCANCODE := KEY_SHIFT
const DEFAULT_BUTTON := JOY_L3
const BASE_COOLDOWN := 3.0
const MIN_COOLDOWN := 0.5
# knockback_vector length; resulting dash distance is roughly 15x this (~225px)
const DASH_STRENGTH := 15.0

# Cooldown bar (same width as the game's on-character HP bar)
const BAR_WIDTH := 64.0
const BAR_HEIGHT := 10.0
const BAR_OFFSET_Y := 52.0          # below the shadow (shadow sits at +38)
const BAR_BORDER := 3.0
const BAR_COLOR_BG := Color(0.07, 0.07, 0.07, 0.85)
const BAR_COLOR_BORDER := Color(0.06, 0.05, 0.05, 1.0)
const BAR_COLOR_FILL := Color(0.353, 0.745, 1.0, 1.0)   # light blue

const LOG_NAME := "BrotatoQoL-FartCushion:Dash"
const ITEM_ID := "item_brotatoqol_fart_cushion"

var item_id_hash := 0
var dash_sound = null
var settings = null          # mod_main.gd

var _cooldown_left := 0.0
var _cooldown_total := 0.0
var _sound_player: AudioStreamPlayer = null
var _bar: Node2D = null
var _bar_owner = null
var _dash_key_was_down := false
var _dash_button_was_down := false
var _dash_requested := false


func _ready() -> void:
	_sound_player = AudioStreamPlayer.new()
	_sound_player.bus = "Sound"
	_sound_player.volume_db = -6.0
	add_child(_sound_player)
	set_process_input(true)
	set_physics_process(true)
	ModLoaderLog.info("Dash controller attached to wave (pause_mode=%s)" % pause_mode, LOG_NAME)


func _get_scancode() -> int:
	if settings != null and is_instance_valid(settings):
		return settings.dash_scancode
	return DEFAULT_SCANCODE


func _get_button() -> int:
	if settings != null and is_instance_valid(settings):
		return settings.dash_button
	return DEFAULT_BUTTON


# Event based: catches the press even if polling misses it
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var scancode := _get_scancode()
		if scancode != 0 and event.pressed and not event.echo and event.scancode == scancode:
			_dash_requested = true
	elif event is InputEventJoypadButton:
		var button := _get_button()
		if button >= 0 and event.pressed and event.button_index == button:
			_dash_requested = true


func _is_button_down(button: int) -> bool:
	if button < 0:
		return false
	for device in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(device, button):
			return true
	return false


func _physics_process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = max(0.0, _cooldown_left - delta)
	_update_bar()

	# Polling based (edge detection), as a second way to detect the press
	var scancode := _get_scancode()
	var key_down := scancode != 0 and Input.is_key_pressed(scancode)
	if key_down and not _dash_key_was_down:
		_dash_requested = true
	_dash_key_was_down = key_down

	var button_down := _is_button_down(_get_button())
	if button_down and not _dash_button_was_down:
		_dash_requested = true
	_dash_button_was_down = button_down

	if not _dash_requested:
		return
	_dash_requested = false

	if _cooldown_left > 0.0:
		ModLoaderLog.info("Dash pressed -> still on cooldown (%.2fs left)" % _cooldown_left, LOG_NAME)
		return

	var player = _get_player_with_item()
	if player == null:
		return

	var direction = player.get("_current_movement")
	if not (direction is Vector2) or direction.length_squared() < 0.01:
		# Standing still: dash the way the character is facing
		var facing = player.get_direction() if player.has_method("get_direction") else 1
		direction = Vector2(1 if facing >= 0 else -1, 0)

	player.knockback_vector = direction.normalized() * DASH_STRENGTH
	_cooldown_total = _get_cooldown(0)
	_cooldown_left = _cooldown_total
	_update_bar()
	ModLoaderLog.info("DASH! direction=%s cooldown=%.2fs" % [direction.normalized(), _cooldown_total], LOG_NAME)

	if dash_sound != null:
		_sound_player.stream = dash_sound
		_sound_player.pitch_scale = rand_range(0.9, 1.15)
		_sound_player.play()


# Dash for player 1 (single player). Returns null (and logs why)
# if the player doesn't own the item or can't dash right now.
func _get_player_with_item():
	var run_data = get_node_or_null("/root/RunData")
	if run_data == null:
		ModLoaderLog.info("Dash pressed -> RunData not found", LOG_NAME)
		return null
	var player_index := 0

	# Compare by text id (robust), not only by hash
	var owns_item := false
	var item_ids := []
	for item in run_data.get_player_items_ref(player_index):
		item_ids.push_back(item.my_id)
		if item.my_id == ITEM_ID or (item_id_hash != 0 and item.my_id_hash == item_id_hash):
			owns_item = true
	if not owns_item:
		ModLoaderLog.info("Dash pressed -> item not owned. Player items: %s" % [item_ids], LOG_NAME)
		return null

	var players = get_parent().get("_players")
	if players == null or players.size() <= player_index:
		ModLoaderLog.info("Dash pressed -> no player found in wave (players=%s)" % [players], LOG_NAME)
		return null
	var player = players[player_index]
	if not is_instance_valid(player) or player.dead:
		ModLoaderLog.info("Dash pressed -> player invalid or dead", LOG_NAME)
		return null
	return player


func _get_cooldown(player_index: int) -> float:
	var utils = get_node_or_null("/root/Utils")
	var keys = get_node_or_null("/root/Keys")
	if utils == null or keys == null:
		return BASE_COOLDOWN
	var attack_speed = utils.get_stat(keys.stat_attack_speed_hash, player_index)
	var factor = max(0.25, 1.0 + attack_speed / 100.0)
	return max(MIN_COOLDOWN, BASE_COOLDOWN / factor)


# ---------------------------------------------------------------- cooldown bar

func _update_bar() -> void:
	var cooling := _cooldown_left > 0.0 and _cooldown_total > 0.0
	if not cooling:
		if _bar != null and is_instance_valid(_bar):
			_bar.visible = false
		return

	var players = get_parent().get("_players")
	if players == null or players.empty():
		return
	var player = players[0]
	if not is_instance_valid(player) or player.dead:
		if _bar != null and is_instance_valid(_bar):
			_bar.visible = false
		return

	# Create the bar (once) as a child of the player so it follows the potato
	if _bar == null or not is_instance_valid(_bar) or _bar_owner != player:
		if _bar != null and is_instance_valid(_bar):
			_bar.queue_free()
		_bar = Node2D.new()
		_bar.name = "BrotatoQoLDashCooldownBar"
		_bar.z_index = 10
		_bar.position = Vector2(0, BAR_OFFSET_Y)
		_bar.connect("draw", self, "_draw_bar")
		player.add_child(_bar)
		_bar_owner = player

	_bar.visible = true
	_bar.update()


func _draw_bar() -> void:
	if _bar == null or _cooldown_total <= 0.0:
		return
	var progress: float = clamp(1.0 - _cooldown_left / _cooldown_total, 0.0, 1.0)
	var outer := Rect2(-BAR_WIDTH / 2.0 - BAR_BORDER, -BAR_HEIGHT / 2.0 - BAR_BORDER,
		BAR_WIDTH + BAR_BORDER * 2.0, BAR_HEIGHT + BAR_BORDER * 2.0)
	var inner := Rect2(-BAR_WIDTH / 2.0, -BAR_HEIGHT / 2.0, BAR_WIDTH, BAR_HEIGHT)
	_bar.draw_rect(outer, BAR_COLOR_BORDER)
	_bar.draw_rect(inner, BAR_COLOR_BG)
	if progress > 0.0:
		_bar.draw_rect(Rect2(inner.position, Vector2(BAR_WIDTH * progress, BAR_HEIGHT)), BAR_COLOR_FILL)
