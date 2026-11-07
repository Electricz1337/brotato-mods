extends Node

# FartCushion – adds a new item "Furzkissen / Whoopee Cushion"
#
#  - Tier: uncommon (blue), price 40 (same base price as the Piggy Bank)
#  - Unique: max 1 per run
#  - Owning it unlocks a dash. Default bindings: Shift (keyboard) and
#    L3 / left stick click (controller) - both unused by the game.
#    With "Oudstand-ModOptions" installed, both can be changed in
#    Options -> Mods (dropdowns). Without it, the defaults are used.
#  - Cooldown 3s, divided by (1 + attack speed %), min 0.5s
#
# No game scripts are replaced. The item is added to the base game's item set
# at runtime, and a small controller node is attached to every wave scene.
# Game singletons are accessed via /root/... on purpose, because this script
# is compiled while the game's autoloads are still being created.

const MOD_ID := "BrotatoQoL-FartCushion"
const LOG_NAME := "BrotatoQoL-FartCushion:Main"
const ITEM_ID := "item_brotatoqol_fart_cushion"
const MAIN_SCENE_PATH := "res://main.tscn"
const MOD_OPTIONS_PATH := "/root/ModLoader/Oudstand-ModOptions/ModOptions"
const MOD_OPTIONS_RETRIES := 10
const OPTION_KEY := "keyboard_key"
const OPTION_BUTTON := "controller_button"
const OFF := "-"

# Dropdown choice -> Godot scancode (kept short: ModOptions dropdowns can't scroll)
const KEYBOARD_CHOICES := {
	"Shift": KEY_SHIFT,
	"Ctrl": KEY_CONTROL,
	"Alt": KEY_ALT,
	"Space": KEY_SPACE,
	"Q": KEY_Q,
	"Tab": KEY_TAB,
	"-": 0,
}
const DEFAULT_KEY := "Shift"

# Dropdown choice -> joypad button index (Xbox layout names)
const CONTROLLER_CHOICES := {
	"L3": JOY_L3,            # 8  - left stick click
	"R3": JOY_R3,            # 9  - right stick click
	"Select / Back": JOY_SELECT,  # 10
	"LB": JOY_L,             # 4
	"RB": JOY_R,             # 5
	"A": JOY_XBOX_A,         # 0
	"-": -1,
}
const DEFAULT_BUTTON := "L3"

# Read every frame by the dash controller
var key_name := DEFAULT_KEY
var button_name := DEFAULT_BUTTON
var dash_scancode: int = KEYBOARD_CHOICES[DEFAULT_KEY]
var dash_button: int = CONTROLLER_CHOICES[DEFAULT_BUTTON]

var _mod_dir := ""
var _item = null
var _dash_sound = null
var _setup_done := false
var _mod_options = null
var _mod_options_tries := 0
var _translations := {}     # locale -> Translation


func _init() -> void:
	_mod_dir = ModLoaderMod.get_unpacked_dir().plus_file(MOD_ID)
	_add_translations()
	ModLoaderLog.info("Loaded", LOG_NAME)


func _ready() -> void:
	var _err = get_tree().connect("node_added", self, "_on_node_added")
	set_process(true)
	call_deferred("_register_mod_options")


# First frame: all game singletons exist -> register the item
func _process(_delta: float) -> void:
	set_process(false)
	if _setup_done:
		return
	_setup_done = true
	_dash_sound = _load_dash_sound()
	_register_item()
	_restore_item_in_saved_run()


# ---------------------------------------------------------------- ModOptions

func _register_mod_options() -> void:
	_mod_options = get_node_or_null(MOD_OPTIONS_PATH)
	if _mod_options == null:
		_mod_options_tries += 1
		if _mod_options_tries < MOD_OPTIONS_RETRIES:
			var _e = get_tree().create_timer(0.5).connect("timeout", self, "_register_mod_options")
		else:
			ModLoaderLog.info("ModOptions not installed - using default bindings (Shift / L3)", LOG_NAME)
		return

	if not _mod_options.get_registered_mods().has(MOD_ID):
		_mod_options.register_mod_options(MOD_ID, {
			"tab_title": "Whoopee Cushion",
			"options": [
				{
					"type": "dropdown",
					"id": OPTION_KEY,
					"label": "BROTATOQOL_FART_OPTION_KEY",
					"default": DEFAULT_KEY,
					"choices": KEYBOARD_CHOICES.keys()
				},
				{
					"type": "dropdown",
					"id": OPTION_BUTTON,
					"label": "BROTATOQOL_FART_OPTION_BUTTON",
					"default": DEFAULT_BUTTON,
					"choices": CONTROLLER_CHOICES.keys()
				}
			],
			"info_text": "BROTATOQOL_FART_OPTION_INFO"
		})

	# Registration loads the saved values but does not emit config_changed
	_set_key(_mod_options.get_value(MOD_ID, OPTION_KEY))
	_set_button(_mod_options.get_value(MOD_ID, OPTION_BUTTON))
	if not _mod_options.is_connected("config_changed", self, "_on_config_changed"):
		_mod_options.connect("config_changed", self, "_on_config_changed")
	ModLoaderLog.info("Registered with ModOptions (key = %s, button = %s)" % [key_name, button_name], LOG_NAME)


