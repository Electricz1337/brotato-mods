extends CanvasLayer

# Damage meter HUD, attached to every wave scene (main.tscn) by mod_main.gd.
#
# Rows: [icon] value   - weapons first, then items, each sorted by damage.
# Values are refreshed a few times per second and frozen when the wave ends.

const LOG_NAME := "BrotatoQoL-DamageMeter:Meter"
const UPDATE_INTERVAL := 0.25
const PLAYER_INDEX := 0

const MARGIN_SIDE := 24.0
const ICON_SIZE := 44.0
const ICON_PADDING := 3.0
const ROW_GAP := 6.0
const CATEGORY_GAP := 16.0
const TEXT_GAP := 10.0
const PANEL_PADDING := 10.0
const MAX_ROWS := 16

const COLOR_PANEL := Color(0.0, 0.0, 0.0, 0.45)
const COLOR_ICON_BG := Color(0.12, 0.12, 0.12, 0.9)
const COLOR_TEXT := Color(1, 1, 1, 1)
const COLOR_TEXT_SECONDARY := Color(0.72, 0.72, 0.72, 1)
const COLOR_SEPARATOR := Color(1, 1, 1, 0.25)

# Tracking texts that mean "damage dealt" (see ItemParentData.get_tracking_text)
const DAMAGE_TEXTS := ["DAMAGE_DEALT", "EXPLOSION_DAMAGE_DEALT"]
# Array tracking values where the game uses another text for one index
const INDEX_TEXT_OVERRIDES := {
	"item_bone_dice_hash": [1, "stats_lost"],
	"item_bonk_dog_hash": [1, "damage_dealt"],
	"item_bot_o_mine_hash": [1, "dropped_landmines"],
	"character_hiker_hash": [0, "materials_gained"],
	"item_doc_moth_hash": [1, "health_recovered"],
	"item_hungry_hungry_dinosaur_hash": [1, "fruits_eaten"],
}

var settings = null          # mod_main.gd

var _canvas: Control = null
var _font: Font = null
var _rows_weapons := []      # [{icon, tier, damage}]
var _rows_items := []
var _elapsed := 0.0
var _started := false
var _frozen := false
var _update_left := 0.0
var _item_baseline := {}     # tracking key -> value at wave start


func _ready() -> void:
	layer = 1                # above the world, below the game's UI (pause menu etc.)
	_canvas = Control.new()
	_canvas.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var _e = _canvas.connect("draw", self, "_draw_meter")
	add_child(_canvas)

	_font = load("res://resources/fonts/actual/base/font_26_outline.tres")
	if _font == null:
		_font = _canvas.get_font("font", "Label")

	# The meter is added deferred, so the players are usually already there
	# (and "players_spawned" was already emitted). Start right away then.
	var players = get_parent().get("_players")
	var spawner = get_parent().get_node_or_null("EntitySpawner")
	if (players is Array and not players.empty()) or spawner == null:
		_on_players_spawned([])
	else:
		var _err = spawner.connect("players_spawned", self, "_on_players_spawned", [], CONNECT_DEFERRED | CONNECT_ONESHOT)


# Wave start: weapon damage was just reset by the game, item values are
# snapshotted so only this wave's damage is shown.
func _on_players_spawned(_players) -> void:
	_item_baseline = {}
	var run_data = get_node_or_null("/root/RunData")
	if run_data != null and run_data.tracked_item_effects.size() > PLAYER_INDEX:
		var tracked: Dictionary = run_data.tracked_item_effects[PLAYER_INDEX]
		for key in tracked:
			_item_baseline[key] = tracked[key].duplicate() if tracked[key] is Array else tracked[key]
	if not _started:
		ModLoaderLog.info("Damage meter started for this wave", LOG_NAME)
	_started = true
	_update_left = 0.0


