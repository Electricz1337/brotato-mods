extends Node

# DamageMeter
#
# Shows a list at the edge of the screen during a wave: icon of every weapon
# and every damage-dealing item, followed by its damage per second and/or
# its total damage in the current wave.
#
# Data comes from the game itself:
#   weapons -> WeaponData.dmg_dealt_last_wave (counted by the game per wave)
#   items   -> RunData.tracked_item_effects (the "Damage dealt" numbers shown
#              in item tooltips; they count over the whole run, so the meter
#              takes a snapshot at wave start and shows the difference)
#
# Optional: with "Oudstand-ModOptions" installed the meter can be configured
# in Options -> Mods. Without it the defaults below are used.

const MOD_ID := "BrotatoQoL-DamageMeter"
const LOG_NAME := "BrotatoQoL-DamageMeter:Main"
const MAIN_SCENE_PATH := "res://main.tscn"
const MOD_OPTIONS_PATH := "/root/ModLoader/Oudstand-ModOptions/ModOptions"
const MOD_OPTIONS_RETRIES := 10

const OPTION_ENABLED := "enabled"
const OPTION_SIDE := "side"
const OPTION_MODE := "mode"
const OPTION_WEAPONS := "show_weapons"
const OPTION_ITEMS := "show_items"

# Dropdown values are translation keys (the dropdown shows them translated)
const SIDE_RIGHT := "BROTATOQOL_DM_SIDE_RIGHT"
const SIDE_LEFT := "BROTATOQOL_DM_SIDE_LEFT"
const MODE_DPS := "BROTATOQOL_DM_MODE_DPS"
const MODE_TOTAL := "BROTATOQOL_DM_MODE_TOTAL"
const MODE_BOTH := "BROTATOQOL_DM_MODE_BOTH"

# Current settings, read by meter.gd every update
var enabled := true
var side_right := true
var show_dps := true
var show_total := false
var show_weapons := true
var show_items := true

var _mod_dir := ""
var _mod_options = null
var _mod_options_tries := 0


func _init() -> void:
	_mod_dir = ModLoaderMod.get_unpacked_dir().plus_file(MOD_ID)
	_add_translations()
	ModLoaderLog.info("Loaded", LOG_NAME)


func _ready() -> void:
	var _err = get_tree().connect("node_added", self, "_on_node_added")
	call_deferred("_register_mod_options")


# ---------------------------------------------------------------- ModOptions

func _register_mod_options() -> void:
	_mod_options = get_node_or_null(MOD_OPTIONS_PATH)
	if _mod_options == null:
		_mod_options_tries += 1
		if _mod_options_tries < MOD_OPTIONS_RETRIES:
			var _e = get_tree().create_timer(0.5).connect("timeout", self, "_register_mod_options")
		else:
			ModLoaderLog.info("ModOptions not installed - using default settings", LOG_NAME)
		return

	if not _mod_options.get_registered_mods().has(MOD_ID):
		_mod_options.register_mod_options(MOD_ID, {
			"tab_title": "Damage Meter",
			"options": [
				{
					"type": "toggle",
					"id": OPTION_ENABLED,
					"label": "BROTATOQOL_DM_OPTION_ENABLED",
					"default": true
				},
				{
					"type": "dropdown",
					"id": OPTION_SIDE,
					"label": "BROTATOQOL_DM_OPTION_SIDE",
					"default": SIDE_RIGHT,
					"choices": [SIDE_RIGHT, SIDE_LEFT]
				},
				{
					"type": "dropdown",
					"id": OPTION_MODE,
					"label": "BROTATOQOL_DM_OPTION_MODE",
					"default": MODE_DPS,
					"choices": [MODE_DPS, MODE_TOTAL, MODE_BOTH]
				},
				{
					"type": "toggle",
					"id": OPTION_WEAPONS,
					"label": "BROTATOQOL_DM_OPTION_WEAPONS",
					"default": true
				},
				{
					"type": "toggle",
					"id": OPTION_ITEMS,
					"label": "BROTATOQOL_DM_OPTION_ITEMS",
					"default": true
				}
			],
			"info_text": "BROTATOQOL_DM_OPTION_INFO"
		})

	# Registration loads the saved values but does not emit config_changed
	for option_id in [OPTION_ENABLED, OPTION_SIDE, OPTION_MODE, OPTION_WEAPONS, OPTION_ITEMS]:
		_apply_option(option_id, _mod_options.get_value(MOD_ID, option_id))
	if not _mod_options.is_connected("config_changed", self, "_on_config_changed"):
		_mod_options.connect("config_changed", self, "_on_config_changed")
	ModLoaderLog.info("Registered with ModOptions", LOG_NAME)


