extends "res://ui/menus/shop/shop.gd"

# Shop: adds a small "∞" toggle to the left of the material counter.
# While on, rerolls are free and unlimited (the material count stays the same).

const INFMAT_META_KEY := "brotatoqol_infinite_materials_enabled"
const INFMAT_AMOUNT := 999999
const INFMAT_GREEN := Color("76ff76")
const INFMAT_DARK := Color(0.07, 0.07, 0.07, 1.0)
const INFMAT_SIZE := 64

var _infmat_button: Button = null


func _ready() -> void:
	var gold_ui = get_node_or_null("Content/MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/GoldUI")
	if gold_ui == null:
		var gold_label = get_node_or_null("%GoldLabel")
		if gold_label != null:
			gold_ui = gold_label.get_parent()
	if gold_ui == null:
		ModLoaderLog.error("Material counter not found, toggle not added", "BrotatoQoL-InfiniteMaterials:Shop")
		return

	_infmat_button = Button.new()
	_infmat_button.name = "ModInfiniteMaterialsToggle"
	_infmat_button.rect_min_size = Vector2(INFMAT_SIZE, INFMAT_SIZE)
	_infmat_button.size_flags_vertical = SIZE_SHRINK_CENTER
	_infmat_button.hint_tooltip = "MOD_INFMAT_TOOLTIP"
	_infmat_button.focus_mode = FOCUS_NONE

	# Place it directly to the left of the material icon + counter
	var parent = gold_ui.get_parent()
	parent.add_child(_infmat_button)
	parent.move_child(_infmat_button, gold_ui.get_index())

	_infmat_button.connect("pressed", self, "_on_ModInfiniteMaterialsToggle_pressed")
	_infmat_button.connect("draw", self, "_infmat_draw_symbol")

	_infmat_update_button()
	for player_index in RunData.get_player_count():
		_refresh_currency_dependent_buttons(player_index)
	ModLoaderLog.info("Toggle added to shop", "BrotatoQoL-InfiniteMaterials:Shop")


func _infmat_is_enabled() -> bool:
	return Engine.has_meta(INFMAT_META_KEY) and Engine.get_meta(INFMAT_META_KEY) == true


func _infmat_make_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(4)
	style.set_corner_radius_all(10)
	return style


func _infmat_update_button() -> void:
	if _infmat_button == null:
		return
	var enabled := _infmat_is_enabled()
	# ON: filled green / OFF: dark with green border
	var bg: Color = INFMAT_GREEN if enabled else INFMAT_DARK
	var normal := _infmat_make_style(bg, INFMAT_GREEN)
	var hover := _infmat_make_style(bg.lightened(0.2), Color.white)
	for state in ["normal", "focus", "disabled"]:
		_infmat_button.add_stylebox_override(state, normal)
	for state in ["hover", "pressed"]:
		_infmat_button.add_stylebox_override(state, hover)
	_infmat_button.update()


# Draws the infinity symbol (two loops) on the button, so it doesn't
# depend on the game font having a "∞" character.
func _infmat_draw_symbol() -> void:
	if _infmat_button == null:
		return
	var color: Color = INFMAT_DARK if _infmat_is_enabled() else INFMAT_GREEN
	var center: Vector2 = _infmat_button.rect_size / 2.0
	var radius: float = _infmat_button.rect_size.y * 0.17
	var offset: float = radius * 0.95
	var width: float = max(3.0, _infmat_button.rect_size.y * 0.075)
	_infmat_button.draw_arc(center - Vector2(offset, 0), radius, 0.0, TAU, 32, color, width, true)
	_infmat_button.draw_arc(center + Vector2(offset, 0), radius, 0.0, TAU, 32, color, width, true)


func _on_ModInfiniteMaterialsToggle_pressed() -> void:
	Engine.set_meta(INFMAT_META_KEY, not _infmat_is_enabled())
	_infmat_update_button()
	for player_index in RunData.get_player_count():
		_refresh_currency_dependent_buttons(player_index)


func _on_RerollButton_pressed(player_index: int) -> void:
	if not _infmat_is_enabled():
		._on_RerollButton_pressed(player_index)
		return
	# Give the reroll price for a moment so the vanilla reroll goes through,
	# then put the material count back to what it was.
	var player_data = RunData.players_data[player_index]
	var gold_before: int = player_data.gold
	player_data.gold += _reroll_price[player_index]
	._on_RerollButton_pressed(player_index)
	player_data.gold = gold_before
	RunData.emit_signal("gold_changed", gold_before, player_index)


func set_reroll_button_price(player_index: int) -> void:
	.set_reroll_button_price(player_index)
	_infmat_fix_reroll_color(player_index)


func _refresh_currency_dependent_buttons(player_index: int) -> void:
	._refresh_currency_dependent_buttons(player_index)
	_infmat_fix_reroll_color(player_index)


func _infmat_fix_reroll_color(player_index: int) -> void:
	if not _infmat_is_enabled():
		return
	var reroll_button = _get_reroll_button(player_index)
	if reroll_button != null and reroll_button.has_method("set_color_from_currency"):
		reroll_button.set_color_from_currency(INFMAT_AMOUNT)