func _process(delta: float) -> void:
	if not _started:
		return
	var main = get_parent()
	if not _frozen:
		if main.get("_cleaning_up") == true:
			_frozen = true            # wave over: keep the final numbers
		else:
			_elapsed = _get_wave_elapsed(main, delta)

	_update_left -= delta
	if _update_left > 0.0:
		return
	_update_left = UPDATE_INTERVAL
	if not _frozen:
		_collect()
	_canvas.update()


func _get_wave_elapsed(main, delta: float) -> float:
	var timer = main.get("_wave_timer")
	if timer != null and is_instance_valid(timer) and timer.wait_time > 0.0:
		return max(0.0, timer.wait_time - timer.time_left)
	return _elapsed + delta


# ---------------------------------------------------------------- data

func _collect() -> void:
	_rows_weapons = []
	_rows_items = []
	var run_data = get_node_or_null("/root/RunData")
	if run_data == null or run_data.players_data.size() <= PLAYER_INDEX:
		return

	for weapon in run_data.get_player_weapons_ref(PLAYER_INDEX):
		_rows_weapons.push_back({"icon": weapon.icon, "tier": weapon.tier, "damage": int(weapon.dmg_dealt_last_wave)})

	if run_data.tracked_item_effects.size() > PLAYER_INDEX:
		var tracked: Dictionary = run_data.tracked_item_effects[PLAYER_INDEX]
		var seen := {}
		var sources := []
		var character = run_data.get_player_character(PLAYER_INDEX)
		if character != null:
			sources.push_back(character)
		for item in run_data.get_player_items_ref(PLAYER_INDEX):
			sources.push_back(item)
		for item in sources:
			if seen.has(item.my_id_hash):
				continue
			seen[item.my_id_hash] = true
			if not tracked.has(item.my_id_hash):
				continue
			var damage = _get_item_damage(item, tracked[item.my_id_hash], _item_baseline.get(item.my_id_hash, null))
			if damage == null:
				continue
			_rows_items.push_back({"icon": item.icon, "tier": item.tier, "damage": int(damage)})

	_rows_weapons.sort_custom(self, "_sort_by_damage")
	_rows_items.sort_custom(self, "_sort_by_damage")


# Damage this wave, or null if the item doesn't track damage
func _get_item_damage(item, value, baseline):
	var text: String = str(item.tracking_text)
	if value is Array:
		var override = _get_index_override(item.my_id_hash)
		var total := 0
		var any_damage := false
		for i in value.size():
			var text_i := text
			if override != null and override[0] == i:
				text_i = override[1]
			if not DAMAGE_TEXTS.has(text_i.to_upper()):
				continue
			any_damage = true
			var base := 0
			if baseline is Array and i < baseline.size():
				base = int(baseline[i])
			total += int(value[i]) - base
		return max(0, total) if any_damage else null

	if not DAMAGE_TEXTS.has(text.to_upper()):
		return null
	var base_value := 0
	if baseline != null and not (baseline is Array):
		base_value = int(baseline)
	return max(0, int(value) - base_value)


func _get_index_override(id_hash: int):
	var keys = get_node_or_null("/root/Keys")
	if keys == null:
		return null
	for key_name in INDEX_TEXT_OVERRIDES:
		var h = keys.get(key_name)
		if h != null and h == id_hash:
			return INDEX_TEXT_OVERRIDES[key_name]
	return null


func _sort_by_damage(a: Dictionary, b: Dictionary) -> bool:
	return a.damage > b.damage


# ---------------------------------------------------------------- drawing

func _format_number(value: float) -> String:
	if value >= 1000000.0:
		return "%.1fM" % (value / 1000000.0)
	if value >= 10000.0:
		return "%dk" % int(value / 1000.0)
	if value >= 1000.0:
		return "%.1fk" % (value / 1000.0)
	return str(int(round(value)))


