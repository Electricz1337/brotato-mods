extends Node

const MOD_ID := "BrotatoQoL-WaveRetry"
const LOG_NAME := "BrotatoQoL-WaveRetry:Main"

var mod_dir_path := ""


func _init() -> void:
	mod_dir_path = ModLoaderMod.get_unpacked_dir().plus_file(MOD_ID)
	var ext_dir := mod_dir_path.plus_file("extensions")

	# Death dialog: always offer the retry, and don't count it
	ModLoaderMod.install_script_extension(ext_dir.plus_file("ui/menus/ingame/retry_wave.gd"))
	# Pause menu: extra "Retry wave" button
	ModLoaderMod.install_script_extension(ext_dir.plus_file("ui/menus/ingame/ingame_main_menu.gd"))

	_add_translations()
	ModLoaderLog.info("Loaded", LOG_NAME)


func _add_translations() -> void:
	var de := {
		"MOD_RETRY_WAVE": "Welle neu starten",
		"MOD_RETRY_WAVE_CONFIRM": "Sicher? Nochmal drücken",
	}
	var en := {
		"MOD_RETRY_WAVE": "Retry wave",
		"MOD_RETRY_WAVE_CONFIRM": "Sure? Press again",
	}
	var locales := ["de", "en", "es", "fr", "it", "ja", "ko", "pl", "pt", "ru", "tr", "zh", "zh_TW"]
	for locale in locales:
		var source: Dictionary = de if locale == "de" else en
		var t := Translation.new()
		t.locale = locale
		for key in source:
			t.add_message(key, source[key])
		TranslationServer.add_translation(t)
