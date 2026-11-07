extends "res://ui/menus/ingame/upgrades_ui_player_container.gd"

# Adds an "Upgrade to <rarity> (<chance>%)" button below "Take" on the
# end-of-wave crate screen.

const BROTATOQOL_CU_CHANCES := {0: 0.5, 1: 0.25, 2: 0.1}   # current tier -> chance
const BROTATOQOL_CU_TIER_COLORS := {
	1: Color(90.0 / 255, 190.0 / 255, 255.0 / 255),
	2: Color(173.0 / 255, 90.0 / 255, 255.0 / 255),
	3: Color(255.0 / 255, 59.0 / 255, 59.0 / 255),
}
const BROTATOQOL_CU_COLOR_SUCCESS := Color("76ff76")
const BROTATOQOL_CU_COLOR_FAIL := Color("ff5d5d")
const BROTATOQOL_CU_COLOR_HINT := Color(0.7, 0.7, 0.7)
const BROTATOQOL_CU_LOG := "BrotatoQoL-CrateUpgrade:Crate"

var _brotatoqol_cu_button: Button = null
var _brotatoqol_cu_label: Label = null
var _brotatoqol_cu_busy := false
var _brotatoqol_cu_failing := false


func _ready() -> void:
	_brotatoqol_cu_create_ui()


func _brotatoqol_cu_create_ui() -> void:
	if _take_button == null or _brotatoqol_cu_button != null:
		return
	var buttons_box = _take_button.get_parent()

	_brotatoqol_cu_button = Button.new()
	_brotatoqol_cu_button.name = "BrotatoQoLUpgradeButton"
	_brotatoqol_cu_button.rect_min_size = Vector2(0, _take_button.rect_size.y if _take_button.rect_size.y > 0 else 65)
	_brotatoqol_cu_button.focus_mode = Control.FOCUS_ALL
	var menu_button_script = load("res://ui/menus/global/my_menu_button.gd")
	if menu_button_script != null:
		_brotatoqol_cu_button.set_script(menu_button_script)
	_brotatoqol_cu_button.visible = false
	buttons_box.add_child(_brotatoqol_cu_button)
	buttons_box.move_child(_brotatoqol_cu_button, _take_button.get_index() + 1)
	var _e = _brotatoqol_cu_button.connect("pressed", self, "_brotatoqol_cu_on_upgrade_pressed")

	_brotatoqol_cu_label = Label.new()
	_brotatoqol_cu_label.name = "BrotatoQoLUpgradeHint"
	_brotatoqol_cu_label.align = Label.ALIGN_CENTER
	_brotatoqol_cu_label.visible = false
	var font = load("res://resources/fonts/actual/base/font_26_outline.tres")
	if font != null:
		_brotatoqol_cu_label.add_font_override("font", font)
	buttons_box.add_child(_brotatoqol_cu_label)
	buttons_box.move_child(_brotatoqol_cu_label, _brotatoqol_cu_button.get_index() + 1)


func show_item(item_data: ItemParentData) -> void:
	.show_item(item_data)
	_brotatoqol_cu_refresh()


# Keep all buttons blocked while the "failed" message is shown
func _on_ButtonDelayTimer_timeout() -> void:
	if _brotatoqol_cu_failing:
		return
	._on_ButtonDelayTimer_timeout()


# ---------------------------------------------------------------- button

func _brotatoqol_cu_can_upgrade(item_data) -> bool:
	if item_data == null or not BROTATOQOL_CU_CHANCES.has(item_data.tier):
		return false
	if item_data is WeaponData:
		var max_tier = RunData.get_player_effect(Keys.max_weapon_tier_hash, player_index)
		if max_tier <= item_data.tier:
			return false
	return true


func _brotatoqol_cu_refresh() -> void:
	if _brotatoqol_cu_button == null:
		_brotatoqol_cu_create_ui()
	if _brotatoqol_cu_button == null:
		return
	_brotatoqol_cu_busy = false
	_brotatoqol_cu_button.disabled = false
	var can_show := _brotatoqol_cu_can_upgrade(_item_data)
	_brotatoqol_cu_button.visible = can_show
	_brotatoqol_cu_label.visible = can_show
	if not can_show:
		return
	var next_tier: int = _item_data.tier + 1
	var chance := int(round(BROTATOQOL_CU_CHANCES[_item_data.tier] * 100.0))
	_brotatoqol_cu_button.text = tr("BROTATOQOL_CU_BUTTON").format({
		"tier": tr("BROTATOQOL_CU_TIER_%s" % next_tier),
		"chance": chance,
	})
	_brotatoqol_cu_button.add_color_override("font_color", BROTATOQOL_CU_TIER_COLORS[next_tier])
	_brotatoqol_cu_label.text = tr("BROTATOQOL_CU_HINT")
	_brotatoqol_cu_label.add_color_override("font_color", BROTATOQOL_CU_COLOR_HINT)


