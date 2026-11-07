extends Node

# EndlessHarvesting
#
# Vanilla (main.gd, _on_HarvestingTimer_timeout, shortly after each wave):
#   wave <= nb_of_waves : harvesting += ceil(harvesting * harvesting_growth%)   (default 5%)
#   wave >  nb_of_waves : harvesting -= ceil(harvesting * 20%)                  (endless decrease)
#
# This mod does not replace any game script. When a wave scene is created,
# the HarvestingTimer's "timeout" is re-routed to this mod:
#   - up to the last regular wave the game's own function is called unchanged
#   - after that, the normal growth (incl. Crown tracking) is applied instead
#     of the 20% decrease
#
# Optional: if "Oudstand-ModOptions" is installed, the mod registers an
# on/off toggle in Options -> Mods. Without it, the mod is always active.
#
# Game singletons are accessed via /root/... on purpose, because this script
# is compiled while the game's autoloads are still being created.

const LOG_NAME := "BrotatoQoL-EndlessHarvesting:Main"
const MAIN_SCENE_PATH := "res://main.tscn"
const VANILLA_METHOD := "_on_HarvestingTimer_timeout"
const MOD_ID := "BrotatoQoL-EndlessHarvesting"
const MOD_OPTIONS_PATH := "/root/ModLoader/Oudstand-ModOptions/ModOptions"
const OPTION_ENABLED := "enabled"
const MOD_OPTIONS_RETRIES := 10

var enabled := true

var _mod_options = null
var _mod_options_tries := 0


func _init() -> void:
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
			# ModOptions may not be ready yet - try again shortly
			var _e = get_tree().create_timer(0.5).connect("timeout", self, "_register_mod_options")
		else:
			ModLoaderLog.info("ModOptions not installed - mod is always active", LOG_NAME)
		return

	if not _mod_options.get_registered_mods().has(MOD_ID):
		_mod_options.register_mod_options(MOD_ID, {
			"tab_title": "Endless Harvesting",
			"options": [
				{
					"type": "toggle",
					"id": OPTION_ENABLED,
					"label": "BROTATOQOL_HARVEST_OPTION_ENABLED",
					"default": true
				}
			],
			"info_text": "BROTATOQOL_HARVEST_OPTION_INFO"
		})

	# Registration loads the saved value but does not emit config_changed
	enabled = bool(_mod_options.get_value(MOD_ID, OPTION_ENABLED))
	if not _mod_options.is_connected("config_changed", self, "_on_config_changed"):
		_mod_options.connect("config_changed", self, "_on_config_changed")
	ModLoaderLog.info("Registered with ModOptions (enabled = %s)" % enabled, LOG_NAME)


func _on_config_changed(mod_id: String, option_id: String, new_value) -> void:
	if mod_id != MOD_ID or option_id != OPTION_ENABLED:
		return
	enabled = bool(new_value)
	ModLoaderLog.info("Mod %s" % ("enabled" if enabled else "disabled"), LOG_NAME)


# ---------------------------------------------------------------- wave scene


func _on_node_added(node: Node) -> void:
	if node.filename != MAIN_SCENE_PATH:
		return
	var timer = node.get_node_or_null("HarvestingTimer")
	if timer == null:
		ModLoaderLog.error("HarvestingTimer not found", LOG_NAME)
		return
	if timer.is_connected("timeout", node, VANILLA_METHOD):
		timer.disconnect("timeout", node, VANILLA_METHOD)
	var _err = timer.connect("timeout", self, "_on_harvesting_timer_timeout", [node])


func _on_harvesting_timer_timeout(main: Node) -> void:
	var run_data = get_node_or_null("/root/RunData")
	if run_data == null or not is_instance_valid(main):
		return

	# Mod disabled or regular waves: let the game do exactly what it always does
	if not enabled or run_data.current_wave <= run_data.nb_of_waves:
		main.call(VANILLA_METHOD)
		return

	var utils = get_node_or_null("/root/Utils")
	var keys = get_node_or_null("/root/Keys")
	if utils == null or keys == null:
		main.call(VANILLA_METHOD)
		return

	# Endless waves: normal growth instead of the 20% decrease
	for player_index in run_data.get_player_count():
		var harvesting_stat = utils.get_stat(keys.stat_harvesting_hash, player_index)
		if harvesting_stat <= 0:
			continue
		var harvesting_growth = run_data.get_player_effect(keys.harvesting_growth_hash, player_index)
		var val = ceil(harvesting_stat * (harvesting_growth / 100.0))

		# Crown: same tracking as in regular waves
		for item in run_data.get_player_items_ref(player_index):
			if item.my_id_hash == keys.item_crown_hash:
				var crown_value = item.effects[0].value
				run_data.add_tracked_value(player_index, keys.item_crown_hash, int(ceil(harvesting_stat * (crown_value / 100.0))))
				break

		if val > 0:
			run_data.add_stat(keys.stat_harvesting_hash, val, player_index)
			ModLoaderLog.info("Wave %s: harvesting +%s (%s%%) for player %s" % [run_data.current_wave, val, harvesting_growth, player_index], LOG_NAME)


# ---------------------------------------------------------------- texts

func _add_translations() -> void:
	var de := {
		"BROTATOQOL_HARVEST_OPTION_ENABLED": "Ernte wächst nach Welle 20 weiter",
		"BROTATOQOL_HARVEST_OPTION_INFO": "Im Endlos-Modus wächst die Ernte ab Welle 21 normal weiter, statt jede Welle um 20 % zu sinken. Ausschalten stellt das Originalverhalten wieder her.",
	}
	var en := {
		"BROTATOQOL_HARVEST_OPTION_ENABLED": "Harvesting keeps growing after wave 20",
		"BROTATOQOL_HARVEST_OPTION_INFO": "In endless mode harvesting keeps growing normally from wave 21 on instead of dropping by 20% every wave. Turn off to restore the original behavior.",
	}
	var locales := ["de", "en", "es", "fr", "it", "ja", "ko", "pl", "pt", "ru", "tr", "zh", "zh_TW"]
	for locale in locales:
		var source: Dictionary = de if locale == "de" else en
		var t := Translation.new()
		t.locale = locale
		for key in source:
			t.add_message(key, source[key])
		TranslationServer.add_translation(t)
