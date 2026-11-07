extends Node

# Attached to every wave scene (main.tscn) by mod_main.gd.
#
# While the player owns the item and the wave is running, every COOLDOWN
# seconds a crosshair is placed at a random spot of the map. After
# STRIKE_DELAY seconds the game's own player explosion is spawned there
# (same as landmines / rocket turrets), so it only hurts enemies, uses the
# game's explosion visuals + sound and works with explosion bonuses.

const LOG_NAME := "BrotatoQoL-ArtilleryStrike:Strike"
const ITEM_ID := "item_brotatoqol_artillery_strike"

const BASE_COOLDOWN := 15.0
const MIN_COOLDOWN := 2.0
const STRIKE_DELAY := 3.0

const BASE_DAMAGE := 40
const ENGINEERING_SCALING := 2.5          # +250% Engineering
const BASE_EXPLOSION_SCALE := 1.0         # game explosion size (radius ~147px)
const RADIUS_PER_ELEMENTAL := 0.02        # +2% radius per Elemental Damage point
const MIN_RADIUS_FACTOR := 0.5
const EXPLOSION_SCENE_RADIUS := 147.34    # CircleShape2D radius in res://projectiles/explosion.tscn
const MAP_MARGIN := 80.0

var item_id_hash := 0
var whistle_sound = null
var crosshair_script = null

var _time_until_next := -1.0
var _explosion_scene = null
var _explosion_effect = null
var _logged_start := false


func _ready() -> void:
	_explosion_scene = load("res://projectiles/explosion.tscn")
	_explosion_effect = load("res://effects/weapons/exploding_effect.gd").new()
	_explosion_effect.explosion_scene = _explosion_scene
	_explosion_effect.chance = 1.0
	_explosion_effect.base_smoke_amount = 60
	_explosion_effect.sound_db_mod = -4


func _physics_process(delta: float) -> void:
	var player = _get_active_player()
	if player == null:
		return

	if _time_until_next < 0.0:
		# First strike one full cooldown after the wave started
		_time_until_next = _get_cooldown()
		if not _logged_start:
			_logged_start = true
			ModLoaderLog.info("Artillery active (cooldown %.1fs)" % _time_until_next, LOG_NAME)
		return

	_time_until_next -= delta
	if _time_until_next <= 0.0:
		_call_in_strike()
		_time_until_next = _get_cooldown()


# Player 1 (single player) if they own the item and the wave is still running
func _get_active_player():
	var run_data = get_node_or_null("/root/RunData")
	if run_data == null:
		return null
	var owns_item := false
	for item in run_data.get_player_items_ref(0):
		if item.my_id == ITEM_ID or (item_id_hash != 0 and item.my_id_hash == item_id_hash):
			owns_item = true
			break
	if not owns_item:
		return null
	var players = get_parent().get("_players")
	if players == null or players.empty():
		return null
	var player = players[0]
	if not is_instance_valid(player) or player.dead or player.cleaning_up:
		return null
	return player


# ---------------------------------------------------------------- strike

func _call_in_strike() -> void:
	var zone_service = get_node_or_null("/root/ZoneService")
	if zone_service == null or crosshair_script == null:
		return
	var rect: Rect2 = zone_service.get_current_zone_rect()
	var pos := Vector2(
		rand_range(rect.position.x + MAP_MARGIN, rect.end.x - MAP_MARGIN),
		rand_range(rect.position.y + MAP_MARGIN, rect.end.y - MAP_MARGIN)
	)

	var explosion_scale := _get_explosion_scale()
	var crosshair = crosshair_script.new()
	crosshair.position = pos
	crosshair.radius = EXPLOSION_SCENE_RADIUS * explosion_scale * _get_explosion_size_factor()
	crosshair.delay = STRIKE_DELAY
	crosshair.whistle_sound = whistle_sound
	crosshair.screenshaker = get_parent().get("_screenshaker")
	var _e = crosshair.connect("impact", self, "_on_impact", [explosion_scale])
	get_parent().add_child(crosshair)


func _on_impact(pos: Vector2, explosion_scale: float) -> void:
	var weapon_service = get_node_or_null("/root/WeaponService")
	if weapon_service == null or _get_active_player() == null:
		return

	var args = load("res://singletons/weapon_service_explode_args.gd").new()
	args.pos = pos
	args.damage = _get_damage()
	args.accuracy = 1.0
	args.crit_chance = 0.0
	args.crit_damage = 1.0
	args.burning_data = null
	args.from_player_index = 0
	args.damage_tracking_key_hash = item_id_hash
	var keys = get_node_or_null("/root/Keys")
	if keys != null:
		args.scaling_stats = [[keys.stat_engineering_hash, ENGINEERING_SCALING]]

	_ensure_tracking_key()
	_explosion_effect.scale = explosion_scale
	var _inst = weapon_service.explode(_explosion_effect, args)


# ---------------------------------------------------------------- values

func _get_stat(stat_name: String) -> float:
	var utils = get_node_or_null("/root/Utils")
	var keys = get_node_or_null("/root/Keys")
	if utils == null or keys == null:
		return 0.0
	return float(utils.get_stat(keys.get(stat_name), 0))


func _get_cooldown() -> float:
	var factor = max(0.25, 1.0 + _get_stat("stat_attack_speed_hash") / 100.0)
	return max(MIN_COOLDOWN, BASE_COOLDOWN / factor)


# 40 + 250% Engineering, x (1 + % Damage + % Explosion Damage)
# (same formula the game uses for explosions in WeaponService.get_explosion_damage)
func _get_damage() -> int:
	var raw = max(1.0, BASE_DAMAGE + _get_stat("stat_engineering_hash") * ENGINEERING_SCALING)
	var bonus = 1.0 + _get_stat("stat_percent_damage_hash") / 100.0 + _get_stat("explosion_damage_hash") / 100.0
	return int(max(1, round(raw * bonus)))


func _get_explosion_scale() -> float:
	var factor = max(MIN_RADIUS_FACTOR, 1.0 + _get_stat("stat_elemental_damage_hash") * RADIUS_PER_ELEMENTAL)
	return BASE_EXPLOSION_SCALE * factor


# The explosion scene itself applies % Explosion Size on top (set_area)
func _get_explosion_size_factor() -> float:
	return max(0.1, 1.0 + _get_stat("explosion_size_hash") / 100.0)


# Damage tracking for runs that were already running before the item existed
func _ensure_tracking_key() -> void:
	var run_data = get_node_or_null("/root/RunData")
	if run_data == null or item_id_hash == 0:
		return
	if run_data.tracked_item_effects.size() > 0 and not run_data.tracked_item_effects[0].has(item_id_hash):
		run_data.tracked_item_effects[0][item_id_hash] = 0
