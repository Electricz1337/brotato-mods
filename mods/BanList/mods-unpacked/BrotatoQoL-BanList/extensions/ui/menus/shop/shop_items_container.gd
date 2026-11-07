extends "res://ui/menus/shop/shop_items_container.gd"

# Ban without tokens: the game only bans while ban tokens are left.
# (An optional ban limit is checked in ban_data.gd.)


func on_shop_item_ban_button_pressed(shop_item: ShopItem) -> void:
	if shop_item == null or shop_item.item_data == null or not shop_item.active:
		return
	var player_run_data = RunData.players_data[player_index]
	if player_run_data.banned_items.has(shop_item.item_data.my_id_hash):
		return
	shop_item.ban_item()
	if shop_item.active:
		return          # limit reached, nothing was banned
	emit_signal("shop_item_banned", shop_item)
	SoundManager.play(load("res://ui/menus/ban_item.wav"), 0, 0.1, true)
	var ui = get_tree().current_scene.get_node_or_null("BrotatoQoLBanListUI") if get_tree().current_scene != null else null
	if ui != null and ui.has_method("update_button"):
		ui.update_button()
