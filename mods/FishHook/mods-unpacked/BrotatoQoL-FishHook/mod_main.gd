extends Node

# FishHook  (needs the Abyssal Terrors DLC)
#
# After every wave, each Elite and each Boss killed during that wave gives
# every player one roll:  normal Fish Hook / cursed Fish Hook / nothing.
# The weights of the three results are ModOptions sliders, separately for
# Elites and Bosses (defaults 79/19/2 and 19/79/2). Weights are relative:
# 50/50/0 means 50% normal, 50% cursed, never nothing.
# A player who already holds 3 Fish Hooks (the game's limit) gets no rolls.
#
# "Start with a Fish Hook": checkbox in the weapon selection (also a ModOptions
# toggle). When on, every player gets a normal Fish Hook at the start of wave 1.
#
# How: when the wave scene (main.tscn) enters the tree, the number of killed
# Elites/Bosses of the run is noted (RunData.elites_killed_this_run /
# bosses_killed_this_run). When the shop scene enters the tree (before the
# shop saves the run), the difference = kills of this wave, and the rolls
# happen. The hooks are added with RunData.add_item, like a bought item.

const MOD_ID := "BrotatoQoL-FishHook"
const LOG_NAME := "BrotatoQoL-FishHook:Main"
const MAIN_SCENE_PATH := "res://main.tscn"
const SHOP_SCENES := ["res://ui/menus/shop/shop.tscn", "res://ui/menus/shop/coop_shop.tscn"]
const WEAPON_SELECTION_PATH := "res://ui/menus/run/weapon_selection.tscn"
const HOOK_DATA_PATH := "res://dlcs/dlc_1/items/fish_hook/fish_hook_data.tres"
const DLC_ID := "abyssal_terrors"
const MAX_HOOKS := 3
const MOD_OPTIONS_PATH := "/root/ModLoader/Oudstand-ModOptions/ModOptions"
const MOD_OPTIONS_RETRIES := 10
const FALLBACK_CFG := "user://brotatoqol_fishhook.cfg"

const OPTION_START := "start_with_hook"
const OPTION_KEYS := ["elite_normal", "elite_cursed", "elite_none", "boss_normal", "boss_cursed", "boss_none"]
const DEFAULT_WEIGHTS := {
	"elite_normal": 79, "elite_cursed": 19, "elite_none": 2,
	"boss_normal": 19, "boss_cursed": 79, "boss_none": 2,
}

const OPTION_SUFFIX := "_pct"   # option IDs: "elite_normal_pct" ... (value 0.0 - 1.0)
const MAX_TOTAL := 100

const RESULT_NONE := 0
const RESULT_NORMAL := 1
const RESULT_CURSED := 2

var _weights := DEFAULT_WEIGHTS.duplicate()
var _start_with_hook := false
var _mod_options = null
var _mod_options_tries := 0

var _elites_at_wave_start := -1
var _bosses_at_wave_start := -1
var _messages := []          # shown in the next shop
var _checkbox: CheckButton = null
var _adjusting := false


func _init() -> void:
	_add_translations()
	_load_fallback_cfg()
	ModLoaderLog.info("Loaded", LOG_NAME)


func _ready() -> void:
	var _e = get_tree().connect("node_added", self, "_on_node_added")
	call_deferred("_register_mod_options")


func _on_node_added(node: Node) -> void:
	var path: String = node.filename
	if path == "":
		return
	if path == MAIN_SCENE_PATH:
		_on_wave_scene_added()
	elif path in SHOP_SCENES:
		_on_shop_scene_added(node)
	elif path == WEAPON_SELECTION_PATH:
		var _e = node.connect("ready", self, "_add_checkbox", [node], CONNECT_ONESHOT)


# ---------------------------------------------------------------- hook data

func _dlc_active() -> bool:
	var run_data = get_node_or_null("/root/RunData")
	return run_data != null and DLC_ID in run_data.enabled_dlcs


func _get_hook():
	var item_service = get_node_or_null("/root/ItemService")
	var keys = get_node_or_null("/root/Keys")
	if item_service != null and keys != null:
		var hook = item_service.get_element(item_service.get_items(), keys.item_fish_hook_hash)
		if hook != null:
			return hook
	if ResourceLoader.exists(HOOK_DATA_PATH):
		return load(HOOK_DATA_PATH)
	return null