# Returns [[text, color], ...] for one row
func _value_parts(damage: int) -> Array:
	var parts := []
	if settings == null or settings.show_dps:
		var dps := float(damage) / max(1.0, _elapsed)
		parts.push_back([_format_number(dps) + "/s", COLOR_TEXT])
	if settings != null and settings.show_total:
		var color := COLOR_TEXT_SECONDARY if settings.show_dps else COLOR_TEXT
		parts.push_back([_format_number(damage), color])
	return parts


func _draw_meter() -> void:
	if not _started or _font == null:
		return
	if settings != null and not settings.enabled:
		return

	var groups := []
	if settings == null or settings.show_weapons:
		if not _rows_weapons.empty():
			groups.push_back(_rows_weapons)
	if settings == null or settings.show_items:
		if not _rows_items.empty():
			groups.push_back(_rows_items)
	if groups.empty():
		return

	# Limit rows so the list fits on screen
	var rows := []           # [row, is_first_of_group]
	for g in groups:
		var first := true
		for row in g:
			if rows.size() >= MAX_ROWS:
				break
			rows.push_back([row, first and not rows.empty()])
			first = false

	# Measure text width
	var part_gap := _font.get_string_size("  ").x
	var text_width := 0.0
	var texts := []
	for entry in rows:
		var parts := _value_parts(entry[0].damage)
		var w := 0.0
		for i in parts.size():
			w += _font.get_string_size(parts[i][0]).x
			if i > 0:
				w += part_gap
		texts.push_back(parts)
		text_width = max(text_width, w)

	var content_w := ICON_SIZE + TEXT_GAP + text_width
	var content_h := 0.0
	for entry in rows:
		content_h += ICON_SIZE + ROW_GAP + (CATEGORY_GAP if entry[1] else 0.0)
	content_h -= ROW_GAP

	var screen: Vector2 = _canvas.rect_size
	var panel_w := content_w + PANEL_PADDING * 2.0
	var panel_h := content_h + PANEL_PADDING * 2.0
	var right: bool = settings == null or settings.side_right
	var panel_x := screen.x - MARGIN_SIDE - panel_w if right else MARGIN_SIDE
	var panel_y := (screen.y - panel_h) / 2.0
	_canvas.draw_rect(Rect2(panel_x, panel_y, panel_w, panel_h), COLOR_PANEL)

	var x := panel_x + PANEL_PADDING
	var y := panel_y + PANEL_PADDING
	var ascent := _font.get_ascent()
	var text_h := _font.get_height()
	for i in rows.size():
		var row: Dictionary = rows[i][0]
		if rows[i][1]:
			var sep_y := y + CATEGORY_GAP / 2.0 - ROW_GAP / 2.0
			_canvas.draw_line(Vector2(x, sep_y), Vector2(x + content_w, sep_y), COLOR_SEPARATOR, 2.0)
			y += CATEGORY_GAP

		_draw_icon(Rect2(x, y, ICON_SIZE, ICON_SIZE), row.icon, row.tier)

		var tx := x + ICON_SIZE + TEXT_GAP
		var ty := y + (ICON_SIZE - text_h) / 2.0 + ascent
		for j in texts[i].size():
			var part = texts[i][j]
			_canvas.draw_string(_font, Vector2(tx, ty), part[0], part[1])
			tx += _font.get_string_size(part[0]).x + part_gap
		y += ICON_SIZE + ROW_GAP


func _draw_icon(rect: Rect2, icon, tier: int) -> void:
	var border := _tier_color(tier)
	_canvas.draw_rect(rect, border)
	_canvas.draw_rect(rect.grow(-2.0), COLOR_ICON_BG)
	if icon != null:
		_canvas.draw_texture_rect(icon, rect.grow(-ICON_PADDING), false)


func _tier_color(tier: int) -> Color:
	var item_service = get_node_or_null("/root/ItemService")
	if item_service != null and item_service.has_method("get_color_from_tier"):
		var c: Color = item_service.get_color_from_tier(tier)
		if c != Color.white:
			return c
	return Color(0.45, 0.45, 0.45, 1.0)
