extends Node

# CrateUpgrade
#
# At the end of a wave every collected crate shows its item with
# "Take" / "Recycle". This mod adds a third button: gamble the item for one
# of the next rarity.
#
#   Common (grey)     -> Uncommon (blue)     50%
#   Uncommon (blue)   -> Rare (purple)       25%
#   Rare (purple)     -> Legendary (red)     10%
#
# Success: a random item of the next rarity replaces it (can be upgraded
# again). Failure: the item is lost (no materials).
#
# The extension is installed on the first frame, because the extended game
# script needs the game's autoloads (the screen is only opened much later).

const MOD_ID := "BrotatoQoL-CrateUpgrade"
const LOG_NAME := "BrotatoQoL-CrateUpgrade:Main"

var _ext_dir := ""
var _installed := false


func _init() -> void:
	_ext_dir = ModLoaderMod.get_unpacked_dir().plus_file(MOD_ID).plus_file("extensions")
	_add_translations()
	ModLoaderLog.info("Loaded", LOG_NAME)


func _ready() -> void:
	set_process(true)


func _process(_delta: float) -> void:
	set_process(false)
	if _installed:
		return
	_installed = true
	ModLoaderMod.install_script_extension(_ext_dir.plus_file("ui/menus/ingame/upgrades_ui_player_container.gd"))
	ModLoaderLog.info("Crate screen extension installed", LOG_NAME)


func _add_translations() -> void:
	var de := {
		"BROTATOQOL_CU_TIER_1": "Blau",
		"BROTATOQOL_CU_TIER_2": "Lila",
		"BROTATOQOL_CU_TIER_3": "Rot",
		"BROTATOQOL_CU_BUTTON": "Upgrade auf {tier} ({chance}%)",
		"BROTATOQOL_CU_HINT": "Fehlschlag: Item geht verloren",
		"BROTATOQOL_CU_SUCCESS": "Upgrade erfolgreich!",
		"BROTATOQOL_CU_FAIL": "Fehlgeschlagen - Item verloren!",
		"BROTATOQOL_CU_ZONE_FAIL": "Verloren",
		"BROTATOQOL_CU_RESULT_WIN": "UPGRADE!",
		"BROTATOQOL_CU_RESULT_LOSE": "VERLOREN!",
	}
	var en := {
		"BROTATOQOL_CU_TIER_1": "Blue",
		"BROTATOQOL_CU_TIER_2": "Purple",
		"BROTATOQOL_CU_TIER_3": "Red",
		"BROTATOQOL_CU_BUTTON": "Upgrade to {tier} ({chance}%)",
		"BROTATOQOL_CU_HINT": "On failure the item is lost",
		"BROTATOQOL_CU_SUCCESS": "Upgrade successful!",
		"BROTATOQOL_CU_FAIL": "Failed - item lost!",
		"BROTATOQOL_CU_ZONE_FAIL": "Lost",
		"BROTATOQOL_CU_RESULT_WIN": "UPGRADE!",
		"BROTATOQOL_CU_RESULT_LOSE": "LOST!",
	}
	var locales := ["de", "en", "es", "fr", "it", "ja", "ko", "pl", "pt", "ru", "tr", "zh", "zh_TW"]
	for locale in locales:
		var source: Dictionary = de if locale == "de" else en
		var t := Translation.new()
		t.locale = locale
		for key in source:
			t.add_message(key, source[key])
		TranslationServer.add_translation(t)
