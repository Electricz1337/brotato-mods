extends Node

# Added to the shop scene by mod_main.gd.
#
#  - "Ban list (N)" button in the top bar, left of "Reroll"
#  - window with every banned item / weapon of this run (icon, rarity frame);
#    clicking one lifts its ban. Close with the button, Esc or B.

const LOG_NAME := "BrotatoQoL-BanList:UI"
const PLAYER_INDEX := 0
const COLUMNS := 8
const ENTRY_SIZE := 104.0

const COLOR_PANEL := Color(0.08, 0.08, 0.08, 0.97)
const COLOR_BORDER := Color("ff5d5d")
const COLOR_ENTRY_BG := Color(0.14, 0.14, 0.14, 1.0)
const COLOR_HINT := Color(0.7, 0.7, 0.7)
const COLOR_GREEN := Color("76ff76")

var _list_button: Button = null
var _count_label: Label = null
var _layer: CanvasLayer = null
var _grid: GridContainer = null
var _title: Label = null
var _info: Label = null
var _empty: Label = null
var _close_button: Button = null
var _theme = null
var _data = null


func _ready() -> void:
	_theme = load("res://resources/themes/base_theme.tres")
	_data = load(get_script().resource_path.get_base_dir().plus_file("ban_data.gd"))
	_create_list_button()
	update_button()


func _shop() -> Node:
	return get_parent()


# ---------------------------------------------------------------- button

func _create_list_button() -> void:
	# small button in the header of the item inventory, next to the sorting
	var header = null
	var shop = _shop()
	if shop.has_method("_get_gear_container"):
		var gear = shop._get_gear_container(PLAYER_INDEX)
		if gear != null and gear.items_container != null:
			header = gear.items_container.get_node_or_null("HBoxContainer")
	if header == null:
		ModLoaderLog.error("Item inventory header not found - ban list button not added", LOG_NAME)
		return

	_list_button = Button.new()
	_list_button.name = "BrotatoQoLBanListButton"
	var menu_button_script = load("res://ui/menus/global/my_menu_button.gd")
	if menu_button_script != null:
		_list_button.set_script(menu_button_script)
	var small_theme = load("res://resources/themes/verysmall_option_button_theme.tres")
	if small_theme != null:
		_list_button.theme = small_theme
	_list_button.rect_min_size = Vector2(45, 45)
	_list_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# the game's "banned" icon (white, tinted red like in the inventory)
	var icon := TextureRect.new()
	icon.texture = load("res://items/global/baned_item.png")
	icon.expand = true
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	icon.margin_left = 7
	icon.margin_top = 7
	icon.margin_right = -7
	icon.margin_bottom = -7
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = COLOR_BORDER
	_list_button.add_child(icon)
	# small counter in the bottom right corner
	_count_label = Label.new()
	_count_label.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	_count_label.align = Label.ALIGN_RIGHT
	_count_label.valign = Label.VALIGN_BOTTOM
	_count_label.margin_right = -2
	_count_label.margin_bottom = -1
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font = load("res://resources/fonts/actual/base/font_smallest_text.tres")
	if font != null:
		_count_label.add_font_override("font", font)
	_count_label.add_color_override("font_color", Color.white)
	_count_label.add_color_override("font_outline_modulate", Color.black)
	_list_button.add_child(_count_label)
	header.add_child(_list_button)
	var reverse = header.get_node_or_null("button_reverse_order")
	if reverse != null:
		header.move_child(_list_button, reverse.get_index() + 1)
	var _e = _list_button.connect("pressed", self, "open")


func update_button() -> void:
	if _list_button == null:
		return
	if _count_label != null:
		_count_label.text = str(_data.count(PLAYER_INDEX))
	_list_button.hint_tooltip = "%s (%s)" % [tr("BROTATOQOL_BAN_LIST"), _data.count_text(PLAYER_INDEX)]


# ---------------------------------------------------------------- data

func _get_entries() -> Array:
	return _data.get_entries(PLAYER_INDEX)


func _unban(entry: Dictionary) -> void:
	_data.unban(entry, PLAYER_INDEX)
	_refresh_inventory_marks()
	# shop cards: "Ban" buttons may be usable again (limit)
	var shop = _shop()
	if shop.has_method("_get_shop_items_container"):
		var container = shop._get_shop_items_container(PLAYER_INDEX)
		if container != null and container.has_method("on_ban_update_remaining_token"):
			container.on_ban_update_remaining_token()


# Owned items show a "banned" mark in the inventory - update it
func _refresh_inventory_marks() -> void:
	var shop = _shop()
	if not shop.has_method("_get_gear_container"):
		return
	var gear = shop._get_gear_container(PLAYER_INDEX)
	if gear == null:
		return
	for container in [gear.items_container, gear.weapons_container]:
		if container == null:
			continue
		for element in container._elements.get_children():
			if element.has_method("update_banned_item"):
				element.update_banned_item()


# ---------------------------------------------------------------- window

func open() -> void:
	if _layer != null:
		return
	_build_window()
	_fill()


func close() -> void:
	if _layer == null:
		return
	_layer.queue_free()
	_layer = null
	_grid = null
	update_button()
	if _list_button != null:
		_list_button.call_deferred("grab_focus")


func _input(event: InputEvent) -> void:
	if _layer == null:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_pause"):
		get_tree().set_input_as_handled()
		close()


