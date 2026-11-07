extends "res://entities/units/player/player.gd"

# Moonwalker character:
#  - movement input is reversed
#  - the sprite faces against the movement direction (gliding backwards)
#  - the body leans forward more and more during the wave, pivoting at the
#    feet (the game doesn't animate the rotation of the "Animation" node;
#    its position is animated, so the pivot offset is re-applied every frame)

const BROTATOQOL_MW_ID := "character_brotatoqol_moonwalker"
const BROTATOQOL_MW_MAX_LEAN := 40.0          # degrees at the end of the wave
const BROTATOQOL_MW_PIVOT := Vector2(0, 38)   # feet, in "Animation" node space
const BROTATOQOL_MW_TURN_SPEED := 10.0

var _brotatoqol_mw_checked := false
var _brotatoqol_mw_active := false
var _brotatoqol_mw_facing := 1.0
var _brotatoqol_mw_angle := 0.0
var _brotatoqol_mw_last_written = null
var _brotatoqol_mw_last_base := Vector2.ZERO


func _brotatoqol_mw_is_active() -> bool:
	if not _brotatoqol_mw_checked:
		_brotatoqol_mw_checked = true
		if player_index >= 0 and player_index < RunData.get_player_count():
			var character = RunData.get_player_character(player_index)
			_brotatoqol_mw_active = character != null and character.my_id == BROTATOQOL_MW_ID
	return _brotatoqol_mw_active


func get_movement() -> Vector2:
	var movement: Vector2 = .get_movement()
	if _brotatoqol_mw_is_active() and not _move_locked:
		return -movement
	return movement


func update_animation(movement: Vector2) -> void:
	if not _brotatoqol_mw_is_active():
		.update_animation(movement)
		return
	# face against the movement direction
	if movement.x > 0:
		_brotatoqol_mw_facing = -1.0
	elif movement.x < 0:
		_brotatoqol_mw_facing = 1.0
	.update_animation(Vector2(-movement.x, movement.y))


func _process(delta: float) -> void:
	if not _brotatoqol_mw_is_active() or dead:
		return
	var target: float = BROTATOQOL_MW_MAX_LEAN * _brotatoqol_mw_wave_progress() * _brotatoqol_mw_facing
	_brotatoqol_mw_angle = lerp(_brotatoqol_mw_angle, target, clamp(delta * BROTATOQOL_MW_TURN_SPEED, 0.0, 1.0))
	# after all _process calls (incl. the AnimationPlayer writing "Animation:position")
	call_deferred("_brotatoqol_mw_apply_lean")


func _brotatoqol_mw_wave_progress() -> float:
	var scene = get_tree().current_scene
	if scene == null:
		return 0.0
	var timer = scene.get("_wave_timer")
	if timer == null or not is_instance_valid(timer) or timer.wait_time <= 0.0:
		return 0.0
	if timer.is_stopped():
		return 1.0 if scene.get("_cleaning_up") == true else 0.0
	return clamp(1.0 - timer.time_left / timer.wait_time, 0.0, 1.0)


func _brotatoqol_mw_apply_lean() -> void:
	var anim = get_node_or_null("Animation")
	if anim == null:
		return
	var theta: float = deg2rad(_brotatoqol_mw_angle)
	anim.rotation = theta
	# keep the feet in place: rotate around BROTATOQOL_MW_PIVOT instead of the origin
	var offset: Vector2 = BROTATOQOL_MW_PIVOT - BROTATOQOL_MW_PIVOT.rotated(theta)
	var pos: Vector2 = anim.position
	var base: Vector2 = pos
	if _brotatoqol_mw_last_written != null and pos.is_equal_approx(_brotatoqol_mw_last_written):
		base = _brotatoqol_mw_last_base      # the animation didn't write a new value
	anim.position = base + offset
	_brotatoqol_mw_last_base = base
	_brotatoqol_mw_last_written = anim.position
	# the shadow stays flat on the ground
	for shadow_name in ["Shadow", "Highlight"]:
		var shadow = anim.get_node_or_null(shadow_name)
		if shadow != null:
			shadow.rotation = -theta
