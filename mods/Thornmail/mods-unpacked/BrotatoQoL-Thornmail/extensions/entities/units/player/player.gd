extends "res://entities/units/player/player.gd"

# Thornmail: when the player gets hit by an enemy (melee or projectile) and
# doesn't dodge, the attacker takes the incoming damage (before armor)
# x multiplier (ModOptions) x number of Thornmails back.

const BROTATOQOL_TM_ITEM_ID := "item_brotatoqol_thornmail"
const BROTATOQOL_TM_MULT_META := "brotatoqol_thornmail_multiplier"

var _brotatoqol_tm_hash := 0
var _brotatoqol_tm_args = null


func take_damage(value: int, args: TakeDamageArgs) -> Array:
	var result: Array = .take_damage(value, args)
	_brotatoqol_tm_reflect(value, args, result)
	return result


func _brotatoqol_tm_reflect(value: int, args, result: Array) -> void:
	if dead or value <= 0 or args == null or result.size() < 3:
		return
	if result[2] or int(result[0]) <= 0:      # dodged / invincible / no damage
		return
	if _brotatoqol_tm_hash == 0:
		_brotatoqol_tm_hash = Keys.generate_hash(BROTATOQOL_TM_ITEM_ID)
	var count: int = RunData.get_nb_item(_brotatoqol_tm_hash, player_index)
	if count <= 0:
		return

	var source = args.from
	if (source == null or not is_instance_valid(source)) and args.hitbox != null and is_instance_valid(args.hitbox):
		source = args.hitbox.from
	if source == null or not is_instance_valid(source) or not (source is Enemy) or source.dead:
		return

	var multiplier := 1.0
	if Engine.has_meta(BROTATOQOL_TM_MULT_META):
		multiplier = float(Engine.get_meta(BROTATOQOL_TM_MULT_META))
	var reflected := int(max(1.0, round(value * multiplier * count)))

	if _brotatoqol_tm_args == null:
		_brotatoqol_tm_args = TakeDamageArgs.new(player_index)
	else:
		_brotatoqol_tm_args._init(player_index)
	var dealt = source.take_damage(reflected, _brotatoqol_tm_args)

	var tracked: Dictionary = RunData.tracked_item_effects[player_index]
	if not tracked.has(_brotatoqol_tm_hash):
		tracked[_brotatoqol_tm_hash] = 0
	if dealt is Array and dealt.size() > 1:
		RunData.add_tracked_value(player_index, _brotatoqol_tm_hash, dealt[1])
