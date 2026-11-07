extends "res://ui/menus/ingame/ingame_main_menu.gd"

# Pause menu: adds a "Retry wave" button below "Resume".
# Press once -> asks for confirmation, press again -> wave restarts
# from the state at its beginning. Retries are not counted.

const MOD_TEXT := "MOD_RETRY_WAVE"
const MOD_TEXT_CONFIRM := "MOD_RETRY_WAVE_CONFIRM"

var _mod_retry_button: Button = null
var _mod_retry_armed := false
var _mod_retry_done := false


func _ready() -> void:
	var restart_button = get_node_or_null("%RestartButton")
	if restart_button == null:
		return

	# Copy the vanilla button so it gets the same look, sounds and theme,
	# but without its signal connections.
	_mod_retry_button = restart_button.duplicate(DUPLICATE_GROUPS | DUPLICATE_SCRIPTS)
	_mod_retry_button.name = "ModRetryWaveButton"
	_mod_retry_button.unique_name_in_owner = false
	_mod_retry_button.text = MOD_TEXT

	var parent = restart_button.get_parent()
	parent.add_child(_mod_retry_button)
	parent.move_child(_mod_retry_button, restart_button.get_index())
	_mod_retry_button.connect("pressed", self, "_on_ModRetryWaveButton_pressed")
	_buttons_array.push_back(_mod_retry_button)

	_mod_update_retry_button()


func init(p_player_index: = 0) -> void:
	.init(p_player_index)
	_mod_retry_armed = false
	_mod_update_retry_button()


func _mod_can_retry() -> bool:
	# Only during a wave (the same menu is also used in the shop)
	return (
		get_tree().current_scene is Main
		and RunData.current_wave > 0
		and not RunData.start_wave_state.empty()
	)


func _mod_update_retry_button() -> void:
	if _mod_retry_button == null:
		return
	_mod_retry_button.visible = _mod_can_retry()
	_mod_retry_button.text = MOD_TEXT_CONFIRM if _mod_retry_armed else MOD_TEXT


func _on_ModRetryWaveButton_pressed() -> void:
	if _mod_retry_done or not _mod_can_retry():
		return

	if not _mod_retry_armed:
		_mod_retry_armed = true
		_mod_update_retry_button()
		return

	_mod_retry_done = true
	RunData.reset_to_start_wave_state()
	LinkedStats.reset()
	get_tree().paused = false
	var _error = get_tree().change_scene(MenuData.game_scene)
