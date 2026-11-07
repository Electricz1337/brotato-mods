extends Node

const MOD_ID := "BrotatoQoL-GodMode"
const LOG_NAME := "BrotatoQoL-GodMode:Main"
const META_KEY := "brotatoqol_godmode_enabled"


func _init() -> void:
	var ext_dir := ModLoaderMod.get_unpacked_dir().plus_file(MOD_ID).plus_file("extensions")

	# Off by default every time the game starts
	Engine.set_meta(META_KEY, false)

	# Player: ignore damage while god mode is on
	ModLoaderMod.install_script_extension(ext_dir.plus_file("entities/units/player/player.gd"))
	# Pause menu: toggle button
	ModLoaderMod.install_script_extension(ext_dir.plus_file("ui/menus/ingame/ingame_main_menu.gd"))

	_add_translations()
	ModLoaderLog.info("Loaded", LOG_NAME)


func _add_translations() -> void:
	var de := {
		"MOD_GODMODE_ON": "God Mode: AN",
		"MOD_GODMODE_OFF": "God Mode: AUS",
	}
	var en := {
		"MOD_GODMODE_ON": "God Mode: ON",
		"MOD_GODMODE_OFF": "God Mode: OFF",
	}
	var locales := ["de", "en", "es", "fr", "it", "ja", "ko", "pl", "pt", "ru", "tr", "zh", "zh_TW"]
	for locale in locales:
		var source: Dictionary = de if locale == "de" else en
		var t := Translation.new()
		t.locale = locale
		for key in source:
			t.add_message(key, source[key])
		TranslationServer.add_translation(t)
