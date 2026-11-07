extends Node

# MaterialMultiplier
#
# Every collected material is worth more: after the game has added the
# materials of a pickup (incl. all its own bonuses), the mod adds the same
# amount again (multiplier - 1) times.
#
# Settings (with "Oudstand-ModOptions", Options -> Mods):
#   - on/off
#   - multiplier: x2 (default), x3, x5, x10, x25, x50, x100
#   - also multiply XP (default: off - you level up as usual)
#
# The extension of main.gd is installed on the first frame, because the
# script needs the game's autoloads (the wave scene is only loaded later).

const MOD_ID := "BrotatoQoL-MaterialMultiplier"
const LOG_NAME := "BrotatoQoL-MaterialMultiplier:Main"
const MOD_OPTIONS_PATH := "/root/ModLoader/Oudstand-ModOptions/ModOptions"
const MOD_OPTIONS_RETRIES := 10
const OPTION_ENABLED := "enabled"
const OPTION_MULTIPLIER := "multiplier"
const OPTION_XP := "multiply_xp"
const CHOICES := ["x2", "x3", "x5", "x10", "x25", "x50", "x100"]
const DEFAULT_CHOICE := "x2"
const META_MULTIPLIER := "brotatoqol_material_multiplier"   # int, 1 = off
const META_XP := "brotatoqol_material_multiplier_xp"        # bool

var _ext_dir := ""
var _installed := false
var _mod_options = null
var _mod_options_tries := 0
var _enabled := true
var _choice := DEFAULT_CHOICE
var _multiply_xp := false


func _init() -> void:
	_ext_dir = ModLoaderMod.get_unpacked_dir().plus_file(MOD_ID).plus_file("extensions")
	_publish()
	_add_translations()
	ModLoaderLog.info("Loaded", LOG_NAME)


func _ready() -> void:
	set_process(true)
	call_deferred("_register_mod_options")


func _process(_delta: float) -> void:
	set_process(false)
	if _installed:
		return
	_installed = true
	ModLoaderMod.install_script_extension(_ext_dir.plus_file("main.gd"))
	ModLoaderLog.info("main.gd extension installed", LOG_NAME)


func _publish() -> void:
	var multiplier := 1
	if _enabled:
		var text := _choice.trim_prefix("x")
		multiplier = int(text) if text.is_valid_integer() else 2
	Engine.set_meta(META_MULTIPLIER, max(1, multiplier))
	Engine.set_meta(META_XP, _multiply_xp)


# ---------------------------------------------------------------- ModOptions

func _register_mod_options() -> void:
	_mod_options = get_node_or_null(MOD_OPTIONS_PATH)
	if _mod_options == null:
		_mod_options_tries += 1
		if _mod_options_tries < MOD_OPTIONS_RETRIES:
			var _t = get_tree().create_timer(0.5).connect("timeout", self, "_register_mod_options")
		else:
			ModLoaderLog.info("ModOptions not installed - materials x2", LOG_NAME)
		return
	if not _mod_options.get_registered_mods().has(MOD_ID):
		_mod_options.register_mod_options(MOD_ID, {
			"tab_title": "Material Multiplier",
			"options": [
				{
					"type": "toggle",
					"id": OPTION_ENABLED,
					"label": "BROTATOQOL_MATMULT_OPTION_ENABLED",
					"default": true
				},
				{
					"type": "dropdown",
					"id": OPTION_MULTIPLIER,
					"label": "BROTATOQOL_MATMULT_OPTION_MULTIPLIER",
					"default": DEFAULT_CHOICE,
					"choices": CHOICES
				},
				{
					"type": "toggle",
					"id": OPTION_XP,
					"label": "BROTATOQOL_MATMULT_OPTION_XP",
					"default": false
				}
			],
			"info_text": "BROTATOQOL_MATMULT_OPTION_INFO"
		})
	_enabled = bool(_mod_options.get_value(MOD_ID, OPTION_ENABLED))
	_choice = str(_mod_options.get_value(MOD_ID, OPTION_MULTIPLIER))
	_multiply_xp = bool(_mod_options.get_value(MOD_ID, OPTION_XP))
	_publish()
	if not _mod_options.is_connected("config_changed", self, "_on_config_changed"):
		_mod_options.connect("config_changed", self, "_on_config_changed")
	ModLoaderLog.info("Registered with ModOptions (enabled=%s, %s, xp=%s)" % [_enabled, _choice, _multiply_xp], LOG_NAME)


func _on_config_changed(mod_id: String, option_id: String, new_value) -> void:
	if mod_id != MOD_ID:
		return
	match option_id:
		OPTION_ENABLED:
			_enabled = bool(new_value)
		OPTION_MULTIPLIER:
			_choice = str(new_value)
		OPTION_XP:
			_multiply_xp = bool(new_value)
		_:
			return
	_publish()


# ---------------------------------------------------------------- texts

func _add_translations() -> void:
	var de := {
		"BROTATOQOL_MATMULT_OPTION_ENABLED": "Material-Multiplikator aktiv",
		"BROTATOQOL_MATMULT_OPTION_MULTIPLIER": "Multiplikator",
		"BROTATOQOL_MATMULT_OPTION_XP": "Erfahrung (XP) auch multiplizieren",
		"BROTATOQOL_MATMULT_OPTION_INFO": "Eingesammelte Materialien werden mit dem gewählten Wert multipliziert (inklusive aller Boni des Spiels). Erfahrung bleibt normal, außer der Schalter oben ist aktiv.",
	}
	var en := {
		"BROTATOQOL_MATMULT_OPTION_ENABLED": "Material multiplier enabled",
		"BROTATOQOL_MATMULT_OPTION_MULTIPLIER": "Multiplier",
		"BROTATOQOL_MATMULT_OPTION_XP": "Also multiply experience (XP)",
		"BROTATOQOL_MATMULT_OPTION_INFO": "Collected materials are multiplied by the selected value (including all of the game's bonuses). Experience stays normal unless the switch above is on.",
	}
	var locales := ["de", "en", "es", "fr", "it", "ja", "ko", "pl", "pt", "ru", "tr", "zh", "zh_TW"]
	for locale in locales:
		var source: Dictionary = de if locale == "de" else en
		var t := Translation.new()
		t.locale = locale
		for key in source:
			t.add_message(key, source[key])
		TranslationServer.add_translation(t)