func _on_config_changed(mod_id: String, option_id: String, new_value) -> void:
	if mod_id != MOD_ID:
		return
	if option_id == OPTION_KEY:
		_set_key(new_value)
	elif option_id == OPTION_BUTTON:
		_set_button(new_value)
	ModLoaderLog.info("Bindings changed: key = %s, button = %s" % [key_name, button_name], LOG_NAME)


func _set_key(choice) -> void:
	var choice_name := str(choice)
	if not KEYBOARD_CHOICES.has(choice_name):
		choice_name = DEFAULT_KEY
	key_name = choice_name
	dash_scancode = KEYBOARD_CHOICES[choice_name]
	_update_description()


func _set_button(choice) -> void:
	var choice_name := str(choice)
	if not CONTROLLER_CHOICES.has(choice_name):
		choice_name = DEFAULT_BUTTON
	button_name = choice_name
	dash_button = CONTROLLER_CHOICES[choice_name]
	_update_description()


# ---------------------------------------------------------------- item

func _register_item() -> void:
	var item_service = get_node_or_null("/root/ItemService")
	var progress_data = get_node_or_null("/root/ProgressData")
	var keys = get_node_or_null("/root/Keys")
	if item_service == null or progress_data == null or keys == null:
		ModLoaderLog.error("Game singletons not found, item not registered", LOG_NAME)
		return

	var effect = load("res://items/global/effect.gd").new()
	effect.key = ""                       # purely descriptive, applies nothing
	effect.text_key = "EFFECT_BROTATOQOL_FART_CUSHION"
	effect.value = 3
	effect.effect_sign = 2                # Sign.NEUTRAL
	effect.custom_args = []

	var item = load("res://items/global/item_data.gd").new()
	item.my_id = ITEM_ID
	item.my_id_hash = keys.generate_hash(ITEM_ID)
	item.name = "ITEM_BROTATOQOL_FART_CUSHION"
	item.icon = _load_texture(_mod_dir.plus_file("assets/fart_cushion_icon.png"))
	item.tier = 1                         # UNCOMMON (blue)
	item.value = 40                       # same as Piggy Bank
	item.max_nb = 1                       # unique
	item.unlocked_by_default = true
	item.can_be_looted = true
	item.is_lockable = true
	item.effects = [effect]
	item.item_appearances = []
	item.tags = []
	item.tracking_text = ""
	item.minimum_difficulty = 0
	_item = item

	var item_set = item_service.base_game_item_set
	if item_set == null:
		ModLoaderLog.error("Base item set not found", LOG_NAME)
		return
	for existing in item_set.items:
		if existing.my_id == ITEM_ID:
			return
	item_set.items.push_back(item)
	item_service.invalidate_items_cache()
	item_service._item_id_lookup.clear()

	if not progress_data.items_unlocked.has(item.my_id_hash):
		progress_data.items_unlocked.push_back(item.my_id_hash)
	item_service.init_unlocked_pool()
	ModLoaderLog.info("Item registered: %s" % ITEM_ID, LOG_NAME)


func _load_texture(path: String) -> Texture:
	var image := Image.new()
	var err := image.load(path)
	if err != OK:
		ModLoaderLog.error("Could not load icon %s (%s)" % [path, err], LOG_NAME)
		return null
	var tex := ImageTexture.new()
	tex.create_from_image(image, 0)
	return tex


func _load_dash_sound() -> AudioStreamSample:
	var file := File.new()
	var path := _mod_dir.plus_file("assets/fart.pcm")
	if file.open(path, File.READ) != OK:
		ModLoaderLog.error("Could not load sound %s" % path, LOG_NAME)
		return null
	var data := file.get_buffer(file.get_len())
	file.close()
	var stream := AudioStreamSample.new()
	stream.format = AudioStreamSample.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	stream.data = data
	return stream


# ---------------------------------------------------------------- saved runs

