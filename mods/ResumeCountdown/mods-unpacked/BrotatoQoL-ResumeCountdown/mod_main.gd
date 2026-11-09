extends Node

# ResumeCountdown
#
# When you leave the pause menu during a wave, the game stays frozen for a
# short countdown (default 3 seconds) so you can get an overview first.
# Length: 1 - 10 seconds via a ModOptions slider.
# Pressing pause during the countdown opens the pause menu again.

const MOD_ID := "BrotatoQoL-ResumeCountdown"
const LOG_NAME := "BrotatoQoL-ResumeCountdown:Main"
const MOD_OPTIONS_PATH := "/root/ModLoader/Oudstand-ModOptions/ModOptions"
const MOD_OPTIONS_RETRIES := 10
const OPTION_SECONDS := "countdown_seconds"
const SECONDS_META := "brotatoqol_resume_countdown_seconds"
const DEFAULT_SECONDS := 3

var _mod_options = null
var _mod_options_tries := 0


func _init() -> void:
	Engine.set_meta(SECONDS_META, DEFAULT_SECONDS)
	_add_translations()
	# pause_menu.tscn can already be cached early, so extend right away
	var dir: String = ModLoaderMod.get_unpacked_dir().plus_file(MOD_ID)
	ModLoaderMod.install_script_extension(dir.plus_file("extensions/ui/menus/ingame/pause_menu.gd"))
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
			ModLoaderLog.info("ModOptions not installed - countdown is %d s" % DEFAULT_SECONDS, LOG_NAME)
		return
	if not _mod_options.get_registered_mods().has(MOD_ID):
		_mod_options.register_mod_options(MOD_ID, {
			"tab_title": "Resume Countdown",
			"options": [
				{
					"type": "slider",
					"id": OPTION_SECONDS,
					"label": "BROTATOQOL_RC_OPTION_SECONDS",
					"default": DEFAULT_SECONDS,
					"min": 1,
					"max": 10,
					"step": 1,
					"display_as_integer": true
				}
			],
			"info_text": "BROTATOQOL_RC_OPTION_INFO"
		})
	var value = _mod_options.get_value(MOD_ID, OPTION_SECONDS)
	if value != null:
		_set_seconds(value)
	if not _mod_options.is_connected("config_changed", self, "_on_config_changed"):
		_mod_options.connect("config_changed", self, "_on_config_changed")
	ModLoaderLog.info("Registered with ModOptions (countdown=%d s)" % int(Engine.get_meta(SECONDS_META)), LOG_NAME)


func _on_config_changed(mod_id: String, option_id: String, new_value) -> void:
	if mod_id == MOD_ID and option_id == OPTION_SECONDS:
		_set_seconds(new_value)


func _set_seconds(value) -> void:
	Engine.set_meta(SECONDS_META, int(clamp(round(float(value)), 1, 10)))


func _add_translations() -> void:
	var de := {
		"BROTATOQOL_RC_OPTION_SECONDS": "Countdown (Sekunden)",
		"BROTATOQOL_RC_OPTION_INFO": "Nach dem Verlassen des Pausemenüs bleibt das Spiel für diese Anzahl Sekunden eingefroren, damit man sich einen Überblick verschaffen kann. Pause während des Countdowns öffnet das Menü wieder.",
	}
	var en := {
		"BROTATOQOL_RC_OPTION_SECONDS": "Countdown (seconds)",
		"BROTATOQOL_RC_OPTION_INFO": "After leaving the pause menu the game stays frozen for this many seconds so you can get an overview. Pressing pause during the countdown opens the menu again.",
	}
	var locales := ["de", "en", "es", "fr", "it", "ja", "ko", "pl", "pt", "ru", "tr", "zh", "zh_TW"]
	for locale in locales:
		var source: Dictionary = de if locale == "de" else en
		var t := Translation.new()
		t.locale = locale
		for key in source:
			t.add_message(key, source[key])
		TranslationServer.add_translation(t)
