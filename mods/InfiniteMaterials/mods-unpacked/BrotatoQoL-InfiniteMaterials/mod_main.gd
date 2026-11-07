extends Node

const MOD_ID := "BrotatoQoL-InfiniteMaterials"
const LOG_NAME := "BrotatoQoL-InfiniteMaterials:Main"
const META_KEY := "brotatoqol_infinite_materials_enabled"

var _ext_dir := ""
var _late_extensions_installed := false


func _init() -> void:
	_ext_dir = ModLoaderMod.get_unpacked_dir().plus_file(MOD_ID).plus_file("extensions")
	# Off by default every time the game starts
	Engine.set_meta(META_KEY, false)
	_add_translations()
	ModLoaderLog.info("Loaded", LOG_NAME)


# The shop scripts depend on autoloads that don't exist yet while mods are
# being loaded. So the extensions are installed on the first processed frame,
# when the game is fully running (the shop is only opened much later).
func _ready() -> void:
	set_process(true)


func _process(_delta: float) -> void:
	if _late_extensions_installed:
		set_process(false)
		return
	_late_extensions_installed = true
	set_process(false)
	ModLoaderLog.info("Installing shop extensions...", LOG_NAME)
	ModLoaderMod.install_script_extension(_ext_dir.plus_file("ui/menus/shop/shop_items_container.gd"))
	ModLoaderMod.install_script_extension(_ext_dir.plus_file("ui/menus/shop/shop.gd"))
	ModLoaderLog.info("Shop extensions installed", LOG_NAME)


func _add_translations() -> void:
	var de := {
		"MOD_INFMAT_TOOLTIP": "Unendlich Materialien (Neu würfeln und Kaufen kostenlos)",
	}
	var en := {
		"MOD_INFMAT_TOOLTIP": "Infinite Materials (free rerolls and purchases)",
	}
	var locales := ["de", "en", "es", "fr", "it", "ja", "ko", "pl", "pt", "ru", "tr", "zh", "zh_TW"]
	for locale in locales:
		var source: Dictionary = de if locale == "de" else en
		var t := Translation.new()
		t.locale = locale
		for key in source:
			t.add_message(key, source[key])
		TranslationServer.add_translation(t)
