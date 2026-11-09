extends "res://ui/menus/ingame/pause_menu.gd"

# After "Resume" the game stays paused for a short countdown (3 - 2 - 1),
# so you can see what's going on before the action continues.
# Not used after the wave timer ran out (level-up / crate screens).

const BROTATOQOL_RC_SECONDS_META := "brotatoqol_resume_countdown_seconds"
const BROTATOQOL_RC_MOD_DIR := "BrotatoQoL-ResumeCountdown"


func unpause() -> void:
	.unpause()
	if get_tree().paused:
		return      # the game refused to unpause (e.g. controller applet)
	if not _brotatoqol_rc_wanted():
		return
	var overlay_script = load(ModLoaderMod.get_unpacked_dir().plus_file(BROTATOQOL_RC_MOD_DIR).plus_file("countdown_overlay.gd"))
	if overlay_script == null:
		return
	var host = get_tree().current_scene
	if host == null:
		return
	get_tree().paused = true
	var overlay = overlay_script.new()
	overlay.seconds = _brotatoqol_rc_seconds()
	overlay.pause_menu = self
	host.add_child(overlay)


func _brotatoqol_rc_seconds() -> int:
	if Engine.has_meta(BROTATOQOL_RC_SECONDS_META):
		return int(clamp(int(Engine.get_meta(BROTATOQOL_RC_SECONDS_META)), 1, 10))
	return 3


func _brotatoqol_rc_wanted() -> bool:
	var main = get_tree().current_scene
	if main == null:
		return false
	var wave_over = main.get("_end_wave_timer_timedout")
	if wave_over != null and wave_over:
		return false
	return true
