extends Node

# SellItems
#
# In the shop, clicking an owned item (like a weapon) now shows the item
# popup buttons: "Sell (+X)" and "Cancel". Selling removes the item, undoes
# its effects and gives its recycling value in materials (same formula the
# game uses for recycling weapons, incl. recycling bonuses).
#
# Unique / limited items are counted by the game from the items you own, so a
# sold unique item can show up and be bought in the shop again.
#
# Optional: with "Oudstand-ModOptions" a limit of items sold per run can be
# set (Options -> Mods). Default: unlimited.
#
# Only works in the shop. The extension is installed right away in _init:
# the item popup scene is already loaded by the main menu (item sets page),
# so installing it later would not affect the shop.

const MOD_ID := "BrotatoQoL-SellItems"
const LOG_NAME := "BrotatoQoL-SellItems:Main"
const MOD_OPTIONS_PATH := "/root/ModLoader/Oudstand-ModOptions/ModOptions"
const MOD_OPTIONS_RETRIES := 10
const OPTION_LIMIT := "max_sells"     # slider 0-30, 0 = unlimited
const LIMIT_META := "brotatoqol_sell_limit"
const LIMIT_MAX := 30

var _ext_dir := ""
var _mod_options = null
var _mod_options_tries := 0


func _init() -> void:
	Engine.set_meta(LIMIT_META, -1)
	_ext_dir = ModLoaderMod.get_unpacked_dir().plus_file(MOD_ID).plus_file("extensions")
	ModLoaderMod.install_script_extension(_ext_dir.plus_file("ui/menus/shop/item_popup.gd"))
	_add_translations()
	ModLoaderLog.info("Loaded", LOG_NAME)


func _ready() -> void:
	call_deferred("_register_mod_options")


func _register_mod_options() -> void:
	_mod_options = get_node_or_null(MOD_OPTIONS_PATH)
	if _mod_options == null:
		_mod_options_tries += 1
		if _mod_options_tries < MOD_OPTIONS_RETRIES:
			var _t = get_tree().create_timer(0.5).connect("timeout", self, "_register_mod_options")
		else:
			ModLoaderLog.info("ModOptions not installed - selling is unlimited", LOG_NAME)
		return
	if not _mod_options.get_registered_mods().has(MOD_ID):
		_mod_options.register_mod_options(MOD_ID, {
			"tab_title": "Sell Items",
			"options": [
				{
					"type": "slider",
					"id": OPTION_LIMIT,
					"label": "BROTATOQOL_SELL_OPTION_LIMIT",
					"default": 0,
					"min": 0,
					"max": LIMIT_MAX,
					"step": 1,
					"display_as_integer": true
				}
			],
			"info_text": "BROTATOQOL_SELL_OPTION_INFO"
		})
	_apply_limit(_mod_options.get_value(MOD_ID, OPTION_LIMIT))
	if not _mod_options.is_connected("config_changed", self, "_on_config_changed"):
		_mod_options.connect("config_changed", self, "_on_config_changed")


func _on_config_changed(mod_id: String, option_id: String, new_value) -> void:
	if mod_id == MOD_ID and option_id == OPTION_LIMIT:
		_apply_limit(new_value)


func _apply_limit(value) -> void:
	# slider value; 0 = unlimited
	var limit: int = int(round(float(value))) if (typeof(value) == TYPE_INT or typeof(value) == TYPE_REAL) else 0
	if limit <= 0:
		limit = -1
	Engine.set_meta(LIMIT_META, limit)
	ModLoaderLog.info("Sell limit: %s" % ("unlimited" if limit < 0 else str(limit)), LOG_NAME)


func _add_translations() -> void:
	var de := {
		"BROTATOQOL_SELL": "Verkaufen",
		"BROTATOQOL_SELL_LIMIT_REACHED": "Verkaufslimit erreicht",
		"BROTATOQOL_SELL_OPTION_LIMIT": "Max. Verkäufe pro Run (0 = unendlich)",
		"BROTATOQOL_SELL_OPTION_INFO": "Wie viele Items pro Run verkauft werden dürfen. Der Zähler wird mit dem Run gespeichert und beginnt bei jedem neuen Run bei 0.",
	}
	var en := {
		"BROTATOQOL_SELL": "Sell",
		"BROTATOQOL_SELL_LIMIT_REACHED": "Sell limit reached",
		"BROTATOQOL_SELL_OPTION_LIMIT": "Max. items sold per run (0 = unlimited)",
		"BROTATOQOL_SELL_OPTION_INFO": "How many items can be sold per run. The counter is saved with the run and starts at 0 in every new run.",
	}
	var locales := ["de", "en", "es", "fr", "it", "ja", "ko", "pl", "pt", "ru", "tr", "zh", "zh_TW"]
	for locale in locales:
		var source: Dictionary = de if locale == "de" else en
		var t := Translation.new()
		t.locale = locale
		for key in source:
			t.add_message(key, source[key])
		TranslationServer.add_translation(t)
