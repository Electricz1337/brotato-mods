extends "res://ui/menus/shop/item_popup.gd"

# Shop item popup: owned items get the "Sell (+X)" / "Cancel" buttons that
# weapons already have. Everywhere else (crate screen, pause menu, ...) the
# popup behaves exactly as before.

const BROTATOQOL_SELL_LOG := "BrotatoQoL-SellItems:Popup"
const BROTATOQOL_SELL_LIMIT_META := "brotatoqol_sell_limit"      # -1 = unlimited
const BROTATOQOL_SELL_COUNTER_KEY := "brotatoqol_items_sold"     # stored in the player's effects -> saved with the run


func should_show_buttons(item_data: ItemParentData, focused: bool) -> bool:
	if _brotatoqol_sell_can_sell(item_data):
		return buttons_enabled and (not RunData.is_coop_run or focused)
	return .should_show_buttons(item_data, focused)


var _brotatoqol_sell_orig_text = null


func _update_button_visibilities() -> void:
	if _brotatoqol_sell_orig_text == null and _discard_button != null:
		_brotatoqol_sell_orig_text = _discard_button.text
	if not _brotatoqol_sell_can_sell(_item_data):
		# weapons etc.: undo anything the sell mode changed on the button
		if _discard_button != null:
			_discard_button.disabled = false
			_discard_button.text = _brotatoqol_sell_orig_text
		._update_button_visibilities()
		return

	# Items: only "Sell" and "Cancel" (the base version would call weapon-only
	# functions like RunData.can_combine for them)
	_cancel_pending_upgrade()
	var can_show: bool = should_show_buttons(_item_data, _focused)
	for button in [_combine_button, _upgrade_button]:
		if button != null:
			button.hide()
			button.focus_mode = FOCUS_NONE
	for button in [_discard_button, _cancel_button]:
		button.visible = can_show
		button.focus_mode = FOCUS_ALL if (can_show and _focused) else FOCUS_NONE
	if not can_show:
		return

	var value := _brotatoqol_sell_value(_item_data)
	var limit := _brotatoqol_sell_limit()
	var label: String = tr("BROTATOQOL_SELL")
	_discard_button.disabled = false
	if limit >= 0:
		var counter := "%d/%d" % [_brotatoqol_sell_count(), limit]
		if _brotatoqol_sell_limit_reached():
			_discard_button.disabled = true
			if _recycle_value_display != null:
				_recycle_value_display.hide()
			_discard_button.text = tr("BROTATOQOL_SELL_LIMIT_REACHED") + " (" + counter + ")"
			return
		label += " " + counter
	if _recycle_value_display != null:
		_discard_button.text = _brotatoqol_sell_orig_text
		_recycle_value_display.show()
		_recycle_value_display.update_button(label, value, 0)
	else:
		_discard_button.text = label + " (+" + str(value) + ")"


func _recycle() -> void:
	if not _brotatoqol_sell_can_sell(_item_data):
		._recycle()
		return
	if _brotatoqol_sell_limit_reached():
		return
	var item = _item_data
	_focused = false
	_brotatoqol_sell_item(item)


# ---------------------------------------------------------------- limit

func _brotatoqol_sell_limit() -> int:
	return int(Engine.get_meta(BROTATOQOL_SELL_LIMIT_META)) if Engine.has_meta(BROTATOQOL_SELL_LIMIT_META) else -1


func _brotatoqol_sell_counter_hash() -> int:
	return Keys.generate_hash(BROTATOQOL_SELL_COUNTER_KEY)


# Items sold in this run (kept in the player's effects, which the game saves
# with the run and resets for a new run)
func _brotatoqol_sell_count() -> int:
	var effects: Dictionary = RunData.players_data[player_index].effects
	return int(effects.get(_brotatoqol_sell_counter_hash(), 0))


func _brotatoqol_sell_add_count() -> void:
	var effects: Dictionary = RunData.players_data[player_index].effects
	effects[_brotatoqol_sell_counter_hash()] = _brotatoqol_sell_count() + 1


func _brotatoqol_sell_limit_reached() -> bool:
	var limit := _brotatoqol_sell_limit()
	return limit >= 0 and _brotatoqol_sell_count() >= limit


# ---------------------------------------------------------------- selling

func _brotatoqol_sell_get_shop():
	var scene = get_tree().current_scene
	if scene == null or not scene.has_method("_get_gear_container") or not scene.has_method("_get_shop_items_container"):
		return null
	if not "shop" in str(scene.filename):
		return null
	return scene


func _brotatoqol_sell_can_sell(item_data) -> bool:
	if not (item_data is ItemData) or item_data is CharacterData:
		return false
	if not _is_inventory_element:
		return false
	if _brotatoqol_sell_get_shop() == null:
		return false
	# must really be one of the player's items
	for owned in RunData.get_player_items(player_index):
		if owned == item_data or owned.my_id_hash == item_data.my_id_hash:
			return true
	return false


func _brotatoqol_sell_value(item_data) -> int:
	return ItemService.get_recycling_value(RunData.current_wave, item_data.value, player_index, false)


func _brotatoqol_sell_item(item_data) -> void:
	var shop = _brotatoqol_sell_get_shop()
	if shop == null:
		return
	var value := _brotatoqol_sell_value(item_data)

	shop._popup_manager.reset_focus(player_index)
	var gear = shop._get_gear_container(player_index)
	if gear != null:
		gear.items_container._elements.remove_element(item_data, 1, false)

	RunData.remove_item(item_data, player_index, false, false)
	RunData.add_gold(value, player_index)
	RunData.update_recycling_tracking_value(item_data, player_index)
	_brotatoqol_sell_add_count()
	ModLoaderLog.info("Sold %s for %s materials (%s sold this run)" % [item_data.my_id, value, _brotatoqol_sell_count()], BROTATOQOL_SELL_LOG)

	shop._update_stats(player_index)
	var shop_items = shop._get_shop_items_container(player_index)
	if shop_items != null:
		shop_items.reload_shop_items()
	var reroll_button = shop._get_reroll_button(player_index)
	if reroll_button != null and reroll_button.has_method("set_color_from_currency"):
		reroll_button.set_color_from_currency(RunData.get_player_gold(player_index))
	if shop.get("recycle_sounds") != null and not shop.recycle_sounds.empty():
		SoundManager.play(Utils.get_rand_element(shop.recycle_sounds), 0, 0.1, true)

	# Same clean-up the shop does after recycling a weapon
	var block_background = shop.get("_block_background")
	if block_background != null:
		block_background.hide()
	var focused_shop_item = shop.get("_focused_shop_item")
	if focused_shop_item is Array and focused_shop_item.size() > player_index and focused_shop_item[player_index] != null:
		focused_shop_item[player_index]._can_be_selected()
	if gear != null and gear.items_container._elements.get_child_count() > 0 and Input.get_mouse_mode() == Input.MOUSE_MODE_HIDDEN:
		var first = gear.items_container._elements.get_child(0)
		if first is Control:
			first.call_deferred("grab_focus")