func _nb_hooks(player_index: int) -> int:
	var run_data = get_node("/root/RunData")
	var keys = get_node("/root/Keys")
	return int(run_data.get_nb_item(keys.item_fish_hook_hash, player_index, false))


func _give_hook(player_index: int, cursed: bool) -> bool:
	var hook = _get_hook()
	if hook == null:
		return false
	if cursed:
		var dlc_data = get_node("/root/ItemService").get_dlc_data_by_id(DLC_ID)
		if dlc_data == null:
			return false
		hook = dlc_data.curse_item(hook, player_index)
	get_node("/root/RunData").add_item(hook, player_index)
	return true


# ---------------------------------------------------------------- wave start

func _on_wave_scene_added() -> void:
	var run_data = get_node_or_null("/root/RunData")
	if run_data == null:
		return
	_elites_at_wave_start = run_data.elites_killed_this_run.size()
	_bosses_at_wave_start = run_data.bosses_killed_this_run.size()
	_messages.clear()

	if run_data.current_wave != 1 or not _start_with_hook or not _dlc_active():
		return
	for player_index in run_data.get_player_count():
		if _nb_hooks(player_index) > 0:
			continue
		if _give_hook(player_index, false):
			ModLoaderLog.info("Player %d starts with a Fish Hook" % (player_index + 1), LOG_NAME)


# ---------------------------------------------------------------- wave end

func _on_shop_scene_added(shop: Node) -> void:
	var run_data = get_node_or_null("/root/RunData")
	if run_data == null or _elites_at_wave_start < 0:
		return     # e.g. a saved run loaded straight into the shop
	var elites: int = max(0, run_data.elites_killed_this_run.size() - _elites_at_wave_start)
	var bosses: int = max(0, run_data.bosses_killed_this_run.size() - _bosses_at_wave_start)
	_elites_at_wave_start = -1
	_bosses_at_wave_start = -1
	if (elites == 0 and bosses == 0) or not _dlc_active() or _get_hook() == null:
		return

	var coop: bool = run_data.get_player_count() > 1
	for player_index in run_data.get_player_count():
		var rolls := []
		for _i in elites:
			rolls.push_back("elite")
		for _i in bosses:
			rolls.push_back("boss")
		for kind in rolls:
			if _nb_hooks(player_index) >= MAX_HOOKS:
				break
			var result := roll(kind)
			if result == RESULT_NONE:
				_add_message(player_index, coop, kind, result)
				continue
			if _give_hook(player_index, result == RESULT_CURSED):
				_add_message(player_index, coop, kind, result)
		ModLoaderLog.info("Player %d: %d elite / %d boss rolls, now %d hook(s)" % [player_index + 1, elites, bosses, _nb_hooks(player_index)], LOG_NAME)

	if not _messages.empty():
		var _e = shop.connect("ready", self, "_show_toast", [shop], CONNECT_ONESHOT)


func roll(kind: String) -> int:
	# The values are percentages (sum <= 100). Whatever is missing to 100%
	# also counts as "nothing".
	var w_normal: int = int(clamp(_weights[kind + "_normal"], 0, MAX_TOTAL))
	var w_cursed: int = int(clamp(_weights[kind + "_cursed"], 0, MAX_TOTAL - w_normal))
	var r := randi() % MAX_TOTAL
	if r < w_normal:
		return RESULT_NORMAL
	if r < w_normal + w_cursed:
		return RESULT_CURSED
	return RESULT_NONE


func _add_message(player_index: int, coop: bool, kind: String, result: int) -> void:
	var key := "BROTATOQOL_FISHHOOK_GOT_NONE"
	if result == RESULT_NORMAL:
		key = "BROTATOQOL_FISHHOOK_GOT_NORMAL"
	elif result == RESULT_CURSED:
		key = "BROTATOQOL_FISHHOOK_GOT_CURSED"
	var text := tr(key).format({"source": tr("BROTATOQOL_FISHHOOK_SRC_" + kind.to_upper())})
	if coop:
		text = "P%d: %s" % [player_index + 1, text]
	_messages.push_back({"text": text, "result": result})


