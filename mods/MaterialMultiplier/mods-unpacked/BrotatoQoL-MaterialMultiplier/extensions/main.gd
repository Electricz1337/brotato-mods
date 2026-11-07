extends "res://main.gd"

# MaterialMultiplier: after the game has handled a material pickup, add the
# materials it gave each player (multiplier - 1) more times.


func on_gold_picked_up(gold: Node, player_index: int) -> void:
	var multiplier: int = int(Engine.get_meta("brotatoqol_material_multiplier")) if Engine.has_meta("brotatoqol_material_multiplier") else 1
	if multiplier <= 1 or player_index < 0 or gold.already_picked_up:
		.on_gold_picked_up(gold, player_index)
		return

	var count: int = RunData.get_player_count()
	var before := []
	for i in count:
		before.push_back(RunData.get_player_gold(i))

	.on_gold_picked_up(gold, player_index)

	var multiply_xp: bool = Engine.has_meta("brotatoqol_material_multiplier_xp") and bool(Engine.get_meta("brotatoqol_material_multiplier_xp"))
	for i in count:
		var gained: int = RunData.get_player_gold(i) - before[i]
		if gained <= 0:
			continue
		var extra: int = gained * (multiplier - 1)
		RunData.add_gold(extra, i)
		if multiply_xp:
			RunData.add_xp(extra, i)
