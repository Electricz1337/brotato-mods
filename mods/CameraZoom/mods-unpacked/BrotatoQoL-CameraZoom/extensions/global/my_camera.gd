extends "res://global/my_camera.gd"

# Applies the CameraZoom factor to the game camera.
#
# Single player: the game's camera always uses zoom 1.0 (MIN_ZOOM). The mod
#   uses MIN_ZOOM * factor instead, and the game's own position logic
#   ("follow the player, stay inside the map, center small maps") runs with
#   that real zoom - so the view never goes past the map edges.
# Co-op: the game zooms dynamically to keep all players visible. Its logic
#   runs unchanged with its own zoom; the factor is multiplied on top.
#
# The factor changes smoothly, so moving the slider in the pause menu looks nice.

const BROTATOQOL_ZOOM_META := "brotatoqol_camera_zoom_factor"
const BROTATOQOL_ZOOM_SMOOTH := 8.0

var _brotatoqol_base_zoom = null
var _brotatoqol_factor := -1.0


func _brotatoqol_target_factor() -> float:
	return float(Engine.get_meta(BROTATOQOL_ZOOM_META)) if Engine.has_meta(BROTATOQOL_ZOOM_META) else 1.0


func _process_internal(delta: float):
	if RunData.is_coop_run:
		# game logic with its own zoom, factor on top
		if _brotatoqol_base_zoom != null:
			zoom = _brotatoqol_base_zoom
		._process_internal(delta)
		_brotatoqol_base_zoom = zoom
		zoom = _brotatoqol_scaled(_brotatoqol_base_zoom.x, delta)
	else:
		._process_internal(delta)


# Single player only (co-op is handled in _process_internal)
func _adjust_zoom(alive_targets: Array, delta: float) -> void:
	if RunData.is_coop_run:
		._adjust_zoom(alive_targets, delta)
		return
	zoom = _brotatoqol_scaled(MIN_ZOOM, delta)


func _brotatoqol_scaled(base: float, delta: float) -> Vector2:
	var target := _brotatoqol_target_factor()
	if _brotatoqol_factor < 0.0 or _first_update:
		_brotatoqol_factor = target
	else:
		_brotatoqol_factor = lerp(_brotatoqol_factor, target, clamp(delta * BROTATOQOL_ZOOM_SMOOTH, 0.0, 1.0))
		if abs(_brotatoqol_factor - target) < 0.001:
			_brotatoqol_factor = target
	var z: float = base * _brotatoqol_factor
	# zooming out: stop once the whole map fits on screen
	if _brotatoqol_factor > 1.0 and _max_zoom > 0.0:
		z = min(z, max(base, _max_zoom))
	return Vector2(z, z)
