extends "res://ui/menus/ingame/retry_wave.gd"

# Death dialog: always show "Retry wave? Yes / No", regardless of the
# accessibility setting, and don't increase the retry counter.


func _ready() -> void:
	# The parent _ready() runs first and hides the retry options when the
	# setting is off, so we override that here.
	_ok_button.visible = false
	_retry_wave_container.visible = true
	_label_number_retry.visible = false


func show() -> void:
	visible = true
	_ok_button.visible = false
	_retry_wave_container.visible = true
	_label_number_retry.visible = false
	_confirm_button.grab_focus()
	_focus_emulator.set_process_input(true)


func _on_ConfirmButton_pressed() -> void:
	if confirm_button_pressed:
		return
	confirm_button_pressed = true

	RunData.reset_to_start_wave_state()
	# Vanilla does "RunData.retries += 1" here - we intentionally don't.
	LinkedStats.reset()
	_change_scene(MenuData.game_scene)
