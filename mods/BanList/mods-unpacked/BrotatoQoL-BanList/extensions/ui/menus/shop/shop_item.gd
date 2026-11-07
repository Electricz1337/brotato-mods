extends "res://ui/menus/shop/shop_item.gd"

# Shop card: the game's "Ban" button is always available for items and
# weapons (no challenge unlock, no ban tokens). With a ban limit set in
# ModOptions it is disabled while the limit is reached.



func _brotatoqol_ban_data():
	return load(ModLoaderMod.get_unpacked_dir().plus_file("BrotatoQoL-BanList").plus_file("ban_data.gd"))


func manage_ban_button_visibility() -> void:
	if item_data == null:
		return
	# Fisherman needs his bait - the game hides the button there as well
	if item_data.my_id_hash == Keys.item_bait_hash and RunData.players_data[player_index].current_character.my_id_hash == Keys.character_fisherman_hash:
		_ban_button.disable()
		_ban_button.hide()
		return
	var data = _brotatoqol_ban_data()
	if not RunData.is_coop_run:
		_ban_button.show()
	if data.get_limit() >= 0:
		if data.limit_reached(player_index):
			_ban_button.text = tr("BROTATOQOL_BAN_LIMIT_REACHED") + " (" + data.count_text(player_index) + ")"
			_ban_button.disable()
			return
		_ban_button.text = tr("BROTATOQOL_BAN") + " (" + data.count_text(player_index) + ")"
	else:
		_ban_button.text = tr("BROTATOQOL_BAN")
	_ban_button.activate()


func ban_item() -> void:
	if not _brotatoqol_ban_data().ban(item_data, player_index):
		return
	deactivate()
	emit_signal("ban_update_remaining_token")