func _brotatoqol_cu_on_upgrade_pressed() -> void:
	if _button_pressed or _brotatoqol_cu_busy or not _brotatoqol_cu_can_upgrade(_item_data):
		return
	_brotatoqol_cu_busy = true
	# Lock every button of the screen until the animation is over
	_brotatoqol_cu_failing = true
	_button_pressed = true

	var old_item = _item_data
	var from_tier: int = old_item.tier
	var chance: float = BROTATOQOL_CU_CHANCES[from_tier]
	var success := randf() < chance
	var new_item = null
	if success:
		new_item = _brotatoqol_cu_get_item_of_tier(from_tier + 1, old_item is WeaponData)
		if new_item == null:
			ModLoaderLog.error("No item of tier %s found - keeping the old item" % (from_tier + 1), BROTATOQOL_CU_LOG)
			_brotatoqol_cu_failing = false
			_button_pressed = false
			_brotatoqol_cu_refresh()
			return
	ModLoaderLog.info("Upgrade %s (tier %s, %d%%): %s" % [old_item.my_id, from_tier, int(chance * 100), "SUCCESS" if success else "FAIL"], BROTATOQOL_CU_LOG)

	_take_button.disabled = true
	_discard_button.disabled = true
	_ban_button.disabled = true
	_brotatoqol_cu_button.disabled = true

	var overlay_script = load(_brotatoqol_cu_mod_dir().plus_file("crate_roll_overlay.gd"))
	if overlay_script == null:
		_brotatoqol_cu_apply_result(success, new_item)
		return
	var overlay = overlay_script.new()
	overlay.chance = chance
	overlay.success = success
	overlay.old_icon = old_item.icon
	overlay.new_icon = new_item.icon if new_item != null else null
	overlay.old_color = _brotatoqol_cu_tier_color(from_tier)
	overlay.new_color = BROTATOQOL_CU_TIER_COLORS[from_tier + 1]
	overlay.title_text = _brotatoqol_cu_button.text
	overlay.success_text = tr("BROTATOQOL_CU_RESULT_WIN")
	overlay.fail_text = tr("BROTATOQOL_CU_RESULT_LOSE")
	overlay.zone_success_text = "%d%%" % int(round(chance * 100.0))
	overlay.zone_fail_text = tr("BROTATOQOL_CU_ZONE_FAIL")
	var _e = overlay.connect("finished", self, "_brotatoqol_cu_apply_result", [success, new_item])
	get_tree().root.call_deferred("add_child", overlay)


func _brotatoqol_cu_apply_result(success: bool, new_item) -> void:
	_take_button.disabled = false
	_discard_button.disabled = false
	_ban_button.disabled = false
	if success:
		_brotatoqol_cu_failing = false
		_button_pressed = false
		show_item(new_item)
		_brotatoqol_cu_label.visible = true
		_brotatoqol_cu_label.text = tr("BROTATOQOL_CU_SUCCESS")
		_brotatoqol_cu_label.add_color_override("font_color", BROTATOQOL_CU_COLOR_SUCCESS)
		_brotatoqol_cu_flash(BROTATOQOL_CU_COLOR_SUCCESS)
		focus()
	else:
		_brotatoqol_cu_lose_item()


func _brotatoqol_cu_tier_color(tier: int) -> Color:
	if BROTATOQOL_CU_TIER_COLORS.has(tier):
		return BROTATOQOL_CU_TIER_COLORS[tier]
	return Color(0.6, 0.6, 0.65)


func _brotatoqol_cu_mod_dir() -> String:
	return ModLoaderMod.get_unpacked_dir().plus_file("BrotatoQoL-CrateUpgrade")


func _brotatoqol_cu_flash(color: Color) -> void:
	if _item_panel_container == null:
		return
	var tween := Tween.new()
	tween.pause_mode = Node.PAUSE_MODE_PROCESS
	add_child(tween)
	var _a = tween.interpolate_property(_item_panel_container, "modulate", color, Color.white, 0.5, Tween.TRANS_QUAD, Tween.EASE_OUT)
	var _b = tween.connect("tween_all_completed", tween, "queue_free")
	var _c = tween.start()


func _brotatoqol_cu_get_item_of_tier(tier: int, is_weapon: bool):
	var item_service_script = ItemService.get_script()
	var args = item_service_script.GetRandItemForWaveArgs.new()
	args.fixed_tier = tier
	var owned_items: Array = RunData.get_player_items(player_index)
	for locked_item in RunData.get_player_locked_shop_items(player_index):
		if locked_item[0] is ItemData:
			owned_items.push_back(locked_item[0])
	args.owned_and_shop_items = owned_items
	var type = item_service_script.TierData.WEAPONS if is_weapon else item_service_script.TierData.ITEMS
	return ItemService._get_rand_item_for_wave(RunData.current_wave, player_index, type, args)


# Same as "Recycle", but without giving materials
func _brotatoqol_cu_lose_item() -> void:
	_brotatoqol_cu_failing = false
	_button_pressed = false
	_take_button.disabled = false
	_discard_button.disabled = false
	_ban_button.disabled = false
	if _things_to_process_container and _consumable_data != null:
		_things_to_process_container.consumables.remove_element(_consumable_data)

	var ui = _brotatoqol_cu_find_upgrades_ui()
	if ui == null:
		ModLoaderLog.error("UpgradesUI not found", BROTATOQOL_CU_LOG)
		return
	ui._player_is_choosing[player_index] = false
	var consumable = ui._showing_option[player_index]
	LinkedStats.reset_player(player_index)
	ui._update_player_stats(player_index)
	ui._recheck_extra_items(player_index)
	if not ui._extra_items_to_process[player_index]:
		ui.emit_signal("consumable_selected", consumable)
		ui._showing_option[player_index] = null
	if not ui._show_next_player_options():
		ui.emit_signal("options_processed")


func _brotatoqol_cu_find_upgrades_ui():
	var node = get_parent()
	while node != null:
		if node.has_method("_show_next_player_options"):
			return node
		node = node.get_parent()
	return null
