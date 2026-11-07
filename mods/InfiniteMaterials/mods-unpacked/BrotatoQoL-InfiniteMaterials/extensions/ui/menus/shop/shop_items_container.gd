extends "res://ui/menus/shop/shop_items_container.gd"

# While the toggle is on, buying or dismantling an item costs nothing.
# Trick: for the duration of the vanilla call the player gets exactly the
# price added, the vanilla code checks and removes it, and afterwards the
# material count is put back to what it was. Items that scale with
# materials therefore never see an inflated value.

const INFMAT_META_KEY := "brotatoqol_infinite_materials_enabled"
const INFMAT_AMOUNT := 999999


func _infmat_is_enabled() -> bool:
	return Engine.has_meta(INFMAT_META_KEY) and Engine.get_meta(INFMAT_META_KEY) == true


func on_shop_item_buy_button_pressed(shop_item: ShopItem) -> void:
	if not _infmat_is_enabled():
		.on_shop_item_buy_button_pressed(shop_item)
		return
	var player_data = RunData.players_data[player_index]
	var gold_before: int = player_data.gold
	player_data.gold += shop_item.value
	.on_shop_item_buy_button_pressed(shop_item)
	player_data.gold = gold_before
	RunData.emit_signal("gold_changed", gold_before, player_index)


func on_shop_item_dismantle_button_pressed(shop_item: ShopItem) -> void:
	if not _infmat_is_enabled():
		.on_shop_item_dismantle_button_pressed(shop_item)
		return
	var player_data = RunData.players_data[player_index]
	var gold_before: int = player_data.gold
	player_data.gold += shop_item.get_dismantle_price()
	.on_shop_item_dismantle_button_pressed(shop_item)
	player_data.gold = gold_before
	RunData.emit_signal("gold_changed", gold_before, player_index)


func update_buttons_color() -> void:
	.update_buttons_color()
	if not _infmat_is_enabled():
		return
	# Show every price as affordable
	for item in _shop_items:
		if item._button != null:
			item._button.set_color_from_currency(INFMAT_AMOUNT)
		if item.get("_dismantle_button") != null:
			item._dismantle_button.set_color_from_currency(INFMAT_AMOUNT)