func _show_toast(shop: Node) -> void:
	if not is_instance_valid(shop) or _messages.empty():
		return
	var layer := CanvasLayer.new()
	layer.name = "BrotatoQoLFishHookToast"
	layer.layer = 50
	shop.add_child(layer)

	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.margin_left = -500
	box.margin_right = 500
	box.margin_top = 120
	box.alignment = BoxContainer.ALIGN_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(box)

	var font = load("res://resources/fonts/actual/base/font_40_outline.tres")
	if font == null:
		font = load("res://resources/fonts/actual/base/font_26_outline.tres")
	for message in _messages:
		var label := Label.new()
		label.text = message.text
		label.align = Label.ALIGN_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if font != null:
			label.add_font_override("font", font)
		var color := Color(0.75, 0.75, 0.75)
		if message.result == RESULT_NORMAL:
			color = Color("76ff76")
		elif message.result == RESULT_CURSED:
			color = Color("c77dff")
		label.add_color_override("font_color", color)
		box.add_child(label)
	_messages.clear()

	var tween := Tween.new()
	tween.pause_mode = Node.PAUSE_MODE_PROCESS
	layer.add_child(tween)
	var _a = tween.interpolate_property(box, "modulate:a", 1.0, 0.0, 1.0, Tween.TRANS_QUAD, Tween.EASE_IN, 4.0)
	var _b = tween.connect("tween_all_completed", layer, "queue_free")
	var _c = tween.start()


# ---------------------------------------------------------------- weapon selection checkbox

func _add_checkbox(selection: Node) -> void:
	if not is_instance_valid(selection) or selection.get_node_or_null("BrotatoQoLFishHookStart") != null:
		return
	if not _dlc_active() or _get_hook() == null:
		return
	var check := CheckButton.new()
	check.name = "BrotatoQoLFishHookStart"
	check.text = tr("BROTATOQOL_FISHHOOK_START")
	check.pressed = _start_with_hook
	check.focus_mode = Control.FOCUS_ALL
	check.clip_text = false
	var font = load("res://resources/fonts/actual/base/font_26.tres")
	if font != null:
		check.add_font_override("font", font)
	var hover = load("res://resources/themes/button_styles/button_hover.tres")
	if hover != null:
		check.add_stylebox_override("hover_pressed", hover)
	var hook = _get_hook()
	if hook != null and hook.icon != null:
		check.icon = hook.icon
		check.expand_icon = true
	check.add_constant_override("hseparation", 12)
	selection.add_child(check)

	# Width: with expand_icon the icon is not part of the minimum size, so
	# reserve room for icon + text + switch explicitly.
	var height := 60.0
	var text_width := 300.0
	var used_font = check.get_font("font")
	if used_font != null:
		text_width = used_font.get_string_size(check.text).x
	var switch_width := 80.0
	var switch_icon = check.get_icon("off")
	if switch_icon != null:
		switch_width = switch_icon.get_width()
	var width: float = 32.0 + (height if check.icon != null else 0.0) + 12.0 + text_width + 16.0 + switch_width + 16.0
	width = max(width, check.get_combined_minimum_size().x)

	# Top right corner, same height as the back button row
	check.anchor_left = 1.0
	check.anchor_right = 1.0
	check.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	check.rect_min_size = Vector2(width, height)
	check.margin_right = -32.0
	check.margin_left = -32.0 - width
	check.margin_top = 28.0
	check.margin_bottom = 28.0 + height
	var _e = check.connect("toggled", self, "_on_checkbox_toggled")
	_checkbox = check


func _on_checkbox_toggled(pressed: bool) -> void:
	_set_start_with_hook(pressed)


func _set_start_with_hook(value: bool) -> void:
	if _start_with_hook == value:
		return
	_start_with_hook = value
	if _mod_options != null:
		_mod_options.set_value(MOD_ID, OPTION_START, value)
	else:
		_save_fallback_cfg()
	ModLoaderLog.info("Start with Fish Hook: %s" % value, LOG_NAME)


func _load_fallback_cfg() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(FALLBACK_CFG) == OK:
		_start_with_hook = bool(cfg.get_value("fishhook", OPTION_START, false))


func _save_fallback_cfg() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("fishhook", OPTION_START, _start_with_hook)
	var _e = cfg.save(FALLBACK_CFG)


# ---------------------------------------------------------------- ModOptions

