extends Node

# GameSpeed
#
# Runs the waves faster or slower: 0.5x - 10x (ModOptions slider).
#
# How: Engine.time_scale - the same mechanism the game's own (disabled) debug
# keys use. Everything inside a wave scales with it: players, enemies,
# projectiles, animations and the wave timer.
# The speed is only active while a wave is running. Menus, pause menu, the
# level-up / crate screens after a wave and the shop always run at 1x.
#
# For high speeds the physics tick rate is raised (up to 4x, i.e. 240/s) so
# fast projectiles and enemies don't skip over each other as much.

const MOD_ID := "BrotatoQoL-GameSpeed"
const LOG_NAME := "BrotatoQoL-GameSpeed:Main"
const MAIN_SCENE_PATH := "res://main.tscn"
const MOD_OPTIONS_PATH := "/root/ModLoader/Oudstand-ModOptions/ModOptions"
const MOD_OPTIONS_RETRIES := 10
const OPTION_SPEED := "game_speed"
const DEFAULT_SPEED := 1.0
const MIN_SPEED := 0.5
const MAX_SPEED := 10.0
const MAX_PHYSICS_FACTOR := 4.0

var _speed := DEFAULT_SPEED
var _mod_options = null
var _mod_options_tries := 0
var _main: Node = null
var _base_physics_fps := 60
var _applied := 1.0


func _init() -> void:
	_add_translations()
	ModLoaderLog.info("Loaded", LOG_NAME)


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	_base_physics_fps = Engine.iterations_per_second
	var _e = get_tree().connect("node_added", self, "_on_node_added")
	call_deferred("_register_mod_options")


func _on_node_added(node: Node) -> void:
	if node.filename == MAIN_SCENE_PATH:
		_main = node


func _process(_delta: float) -> void:
	var target := 1.0
	if _wave_running():
		target = clamp(_speed, MIN_SPEED, MAX_SPEED)
	if is_equal_approx(target, _applied) and is_equal_approx(Engine.time_scale, target):
		return
	_applied = target
	Engine.time_scale = target
	var physics_factor: float = clamp(target, 1.0, MAX_PHYSICS_FACTOR)
	Engine.iterations_per_second = int(round(_base_physics_fps * physics_factor))


func _wave_running() -> bool:
	if _main == null or not is_instance_valid(_main) or not _main.is_inside_tree():
		_main = null
		return false
	if get_tree().paused:
		return false
	# after the wave timer ran out: level ups, crates, "wave cleared"
	var ended = _main.get("_end_wave_timer_timedout")
	if ended != null and ended:
		return false
	return true


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	Engine.iterations_per_second = _base_physics_fps


# ---------------------------------------------------------------- ModOptions

func _register_mod_options() -> void:
	_mod_options = get_node_or_null(MOD_OPTIONS_PATH)
	if _mod_options == null:
		_mod_options_tries += 1
		if _mod_options_tries < MOD_OPTIONS_RETRIES:
			var _t = get_tree().create_timer(0.5).connect("timeout", self, "_register_mod_options")
		else:
			ModLoaderLog.info("ModOptions not installed - normal speed", LOG_NAME)
		return
	if not _mod_options.get_registered_mods().has(MOD_ID):
		_mod_options.register_mod_options(MOD_ID, {
			"tab_title": "Game Speed",
			"options": [
				{
					"type": "slider",
					"id": OPTION_SPEED,
					"label": "BROTATOQOL_GAMESPEED_OPTION_SPEED",
					"default": DEFAULT_SPEED,
					"min": MIN_SPEED,
					"max": MAX_SPEED,
					"step": 0.05
				}
			],
			"info_text": "BROTATOQOL_GAMESPEED_OPTION_INFO"
		})
	var value = _mod_options.get_value(MOD_ID, OPTION_SPEED)
	if value != null:
		_speed = float(value)
	if not _mod_options.is_connected("config_changed", self, "_on_config_changed"):
		_mod_options.connect("config_changed", self, "_on_config_changed")
	ModLoaderLog.info("Registered with ModOptions (speed=%d%%)" % int(round(_speed * 100)), LOG_NAME)


func _on_config_changed(mod_id: String, option_id: String, new_value) -> void:
	if mod_id == MOD_ID and option_id == OPTION_SPEED:
		_speed = float(new_value)


# ---------------------------------------------------------------- texts

func _add_translations() -> void:
	var de := {
		"BROTATOQOL_GAMESPEED_OPTION_SPEED": "Spielgeschwindigkeit",
		"BROTATOQOL_GAMESPEED_OPTION_INFO": "100% = normal, 50% = halbe, 200% = doppelte, 1000% = zehnfache Geschwindigkeit. Gilt nur während der Wellen (auch der Wellen-Timer läuft schneller bzw. langsamer). Menüs, Pause und Shop laufen immer normal. Wirkt sofort, auch mitten in der Welle.",
	}
	var en := {
		"BROTATOQOL_GAMESPEED_OPTION_SPEED": "Game speed",
		"BROTATOQOL_GAMESPEED_OPTION_INFO": "100% = normal, 50% = half, 200% = double, 1000% = ten times the speed. Only applies during waves (the wave timer runs faster or slower too). Menus, pause and shop always run at normal speed. Takes effect immediately, even mid-wave.",
	}
	var locales := ["de", "en", "es", "fr", "it", "ja", "ko", "pl", "pt", "ru", "tr", "zh", "zh_TW"]
	for locale in locales:
		var source: Dictionary = de if locale == "de" else en
		var t := Translation.new()
		t.locale = locale
		for key in source:
			t.add_message(key, source[key])
		TranslationServer.add_translation(t)
