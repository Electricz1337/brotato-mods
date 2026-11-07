extends Node

# CameraZoom
#
# The game's camera (res://global/my_camera.gd) calculates its own zoom every
# frame (single player: 1.0). This mod multiplies the result with a factor:
#   view size 100% = vanilla, 150% = you see 1.5x as much (zoomed out),
#   70% = zoomed in.
# The game keeps calculating with its own value, the factor is only applied
# on top. Zooming out stops once the whole map is visible.
#
# Settings (with "Oudstand-ModOptions", Options -> Mods):
#   - view size slider (50% - 250%)
#   - on/off toggle
# Changes apply immediately (also from the pause menu) with a smooth transition.
#
# The camera extension is installed on the first frame, because the camera
# script needs the game's autoloads (the wave scene is only loaded later).

const MOD_ID := "BrotatoQoL-CameraZoom"
const LOG_NAME := "BrotatoQoL-CameraZoom:Main"
const MOD_OPTIONS_PATH := "/root/ModLoader/Oudstand-ModOptions/ModOptions"
const MOD_OPTIONS_RETRIES := 10
const OPTION_ENABLED := "enabled"
const OPTION_VIEW := "view_size"
const META_FACTOR := "brotatoqol_camera_zoom_factor"
const DEFAULT_VIEW := 1.0
const MIN_VIEW := 0.5
const MAX_VIEW := 2.5

var _ext_dir := ""
var _installed := false
var _mod_options = null
var _mod_options_tries := 0
var _enabled := true
var _view := DEFAULT_VIEW


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
	ModLoaderMod.install_script_extension(_ext_dir.plus_file("global/my_camera.gd"))
	ModLoaderLog.info("Camera extension installed", LOG_NAME)


# The camera reads the factor from Engine meta every frame
func _publish() -> void:
	var factor := _view if _enabled else 1.0
	Engine.set_meta(META_FACTOR, clamp(factor, MIN_VIEW, MAX_VIEW))


# ---------------------------------------------------------------- ModOptions

func _register_mod_options() -> void:
	_mod_options = get_node_or_null(MOD_OPTIONS_PATH)
	if _mod_options == null:
		_mod_options_tries += 1
		if _mod_options_tries < MOD_OPTIONS_RETRIES:
			var _t = get_tree().create_timer(0.5).connect("timeout", self, "_register_mod_options")
		else:
			ModLoaderLog.info("ModOptions not installed - using view size %d%%" % int(DEFAULT_VIEW * 100), LOG_NAME)
		return
	if not _mod_options.get_registered_mods().has(MOD_ID):
		_mod_options.register_mod_options(MOD_ID, {
			"tab_title": "Camera Zoom",
			"options": [
				{
					"type": "toggle",
					"id": OPTION_ENABLED,
					"label": "BROTATOQOL_ZOOM_OPTION_ENABLED",
					"default": true
				},
				{
					"type": "slider",
					"id": OPTION_VIEW,
					"label": "BROTATOQOL_ZOOM_OPTION_VIEW",
					"default": DEFAULT_VIEW,
					"min": MIN_VIEW,
					"max": MAX_VIEW,
					"step": 0.05
				}
			],
			"info_text": "BROTATOQOL_ZOOM_OPTION_INFO"
		})
	_enabled = bool(_mod_options.get_value(MOD_ID, OPTION_ENABLED))
	_view = float(_mod_options.get_value(MOD_ID, OPTION_VIEW))
	_publish()
	if not _mod_options.is_connected("config_changed", self, "_on_config_changed"):
		_mod_options.connect("config_changed", self, "_on_config_changed")
	ModLoaderLog.info("Registered with ModOptions (enabled=%s, view=%d%%)" % [_enabled, int(_view * 100)], LOG_NAME)


func _on_config_changed(mod_id: String, option_id: String, new_value) -> void:
	if mod_id != MOD_ID:
		return
	if option_id == OPTION_ENABLED:
		_enabled = bool(new_value)
	elif option_id == OPTION_VIEW:
		_view = float(new_value)
	else:
		return
	_publish()


# ---------------------------------------------------------------- texts

func _add_translations() -> void:
	var de := {
		"BROTATOQOL_ZOOM_OPTION_ENABLED": "Kamera-Zoom aktiv",
		"BROTATOQOL_ZOOM_OPTION_VIEW": "Sichtweite",
		"BROTATOQOL_ZOOM_OPTION_INFO": "100% = Originalansicht. Mehr als 100% zoomt heraus (du siehst mehr von der Karte), weniger als 100% zoomt hinein. Herauszoomen endet, sobald die ganze Karte sichtbar ist.",
	}
	var en := {
		"BROTATOQOL_ZOOM_OPTION_ENABLED": "Camera zoom enabled",
		"BROTATOQOL_ZOOM_OPTION_VIEW": "View size",
		"BROTATOQOL_ZOOM_OPTION_INFO": "100% = original view. Above 100% zooms out (you see more of the map), below 100% zooms in. Zooming out stops once the whole map is visible.",
	}
	var locales := ["de", "en", "es", "fr", "it", "ja", "ko", "pl", "pt", "ru", "tr", "zh", "zh_TW"]
	for locale in locales:
		var source: Dictionary = de if locale == "de" else en
		var t := Translation.new()
		t.locale = locale
		for key in source:
			t.add_message(key, source[key])
		TranslationServer.add_translation(t)
