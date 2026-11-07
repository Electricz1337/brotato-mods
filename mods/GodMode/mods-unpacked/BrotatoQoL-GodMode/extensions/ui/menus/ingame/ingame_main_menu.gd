extends "res://ui/menus/ingame/ingame_main_menu.gd"

# Pause menu: adds a "God Mode: ON/OFF" toggle button above "Options".

const GODMODE_META_KEY := "brotatoqol_godmode_enabled"
const GODMODE_TEXT_ON := "MOD_GODMODE_ON"
const GODMODE_TEXT_OFF := "MOD_GODMODE_OFF"

var _godmode_button: Button = null


func _ready() -> void:
	var template = get_node_or_null("%OptionsButton")
	if template == null:
		return

	# Copy a vanilla button for the same look and sounds (without its signals)
	_godmode_button = template.duplicate(DUPLICATE_GROUPS | DUPLICATE_SCRIPTS)
	_godmode_button.name = "ModGodModeButton"
	_godmode_button.unique_name_in_owner = false

	var parent = template.get_parent()
	parent.add_child(_godmode_button)
	parent.move_child(_godmode_button, template.get_index())
	_godmode_button.connect("pressed", self, "_on_ModGodModeButton_pressed")
	_buttons_array.push_back(_godmode_button)

	_godmode_update_button()


func init(p_player_index: = 0) -> void:
	.init(p_player_index)
	_godmode_update_button()


func _godmode_is_enabled() -> bool:
	return Engine.has_meta(GODMODE_META_KEY) and Engine.get_meta(GODMODE_META_KEY) == true


func _godmode_update_button() -> void:
	if _godmode_button == null:
		return
	_godmode_button.text = GODMODE_TEXT_ON if _godmode_is_enabled() else GODMODE_TEXT_OFF


func _on_ModGodModeButton_pressed() -> void:
	Engine.set_meta(GODMODE_META_KEY, not _godmode_is_enabled())
	_godmode_update_button()
