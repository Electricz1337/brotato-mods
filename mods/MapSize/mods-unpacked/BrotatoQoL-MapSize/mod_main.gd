extends Node

# MapSize
#
# Scales the arena of every wave with a factor (ModOptions slider, 50%-300%).
#
# How: the game already has a "map size" effect (used by some items and
# characters): at the start of a wave, main.gd multiplies the zone width and
# height with (1 + map_size / 100). Right before the wave scene runs its
# _ready, this mod temporarily raises player 1's map_size effect so the
# result is  (game's own map size) x factor,  and removes it again right
# after the wave scene is set up. Nothing is changed permanently and nothing
# ends up in the save file.
#
# The game's minimum map size (12 x 12 tiles) still applies. The number of
# enemies is not changed.

const MOD_ID := "BrotatoQoL-MapSize"
const LOG_NAME := "BrotatoQoL-MapSize:Main"
const MAIN_SCENE_PATH := "res://main.tscn"
const MOD_OPTIONS_PATH := "/root/ModLoader/Oudstand-ModOptions/ModOptions"
const MOD_OPTIONS_RETRIES := 10
const OPTION_ENABLED := "enabled"
const OPTION_SIZE := "map_size"
const DEFAULT_SIZE := 1.0
const MIN_SIZE := 0.5
const MAX_SIZE := 3.0

var _enabled := true
var _size := DEFAULT_SIZE
var _mod_options = null
var _mod_options_tries := 0
var _applied_bonus := 0          # map_size points added for the current wave


func _init() -> void:
	_add_translations()
	ModLoaderLog.info("Loaded", LOG_NAME)


func _ready() -> void:
	var _e = get_tree().connect("node_added", self, "_on_node_added")
	call_deferred("_register_mod_options")


# ---------------------------------------------------------------- wave start

# node_added fires when the wave scene enters the tree - before its _ready
func _on_node_added(node: Node) -> void:
	if node.filename != MAIN_SCENE_PATH:
		return
	_remove_bonus()     # safety: leftovers from an interrupted wave
	var factor: float = clamp(_size, MIN_SIZE, MAX_SIZE) if _enabled else 1.0
	if is_equal_approx(factor, 1.0):
		return
	var run_data = get_node_or_null("/root/RunData")
	var keys = get_node_or_null("/root/Keys")
	if run_data == null or keys == null or run_data.players_data.empty():
		return

	# total map_size of all players (items/characters), as the game sums it up
	var current: float = float(run_data.sum_all_player_effects(keys.map_size_hash))
	var wanted: float = ((1.0 + current / 100.0) * factor - 1.0) * 100.0
	_applied_bonus = int(round(wanted - current))
	var effects: Dictionary = run_data.players_data[0].effects
	effects[keys.map_size_hash] = int(effects.get(keys.map_size_hash, 0)) + _applied_bonus
	ModLoaderLog.info("Wave map size x%.2f (map_size %+d)" % [factor, _applied_bonus], LOG_NAME)

	# remove the temporary bonus as soon as the wave is set up
	var _e = node.connect("ready", self, "_remove_bonus", [], CONNECT_ONESHOT)


func _remove_bonus() -> void:
	if _applied_bonus == 0:
		return
	var run_data = get_node_or_null("/root/RunData")
	var keys = get_node_or_null("/root/Keys")
	if run_data != null and keys != null and not run_data.players_data.empty():
		var effects: Dictionary = run_data.players_data[0].effects
		effects[keys.map_size_hash] = int(effects.get(keys.map_size_hash, 0)) - _applied_bonus
	_applied_bonus = 0


# ---------------------------------------------------------------- ModOptions

func _register_mod_options() -> void:
	_mod_options = get_node_or_null(MOD_OPTIONS_PATH)
	if _mod_options == null:
		_mod_options_tries += 1
		if _mod_options_tries < MOD_OPTIONS_RETRIES:
			var _t = get_tree().create_timer(0.5).connect("timeout", self, "_register_mod_options")
		else:
			ModLoaderLog.info("ModOptions not installed - map size unchanged", LOG_NAME)
		return
	if not _mod_options.get_registered_mods().has(MOD_ID):
		_mod_options.register_mod_options(MOD_ID, {
			"tab_title": "Map Size",
			"options": [
				{
					"type": "toggle",
					"id": OPTION_ENABLED,
					"label": "BROTATOQOL_MAPSIZE_OPTION_ENABLED",
					"default": true
				},
				{
					"type": "slider",
					"id": OPTION_SIZE,
					"label": "BROTATOQOL_MAPSIZE_OPTION_SIZE",
					"default": DEFAULT_SIZE,
					"min": MIN_SIZE,
					"max": MAX_SIZE,
					"step": 0.05
				}
			],
			"info_text": "BROTATOQOL_MAPSIZE_OPTION_INFO"
		})
	_enabled = bool(_mod_options.get_value(MOD_ID, OPTION_ENABLED))
	_size = float(_mod_options.get_value(MOD_ID, OPTION_SIZE))
	if not _mod_options.is_connected("config_changed", self, "_on_config_changed"):
		_mod_options.connect("config_changed", self, "_on_config_changed")
	ModLoaderLog.info("Registered with ModOptions (enabled=%s, size=%d%%)" % [_enabled, int(_size * 100)], LOG_NAME)


func _on_config_changed(mod_id: String, option_id: String, new_value) -> void:
	if mod_id != MOD_ID:
		return
	if option_id == OPTION_ENABLED:
		_enabled = bool(new_value)
	elif option_id == OPTION_SIZE:
		_size = float(new_value)


# ---------------------------------------------------------------- texts

func _add_translations() -> void:
	var de := {
		"BROTATOQOL_MAPSIZE_OPTION_ENABLED": "Kartengröße anpassen",
		"BROTATOQOL_MAPSIZE_OPTION_SIZE": "Kartengröße",
		"BROTATOQOL_MAPSIZE_OPTION_INFO": "100% = normale Arena. Breite und Höhe der Arena werden mit dem Wert multipliziert (Items, die die Karte verändern, wirken zusätzlich). Gilt ab der nächsten Welle. Die Anzahl der Gegner bleibt gleich.",
	}
	var en := {
		"BROTATOQOL_MAPSIZE_OPTION_ENABLED": "Change map size",
		"BROTATOQOL_MAPSIZE_OPTION_SIZE": "Map size",
		"BROTATOQOL_MAPSIZE_OPTION_INFO": "100% = normal arena. Arena width and height are multiplied by this value (items that change the map still apply on top). Takes effect from the next wave. The number of enemies stays the same.",
	}
	var locales := ["de", "en", "es", "fr", "it", "ja", "ko", "pl", "pt", "ru", "tr", "zh", "zh_TW"]
	for locale in locales:
		var source: Dictionary = de if locale == "de" else en
		var t := Translation.new()
		t.locale = locale
		for key in source:
			t.add_message(key, source[key])
		TranslationServer.add_translation(t)