func _register_mod_options() -> void:
	_mod_options = get_node_or_null(MOD_OPTIONS_PATH)
	if _mod_options == null:
		_mod_options_tries += 1
		if _mod_options_tries < MOD_OPTIONS_RETRIES:
			var _t = get_tree().create_timer(0.5).connect("timeout", self, "_register_mod_options")
		else:
			ModLoaderLog.info("ModOptions not installed - default chances are used", LOG_NAME)
		return
	if not _mod_options.get_registered_mods().has(MOD_ID):
		var options := [{
			"type": "toggle",
			"id": OPTION_START,
			"label": "BROTATOQOL_FISHHOOK_START",
			"default": false
		}]
		for key in OPTION_KEYS:
			options.push_back({
				"type": "slider",
				"id": key + OPTION_SUFFIX,
				"label": "BROTATOQOL_FISHHOOK_OPT_" + key.to_upper(),
				"default": DEFAULT_WEIGHTS[key] / 100.0,
				"min": 0.0,
				"max": 1.0,
				"step": 0.01
			})
		_mod_options.register_mod_options(MOD_ID, {
			"tab_title": "Fish Hook",
			"options": options,
			"info_text": "BROTATOQOL_FISHHOOK_OPT_INFO"
		})
	var start = _mod_options.get_value(MOD_ID, OPTION_START)
	if start != null:
		_start_with_hook = bool(start)
	for key in OPTION_KEYS:
		var value = _mod_options.get_value(MOD_ID, key + OPTION_SUFFIX)
		if value != null:
			_weights[key] = _to_percent(value)
	# saved values from before the limit existed
	for kind in ["elite", "boss"]:
		_enforce_limit(kind + "_none")
	if not _mod_options.is_connected("config_changed", self, "_on_config_changed"):
		_mod_options.connect("config_changed", self, "_on_config_changed")
	ModLoaderLog.info("Registered with ModOptions (start=%s, weights=%s)" % [_start_with_hook, _weights], LOG_NAME)


func _on_config_changed(mod_id: String, option_id: String, new_value) -> void:
	if mod_id != MOD_ID:
		return
	if option_id == OPTION_START:
		_start_with_hook = bool(new_value)
		if _checkbox != null and is_instance_valid(_checkbox) and _checkbox.pressed != _start_with_hook:
			_checkbox.set_pressed_no_signal(_start_with_hook)
	elif option_id.ends_with(OPTION_SUFFIX):
		var key := option_id.trim_suffix(OPTION_SUFFIX)
		if not _weights.has(key):
			return
		_weights[key] = _to_percent(new_value)
		if not _adjusting:
			_enforce_limit(key)


func _to_percent(value) -> int:
	return int(clamp(round(float(value) * 100.0), 0, MAX_TOTAL))


# The three sliders of a group (elite / boss) may add up to 100% at most.
# When the changed slider pushes the sum over 100%, the other two are lowered:
# - "normal" or "cursed" changed: first "nothing", then the other hook slider
# - "nothing" changed: both hook sliders, proportionally
func _enforce_limit(changed_key: String) -> void:
	var kind: String = changed_key.split("_")[0]
	var k_normal := kind + "_normal"
	var k_cursed := kind + "_cursed"
	var k_none := kind + "_none"
	var excess: int = _weights[k_normal] + _weights[k_cursed] + _weights[k_none] - MAX_TOTAL
	if excess <= 0:
		return
	var new_values := {}
	if changed_key == k_none:
		var a: int = _weights[k_normal]
		var b: int = _weights[k_cursed]
		var take_a := int(round(float(excess) * a / max(1, a + b)))
		take_a = int(clamp(take_a, max(0, excess - b), min(a, excess)))
		new_values[k_normal] = a - take_a
		new_values[k_cursed] = b - (excess - take_a)
	else:
		var other := k_cursed if changed_key == k_normal else k_normal
		var from_none: int = min(_weights[k_none], excess)
		new_values[k_none] = _weights[k_none] - from_none
		new_values[other] = max(0, _weights[other] - (excess - from_none))
	_adjusting = true
	for key in new_values:
		if new_values[key] != _weights[key]:
			_apply_value(key, new_values[key])
	_adjusting = false


func _apply_value(key: String, percent: int) -> void:
	_weights[key] = percent
	var value := percent / 100.0
	var slider = _find_ui_slider(key + OPTION_SUFFIX)
	if slider != null:
		slider.value = value     # updates the label and calls set_value
	if _mod_options != null and not is_equal_approx(float(_mod_options.get_value(MOD_ID, key + OPTION_SUFFIX)), value):
		_mod_options.set_value(MOD_ID, key + OPTION_SUFFIX, value)


# The HSlider of this mod's option in the open ModOptions menu (or null)
func _find_ui_slider(option_id: String):
	var node_name: String = "%sSlider" % option_id.capitalize().replace(" ", "")
	return _search_slider(get_tree().root, node_name, option_id)