# The game loads the saved run while starting up - before this mod could
# register the item. Unknown items are silently dropped at that point.
# So read the run save again and put the Whoopee Cushion back.
func _restore_item_in_saved_run() -> void:
	if _item == null:
		return
	var progress_data = get_node_or_null("/root/ProgressData")
	if progress_data == null:
		return
	var state = progress_data.saved_run_state
	if typeof(state) != TYPE_DICTIONARY or not state.get("has_run_state", false):
		return
	if not state.has("players_data"):
		return

	var path: String = progress_data.SAVE_DIR + "/run_v3_" + str(progress_data.current_profile_id) + ".json"
	var file := File.new()
	if not file.file_exists(path) or file.open(path, File.READ) != OK:
		return
	var parsed := JSON.parse(file.get_as_text())
	file.close()
	if parsed.error != OK or typeof(parsed.result) != TYPE_DICTIONARY:
		return
	var saved = parsed.result.get("current_run_state", {})
	if typeof(saved) != TYPE_DICTIONARY or not saved.has("players_data"):
		return

	var restored := 0
	var states := [state]
	var last_state = progress_data.last_saved_run_state
	if typeof(last_state) == TYPE_DICTIONARY and last_state.has("players_data") and last_state.hash() != state.hash():
		states.push_back(last_state)

	for player_index in saved.players_data.size():
		var serialized_player = saved.players_data[player_index]
		if typeof(serialized_player) != TYPE_DICTIONARY or not serialized_player.has("items"):
			continue
		var serialized_items := []
		for serialized_item in serialized_player.items:
			if typeof(serialized_item) == TYPE_DICTIONARY and serialized_item.get("my_id", "") == ITEM_ID:
				serialized_items.push_back(serialized_item)
		if serialized_items.empty():
			continue
		for target_state in states:
			if player_index >= target_state.players_data.size():
				continue
			var player_data = target_state.players_data[player_index]
			var owned := 0
			for item in player_data.items:
				if item.my_id == ITEM_ID:
					owned += 1
			for i in range(owned, serialized_items.size()):
				var copy = _item.duplicate()
				copy.deserialize_and_merge(serialized_items[i])
				player_data.items.push_back(copy)
				restored += 1

	if restored > 0:
		ModLoaderLog.info("Restored %s Whoopee Cushion(s) in the saved run" % restored, LOG_NAME)


# ---------------------------------------------------------------- wave scene

func _on_node_added(node: Node) -> void:
	if node.filename != MAIN_SCENE_PATH:
		return
	var controller = load(_mod_dir.plus_file("dash_controller.gd")).new()
	controller.name = "BrotatoQoLDashController"
	controller.item_id_hash = _item.my_id_hash if _item != null else 0
	controller.dash_sound = _dash_sound
	controller.settings = self
	node.call_deferred("add_child", controller)
	ModLoaderLog.info("Wave scene detected, attaching dash controller", LOG_NAME)


# ---------------------------------------------------------------- texts

const TEXTS := {
	"de": {
		"ITEM_BROTATOQOL_FART_CUSHION": "Furzkissen",
		"BROTATOQOL_FART_OPTION_KEY": "Dash-Taste (Tastatur)",
		"BROTATOQOL_FART_OPTION_BUTTON": "Dash-Taste (Controller)",
		"BROTATOQOL_FART_OPTION_INFO": "Taste, mit der das Furzkissen einen Dash auslöst. \"-\" schaltet die jeweilige Belegung ab. Standard: Shift / L3 (linken Stick drücken).",
		"_press": "Drücke {binding}, um in Laufrichtung zu dashen",
		"_or": " oder ",
		"_none": "Keine Dash-Taste belegt (Optionen -> Mods)",
		"_cooldown": "Abklingzeit: {0}s (sinkt mit % Angriffstempo)",
	},
	"en": {
		"ITEM_BROTATOQOL_FART_CUSHION": "Whoopee Cushion",
		"BROTATOQOL_FART_OPTION_KEY": "Dash key (keyboard)",
		"BROTATOQOL_FART_OPTION_BUTTON": "Dash button (controller)",
		"BROTATOQOL_FART_OPTION_INFO": "Button that makes the Whoopee Cushion dash. \"-\" turns that binding off. Default: Shift / L3 (press the left stick).",
		"_press": "Press {binding} to dash in your movement direction",
		"_or": " or ",
		"_none": "No dash key assigned (Options -> Mods)",
		"_cooldown": "Cooldown: {0}s (reduced by % Attack Speed)",
	},
}


func _add_translations() -> void:
	var locales := ["de", "en", "es", "fr", "it", "ja", "ko", "pl", "pt", "ru", "tr", "zh", "zh_TW"]
	for locale in locales:
		var source: Dictionary = TEXTS.de if locale == "de" else TEXTS.en
		var t := Translation.new()
		t.locale = locale
		for key in source:
			if not key.begins_with("_"):
				t.add_message(key, source[key])
		TranslationServer.add_translation(t)
		_translations[locale] = t
	_update_description()


# The item text shows the currently assigned key / button
func _update_description() -> void:
	for locale in _translations:
		var src: Dictionary = TEXTS.de if locale == "de" else TEXTS.en
		var parts := []
		if dash_scancode != 0:
			parts.push_back("[color=#76ff76]%s[/color]" % key_name)
		if dash_button >= 0:
			parts.push_back("[color=#76ff76]%s[/color]%s" % [button_name, " (Controller)"])
		var first_line: String
		if parts.empty():
			first_line = src["_none"]
		else:
			first_line = src["_press"].replace("{binding}", PoolStringArray(parts).join(src["_or"]))
		_translations[locale].add_message("EFFECT_BROTATOQOL_FART_CUSHION", first_line + "\n" + src["_cooldown"])