func _on_config_changed(mod_id: String, option_id: String, new_value) -> void:
	if mod_id != MOD_ID:
		return
	_apply_option(option_id, new_value)


func _apply_option(option_id: String, value) -> void:
	match option_id:
		OPTION_ENABLED:
			enabled = bool(value)
		OPTION_SIDE:
			side_right = str(value) != SIDE_LEFT
		OPTION_MODE:
			var mode := str(value)
			show_dps = mode != MODE_TOTAL
			show_total = mode == MODE_TOTAL or mode == MODE_BOTH
		OPTION_WEAPONS:
			show_weapons = bool(value)
		OPTION_ITEMS:
			show_items = bool(value)


# ---------------------------------------------------------------- wave scene

func _on_node_added(node: Node) -> void:
	if node.filename != MAIN_SCENE_PATH:
		return
	var meter = load(_mod_dir.plus_file("meter.gd")).new()
	meter.name = "BrotatoQoLDamageMeter"
	meter.settings = self
	node.call_deferred("add_child", meter)


# ---------------------------------------------------------------- texts

func _add_translations() -> void:
	var de := {
		"BROTATOQOL_DM_OPTION_ENABLED": "Damage Meter anzeigen",
		"BROTATOQOL_DM_OPTION_SIDE": "Position",
		"BROTATOQOL_DM_OPTION_MODE": "Anzeige",
		"BROTATOQOL_DM_OPTION_WEAPONS": "Waffen anzeigen",
		"BROTATOQOL_DM_OPTION_ITEMS": "Items anzeigen",
		"BROTATOQOL_DM_OPTION_INFO": "Zeigt während einer Welle für jede Waffe und jedes schadensverursachende Item den Schaden pro Sekunde und/oder den Gesamtschaden der aktuellen Welle.",
		"BROTATOQOL_DM_SIDE_RIGHT": "Rechts",
		"BROTATOQOL_DM_SIDE_LEFT": "Links",
		"BROTATOQOL_DM_MODE_DPS": "Schaden pro Sekunde",
		"BROTATOQOL_DM_MODE_TOTAL": "Gesamtschaden",
		"BROTATOQOL_DM_MODE_BOTH": "Beides",
	}
	var en := {
		"BROTATOQOL_DM_OPTION_ENABLED": "Show damage meter",
		"BROTATOQOL_DM_OPTION_SIDE": "Position",
		"BROTATOQOL_DM_OPTION_MODE": "Display",
		"BROTATOQOL_DM_OPTION_WEAPONS": "Show weapons",
		"BROTATOQOL_DM_OPTION_ITEMS": "Show items",
		"BROTATOQOL_DM_OPTION_INFO": "Shows the damage per second and/or the total damage of every weapon and damage-dealing item in the current wave.",
		"BROTATOQOL_DM_SIDE_RIGHT": "Right",
		"BROTATOQOL_DM_SIDE_LEFT": "Left",
		"BROTATOQOL_DM_MODE_DPS": "Damage per second",
		"BROTATOQOL_DM_MODE_TOTAL": "Total damage",
		"BROTATOQOL_DM_MODE_BOTH": "Both",
	}
	var locales := ["de", "en", "es", "fr", "it", "ja", "ko", "pl", "pt", "ru", "tr", "zh", "zh_TW"]
	for locale in locales:
		var source: Dictionary = de if locale == "de" else en
		var t := Translation.new()
		t.locale = locale
		for key in source:
			t.add_message(key, source[key])
		TranslationServer.add_translation(t)