func _search_slider(node: Node, node_name: String, option_id: String):
	if node.name == node_name:
		var hslider = node.get_node_or_null("HSlider")
		if hslider != null:
			for connection in hslider.get_signal_connection_list("value_changed"):
				var binds: Array = connection.binds
				if binds.size() >= 2 and binds[0] == MOD_ID and binds[1] == option_id:
					return hslider
	for child in node.get_children():
		var found = _search_slider(child, node_name, option_id)
		if found != null:
			return found
	return null


# ---------------------------------------------------------------- texts

func _add_translations() -> void:
	var de := {
		"BROTATOQOL_FISHHOOK_START": "Mit Angelhaken starten",
		"BROTATOQOL_FISHHOOK_OPT_ELITE_NORMAL": "Elite: normaler Angelhaken",
		"BROTATOQOL_FISHHOOK_OPT_ELITE_CURSED": "Elite: verfluchter Angelhaken",
		"BROTATOQOL_FISHHOOK_OPT_ELITE_NONE": "Elite: nichts",
		"BROTATOQOL_FISHHOOK_OPT_BOSS_NORMAL": "Boss: normaler Angelhaken",
		"BROTATOQOL_FISHHOOK_OPT_BOSS_CURSED": "Boss: verfluchter Angelhaken",
		"BROTATOQOL_FISHHOOK_OPT_BOSS_NONE": "Boss: nichts",
		"BROTATOQOL_FISHHOOK_OPT_INFO": "Benötigt Abyssal Terrors. Nach jeder Welle bekommt man pro getötetem Elite und Boss einen Versuch. Die drei Werte zusammen ergeben höchstens 100% – erhöht man einen, werden die anderen automatisch verringert. Fehlt etwas zu 100%, zählt der Rest als „nichts“. Mit 3 Angelhaken gibt es keine Versuche mehr.",
		"BROTATOQOL_FISHHOOK_SRC_ELITE": "Elite",
		"BROTATOQOL_FISHHOOK_SRC_BOSS": "Boss",
		"BROTATOQOL_FISHHOOK_GOT_NORMAL": "{source}: Angelhaken erhalten!",
		"BROTATOQOL_FISHHOOK_GOT_CURSED": "{source}: Verfluchter Angelhaken erhalten!",
		"BROTATOQOL_FISHHOOK_GOT_NONE": "{source}: kein Angelhaken",
	}
	var en := {
		"BROTATOQOL_FISHHOOK_START": "Start with a Fish Hook",
		"BROTATOQOL_FISHHOOK_OPT_ELITE_NORMAL": "Elite: normal Fish Hook",
		"BROTATOQOL_FISHHOOK_OPT_ELITE_CURSED": "Elite: cursed Fish Hook",
		"BROTATOQOL_FISHHOOK_OPT_ELITE_NONE": "Elite: nothing",
		"BROTATOQOL_FISHHOOK_OPT_BOSS_NORMAL": "Boss: normal Fish Hook",
		"BROTATOQOL_FISHHOOK_OPT_BOSS_CURSED": "Boss: cursed Fish Hook",
		"BROTATOQOL_FISHHOOK_OPT_BOSS_NONE": "Boss: nothing",
		"BROTATOQOL_FISHHOOK_OPT_INFO": "Requires Abyssal Terrors. After every wave you get one roll per Elite and Boss killed. The three values add up to 100% at most - raising one lowers the others automatically. Anything missing to 100% also counts as \"nothing\". Once you hold 3 Fish Hooks there are no more rolls.",
		"BROTATOQOL_FISHHOOK_SRC_ELITE": "Elite",
		"BROTATOQOL_FISHHOOK_SRC_BOSS": "Boss",
		"BROTATOQOL_FISHHOOK_GOT_NORMAL": "{source}: Fish Hook received!",
		"BROTATOQOL_FISHHOOK_GOT_CURSED": "{source}: Cursed Fish Hook received!",
		"BROTATOQOL_FISHHOOK_GOT_NONE": "{source}: no Fish Hook",
	}
	var locales := ["de", "en", "es", "fr", "it", "ja", "ko", "pl", "pt", "ru", "tr", "zh", "zh_TW"]
	for locale in locales:
		var source: Dictionary = de if locale == "de" else en
		var t := Translation.new()
		t.locale = locale
		for key in source:
			t.add_message(key, source[key])
		TranslationServer.add_translation(t)
