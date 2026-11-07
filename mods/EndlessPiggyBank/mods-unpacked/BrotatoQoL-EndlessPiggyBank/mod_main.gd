extends Node

# EndlessPiggyBank
#
# Vanilla (main.gd, at the start of every wave):
#   pct_val = effect "gain_pct_gold_start_wave"   (Piggy Bank: +20%)
#   applied only while current_wave <= nb_of_waves  -> stops after wave 20
#
# This mod does not replace any game script. When a wave starts after the
# last regular wave, it pays out the same percentage itself, right after
# the game's own wave-start handling. Up to wave 20 nothing changes.
#
# Optional: if "Oudstand-ModOptions" is installed, the mod registers an
# on/off toggle in Options -> Mods. Without it, the mod is always active.
#
# Game singletons are accessed via /root/... on purpose, because this script
# is compiled while the game's autoloads are still being created.

const MOD_ID := "BrotatoQoL-EndlessPiggyBank"
const LOG_NAME := "BrotatoQoL-EndlessPiggyBank:Main"
const MAIN_SCENE_PATH := "res://main.tscn"
const LIMITED_TEXT_KEY := "effect_gain_pct_gold_start_wave_limited"
const UNLIMITED_TEXT_KEY := "effect_gain_pct_gold_start_wave"
const MOD_OPTIONS_PATH := "/root/ModLoader/Oudstand-ModOptions/ModOptions"
const OPTION_ENABLED := "enabled"
const MOD_OPTIONS_RETRIES := 10

var enabled := true

var _setup_done := false
var _mod_options = null
var _mod_options_tries := 0


func _init() -> void:
	_add_translations()
	ModLoaderLog.info("Loaded", LOG_NAME)


func _ready() -> void:
	var _err = get_tree().connect("node_added", self, "_on_node_added")
	set_process(true)
	call_deferred("_register_mod_options")


# First frame: the game is fully running, all singletons exist
func _process(_delta: float) -> void:
	set_process(false)
	if _setup_done:
		return
	_setup_done = true
	_apply_enabled_state()


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
			"tab_title": "Endless Piggy Bank",
			"options": [
				{
					"type": "toggle",
					"id": OPTION_ENABLED,
					"label": "BROTATOQOL_PIGGY_OPTION_ENABLED",
					"default": true
				}
			],
			"info_text": "BROTATOQOL_PIGGY_OPTION_INFO"
		})

	# Registration loads the saved value but does not emit config_changed
	enabled = bool(_mod_options.get_value(MOD_ID, OPTION_ENABLED))
	if not _mod_options.is_connected("config_changed", self, "_on_config_changed"):
		_mod_options.connect("config_changed", self, "_on_config_changed")
	ModLoaderLog.info("Registered with ModOptions (enabled = %s)" % enabled, LOG_NAME)
	if _setup_done:
		_apply_enabled_state()


func _on_config_changed(mod_id: String, option_id: String, new_value) -> void:
	if mod_id != MOD_ID or option_id != OPTION_ENABLED:
		return
	enabled = bool(new_value)
	ModLoaderLog.info("Mod %s" % ("enabled" if enabled else "disabled"), LOG_NAME)
	_apply_enabled_state()


func _apply_enabled_state() -> void:
	_set_item_description(enabled)


# ---------------------------------------------------------------- item text

# Enabled: show the unlimited text; disabled: restore the game's original
func _set_item_description(unlimited: bool) -> void:
	var item_service = get_node_or_null("/root/ItemService")
	var keys = get_node_or_null("/root/Keys")
	if item_service == null or keys == null:
		return
	var piggy_bank = item_service.get_item_from_id(keys.item_piggy_bank_hash)
	if piggy_bank == null:
		return
	var from_key: String = LIMITED_TEXT_KEY if unlimited else UNLIMITED_TEXT_KEY
	var to_key: String = UNLIMITED_TEXT_KEY if unlimited else LIMITED_TEXT_KEY
	for effect in piggy_bank.effects:
		if effect.text_key == from_key:
			effect.text_key = to_key


# ---------------------------------------------------------------- wave start

# A new wave = a new main scene. Hook into its player spawn signal.
func _on_node_added(node: Node) -> void:
	if node.filename != MAIN_SCENE_PATH:
		return
	var spawner = node.get_node_or_null("EntitySpawner")
	if spawner == null:
		ModLoaderLog.error("EntitySpawner not found", LOG_NAME)
		return
	# Deferred: runs after the game's own handler for the same signal
	var _err = spawner.connect("players_spawned", self, "_on_players_spawned", [], CONNECT_DEFERRED | CONNECT_ONESHOT)


func _on_players_spawned(_players) -> void:
	if not enabled:
		return
	var run_data = get_node_or_null("/root/RunData")
	var keys = get_node_or_null("/root/Keys")
	if run_data == null or keys == null:
		return

	# Up to the last regular wave the game handles it itself
	if run_data.current_wave <= run_data.nb_of_waves:
		return

	for player_index in run_data.get_player_count():
		var pct_val = run_data.get_player_effect(keys.gain_pct_gold_start_wave_hash, player_index)
		if pct_val <= 0:
			continue
		var gold = run_data.get_player_gold(player_index)
		var val := int(gold * (pct_val / 100.0))
		if val <= 0:
			continue
		run_data.add_gold(val, player_index)
		run_data.add_tracked_value(player_index, keys.item_piggy_bank_hash, val)
		ModLoaderLog.info("Wave %s: +%s materials (%s%%) for player %s" % [run_data.current_wave, val, pct_val, player_index], LOG_NAME)


# ---------------------------------------------------------------- texts

func _add_translations() -> void:
	var de := {
		"BROTATOQOL_PIGGY_OPTION_ENABLED": "Sparschwein auch nach Welle 20 aktiv",
		"BROTATOQOL_PIGGY_OPTION_INFO": "Im Endlos-Modus zahlt das Sparschwein ab Welle 21 weiterhin Zinsen. Ausschalten stellt das Originalverhalten wieder her.",
	}
	var en := {
		"BROTATOQOL_PIGGY_OPTION_ENABLED": "Piggy Bank keeps working after wave 20",
		"BROTATOQOL_PIGGY_OPTION_INFO": "In endless mode the Piggy Bank keeps paying interest from wave 21 on. Turn off to restore the original behavior.",
	}
	var locales := ["de", "en", "es", "fr", "it", "ja", "ko", "pl", "pt", "ru", "tr", "zh", "zh_TW"]
	for locale in locales:
		var source: Dictionary = de if locale == "de" else en
		var t := Translation.new()
		t.locale = locale
		for key in source:
			t.add_message(key, source[key])
		TranslationServer.add_translation(t)
