extends Node

# BanList
#
# Uses the game's own per-run ban list (RunData.players_data[i].banned_items):
# the game already removes everything on it from the shop / crate pools and
# saves it with the run.
#
#  - every shop card shows the game's "Ban" button - no challenge unlock and
#    no token limit needed, works for items and weapons (all tiers)
#  - a "Ban list (N)" button next to "Reroll" opens a window with all banned
#    items/weapons of the run; clicking one lifts the ban
#
# Optional: with "Oudstand-ModOptions" a ban limit can be set (Options ->
# Mods). Default: unlimited. The limit counts the currently active bans, so
# lifting a ban frees a slot again.
#
# The extensions are installed on the first frame, because the extended game
# scripts need the game's autoloads.

const MOD_ID := "BrotatoQoL-BanList"
const LOG_NAME := "BrotatoQoL-BanList:Main"
const SHOP_SCENE := "res://ui/menus/shop/shop.tscn"
const MOD_OPTIONS_PATH := "/root/ModLoader/Oudstand-ModOptions/ModOptions"
const MOD_OPTIONS_RETRIES := 10
const OPTION_LIMIT := "max_bans"     # slider 0-30, 0 = unlimited
const LIMIT_META := "brotatoqol_ban_limit"
const LIMIT_MAX := 30

var _mod_dir := ""
var _installed := false
var _mod_options = null
var _mod_options_tries := 0


func _init() -> void:
	Engine.set_meta(LIMIT_META, -1)
	_mod_dir = ModLoaderMod.get_unpacked_dir().plus_file(MOD_ID)
	_add_translations()
	ModLoaderLog.info("Loaded", LOG_NAME)


func _ready() -> void:
	var _e = get_tree().connect("node_added", self, "_on_node_added")
	set_process(true)
	call_deferred("_register_mod_options")


# ---------------------------------------------------------------- ModOptions

func _register_mod_options() -> void:
	_mod_options = get_node_or_null(MOD_OPTIONS_PATH)
	if _mod_options == null:
		_mod_options_tries += 1
		if _mod_options_tries < MOD_OPTIONS_RETRIES:
			var _t = get_tree().create_timer(0.5).connect("timeout", self, "_register_mod_options")
		else:
			ModLoaderLog.info("ModOptions not installed - bans are unlimited", LOG_NAME)
		return
	if not _mod_options.get_registered_mods().has(MOD_ID):
		_mod_options.register_mod_options(MOD_ID, {
			"tab_title": "Ban List",
			"options": [
				{
					"type": "slider",
					"id": OPTION_LIMIT,
					"label": "BROTATOQOL_BAN_OPTION_LIMIT",
					"default": 0,
					"min": 0,
					"max": LIMIT_MAX,
					"step": 1,
					"display_as_integer": true
				}
			],
			"info_text": "BROTATOQOL_BAN_OPTION_INFO"
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
	ModLoaderLog.info("Ban limit: %s" % ("unlimited" if limit < 0 else str(limit)), LOG_NAME)


# ---------------------------------------------------------------- shop


func _process(_delta: float) -> void:
	set_process(false)
	if _installed:
		return
	_installed = true
	var ext := _mod_dir.plus_file("extensions/ui/menus/shop")
	ModLoaderMod.install_script_extension(ext.plus_file("shop_item.gd"))
	ModLoaderMod.install_script_extension(ext.plus_file("shop_items_container.gd"))
	ModLoaderLog.info("Shop extensions installed", LOG_NAME)


func _on_node_added(node: Node) -> void:
	if node.filename != SHOP_SCENE:
		return
	var ui = load(_mod_dir.plus_file("ban_list_ui.gd")).new()
	ui.name = "BrotatoQoLBanListUI"
	node.call_deferred("add_child", ui)


func _add_translations() -> void:
	var de := {
		"BROTATOQOL_BAN": "Bannen",
		"BROTATOQOL_BAN_LIST": "Bannliste",
		"BROTATOQOL_BAN_LIST_HINT": "Klicke auf ein Item, um den Bann aufzuheben",
		"BROTATOQOL_BAN_LIST_EMPTY": "Noch nichts gebannt.\nIm Shop kannst du Items und Waffen mit \"Bannen\" aus der Rotation nehmen.",
		"BROTATOQOL_BAN_LIST_CLOSE": "Schließen",
		"BROTATOQOL_BAN_LIST_UNBANNED": "Bann aufgehoben: {name}",
		"BROTATOQOL_BAN_LIMIT_REACHED": "Bann-Limit erreicht",
		"BROTATOQOL_BAN_OPTION_LIMIT": "Max. Banns pro Run (0 = unendlich)",
		"BROTATOQOL_BAN_OPTION_INFO": "Wie viele Items/Waffen gleichzeitig gebannt sein dürfen. Wird ein Bann in der Bannliste aufgehoben, ist der Platz wieder frei.",
	}
	var en := {
		"BROTATOQOL_BAN": "Ban",
		"BROTATOQOL_BAN_LIST": "Ban list",
		"BROTATOQOL_BAN_LIST_HINT": "Click an item to lift its ban",
		"BROTATOQOL_BAN_LIST_EMPTY": "Nothing banned yet.\nIn the shop, use \"Ban\" to take items and weapons out of the rotation.",
		"BROTATOQOL_BAN_LIST_CLOSE": "Close",
		"BROTATOQOL_BAN_LIST_UNBANNED": "Ban lifted: {name}",
		"BROTATOQOL_BAN_LIMIT_REACHED": "Ban limit reached",
		"BROTATOQOL_BAN_OPTION_LIMIT": "Max. bans per run (0 = unlimited)",
		"BROTATOQOL_BAN_OPTION_INFO": "How many items/weapons can be banned at the same time. Lifting a ban in the ban list frees the slot again.",
	}
	var locales := ["de", "en", "es", "fr", "it", "ja", "ko", "pl", "pt", "ru", "tr", "zh", "zh_TW"]
	for locale in locales:
		var source: Dictionary = de if locale == "de" else en
		var t := Translation.new()
		t.locale = locale
		for key in source:
			t.add_message(key, source[key])
		TranslationServer.add_translation(t)
