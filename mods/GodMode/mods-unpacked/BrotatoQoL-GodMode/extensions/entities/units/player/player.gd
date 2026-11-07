extends "res://entities/units/player/player.gd"

# God mode: while enabled, every incoming hit is ignored.
# Healing "hits" (e.g. from healing turrets) still go through.

const GODMODE_META_KEY := "brotatoqol_godmode_enabled"


func take_damage(value: int, args: TakeDamageArgs) -> Array:
	if _godmode_is_enabled():
		var hitbox = args.hitbox if args else null
		if not (hitbox and hitbox.is_healing):
			return [0, 0, false]
	return .take_damage(value, args)


func _godmode_is_enabled() -> bool:
	return Engine.has_meta(GODMODE_META_KEY) and Engine.get_meta(GODMODE_META_KEY) == true