func _build_window() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 60
	add_child(_layer)

	var root := Control.new()
	root.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	if _theme != null:
		root.theme = _theme
	_layer.add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = COLOR_BORDER
	style.set_border_width_all(4)
	style.set_corner_radius_all(12)
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	panel.add_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_constant_override("separation", 18)
	panel.add_child(vbox)

	_title = Label.new()
	_title.align = Label.ALIGN_CENTER
	_title.add_color_override("font_color", COLOR_BORDER)
	vbox.add_child(_title)

	var hint := Label.new()
	hint.text = tr("BROTATOQOL_BAN_LIST_HINT")
	hint.align = Label.ALIGN_CENTER
	hint.add_color_override("font_color", COLOR_HINT)
	vbox.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.rect_min_size = Vector2(COLUMNS * (ENTRY_SIZE + 12.0) + 20.0, 3 * (ENTRY_SIZE + 12.0) + 10.0)
	scroll.scroll_horizontal_enabled = false
	vbox.add_child(scroll)

	var scroll_box := VBoxContainer.new()
	scroll_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(scroll_box)

	_empty = Label.new()
	_empty.text = tr("BROTATOQOL_BAN_LIST_EMPTY")
	_empty.align = Label.ALIGN_CENTER
	_empty.autowrap = true
	_empty.rect_min_size = Vector2(scroll.rect_min_size.x - 20.0, 0)
	_empty.add_color_override("font_color", COLOR_HINT)
	scroll_box.add_child(_empty)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_constant_override("hseparation", 12)
	_grid.add_constant_override("vseparation", 12)
	scroll_box.add_child(_grid)

	_info = Label.new()
	_info.align = Label.ALIGN_CENTER
	_info.rect_min_size = Vector2(0, 40)
	vbox.add_child(_info)

	_close_button = Button.new()
	var menu_button_script = load("res://ui/menus/global/my_menu_button.gd")
	if menu_button_script != null:
		_close_button.set_script(menu_button_script)
	_close_button.text = tr("BROTATOQOL_BAN_LIST_CLOSE")
	_close_button.rect_min_size = Vector2(300, 65)
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var _e = _close_button.connect("pressed", self, "close")
	vbox.add_child(_close_button)


func _fill() -> void:
	if _grid == null:
		return
	for child in _grid.get_children():
		child.queue_free()
	var entries := _get_entries()
	_title.text = "%s (%s)" % [tr("BROTATOQOL_BAN_LIST"), _data.count_text(PLAYER_INDEX)]
	_empty.visible = entries.empty()

	var first: Control = null
	for entry in entries:
		var button := _make_entry_button(entry)
		_grid.add_child(button)
		if first == null:
			first = button
	if first != null:
		first.call_deferred("grab_focus")
	else:
		_close_button.call_deferred("grab_focus")


func _make_entry_button(entry: Dictionary) -> Button:
	var item = entry.item
	var button := Button.new()
	button.rect_min_size = Vector2(ENTRY_SIZE, ENTRY_SIZE)
	button.icon = item.icon
	button.expand_icon = true
	button.focus_mode = Control.FOCUS_ALL
	button.hint_tooltip = tr(item.name)

	var tier_color := _tier_color(item.tier)
	var normal := _entry_style(tier_color, COLOR_ENTRY_BG)
	var hover := _entry_style(Color.white, COLOR_ENTRY_BG.lightened(0.15))
	button.add_stylebox_override("normal", normal)
	button.add_stylebox_override("hover", hover)
	button.add_stylebox_override("focus", hover)
	button.add_stylebox_override("pressed", hover)

	# red "banned" cross over the icon
	var cross := Control.new()
	cross.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var _d = cross.connect("draw", self, "_draw_cross", [cross])
	button.add_child(cross)

	var _a = button.connect("pressed", self, "_on_entry_pressed", [entry])
	var _b = button.connect("focus_entered", self, "_show_name", [item])
	var _c = button.connect("mouse_entered", self, "_show_name", [item])
	return button


func _entry_style(border: Color, bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(4)
	s.set_corner_radius_all(8)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


func _draw_cross(control: Control) -> void:
	var size: Vector2 = control.rect_size
	var m := 14.0
	var c := Color(1.0, 0.36, 0.36, 0.75)
	control.draw_line(Vector2(m, m), size - Vector2(m, m), c, 6.0, true)
	control.draw_line(Vector2(size.x - m, m), Vector2(m, size.y - m), c, 6.0, true)


func _show_name(item) -> void:
	if _info == null:
		return
	_info.text = tr(item.name)
	_info.add_color_override("font_color", _tier_color(item.tier))


func _on_entry_pressed(entry: Dictionary) -> void:
	_unban(entry)
	var sm = get_node_or_null("/root/SoundManager")
	var sound = load("res://ui/sounds/buy.wav")
	if sm != null and sound != null:
		sm.play(sound, 0, 0.1, true)
	var name_text := tr(entry.item.name)
	_fill()
	# deferred: runs after the new focus (which shows the focused item's name)
	call_deferred("_show_unbanned", name_text)
	update_button()


func _show_unbanned(name_text: String) -> void:
	if _info == null:
		return
	_info.text = tr("BROTATOQOL_BAN_LIST_UNBANNED").format({"name": name_text})
	_info.add_color_override("font_color", COLOR_GREEN)


func _tier_color(tier: int) -> Color:
	var item_service = get_node_or_null("/root/ItemService")
	if item_service != null and item_service.has_method("get_color_from_tier"):
		var c: Color = item_service.get_color_from_tier(tier)
		if c != Color.white:
			return c
	return Color(0.55, 0.55, 0.58)
