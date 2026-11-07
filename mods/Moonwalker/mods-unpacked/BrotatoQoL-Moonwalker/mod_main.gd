extends Node

# Moonwalker - a new character
#
#  - reversed controls: left is right, up is down (keyboard and controller)
#  - always faces against his movement direction, so he glides backwards
#  - leans further and further forward during the wave (up to 40 degrees,
#    pivoting at his feet)
#  - +20% enemies, +30 range, +20% speed, +20% dodge
#
# The player script extension is installed right away in _init (like other
# player mods), the character itself is registered on the first frame, when
# the game's item service exists.

const MOD_ID := "BrotatoQoL-Moonwalker"
const LOG_NAME := "BrotatoQoL-Moonwalker:Main"
const CHARACTER_ID := "character_brotatoqol_moonwalker"
const TEMPLATE_CHARACTER := "res://items/characters/well_rounded/well_rounded_data.tres"

var _mod_dir := ""
var _character = null
var _setup_done := false


func _init() -> void:
	_mod_dir = ModLoaderMod.get_unpacked_dir().plus_file(MOD_ID)
	ModLoaderMod.install_script_extension(_mod_dir.plus_file("extensions/entities/units/player/player.gd"))
	_add_translations()
	ModLoaderLog.info("Loaded", LOG_NAME)


func _ready() -> void:
	set_process(true)


func _process(_delta: float) -> void:
	set_process(false)
	if _setup_done:
		return
	_setup_done = true
	_register_character()
	_restore_character_in_saved_run()


# ---------------------------------------------------------------- character

func _register_character() -> void:
	var item_service = get_node_or_null("/root/ItemService")
	var progress_data = get_node_or_null("/root/ProgressData")
	var keys = get_node_or_null("/root/Keys")
	if item_service == null or progress_data == null or keys == null or item_service.base_game_item_set == null:
		ModLoaderLog.error("Game singletons not found, character not registered", LOG_NAME)
		return
	for existing in item_service.base_game_item_set.characters:
		if existing.my_id == CHARACTER_ID:
			return

	var character = load("res://items/characters/character_data.gd").new()
	character.my_id = CHARACTER_ID
	character.my_id_hash = keys.generate_hash(CHARACTER_ID)
	character.name = "CHARACTER_BROTATOQOL_MOONWALKER"
	character.icon = _load_texture("assets/moonwalker_icon.png")
	character.tier = 0
	character.value = 1
	character.unlocked_by_default = true
	character.can_be_looted = false
	character.is_lockable = false
	character.max_nb = -1
	character.tags = []
	character.tracking_text = ""
	character.minimum_difficulty = 0
	character.wanted_tags = ["stat_speed", "stat_dodge", "stat_range"]
	character.banned_item_groups = []
	character.banned_items = []
	character.banned_upgrades = []
	character.banned_meca_stats = []
	character.starting_items = []
	character.required_item_set = ""

	# same starting weapon choice as the Well Rounded character
	var template = load(TEMPLATE_CHARACTER)
	character.starting_weapons = template.starting_weapons.duplicate() if template != null else []

	character.effects = [
		_text_effect("EFFECT_BROTATOQOL_MOONWALKER_CONTROLS"),
		_text_effect("EFFECT_BROTATOQOL_MOONWALKER_LEAN"),
		_stat_effect("number_of_enemies", 20, 2),
		_stat_effect("stat_range", 30, 3),
		_stat_effect("stat_speed", 20, 3),
		_stat_effect("stat_dodge", 20, 3),
	]
	character.item_appearances = [
		_appearance("assets/moonwalker_eyes.png", 6, 3, 1200.0),
		_appearance("assets/moonwalker_mouth.png", 8, 3, 1100.0),
		_appearance("assets/moonwalker_hat.png", 4, 3, 1000.0),
	]
	_character = character

	item_service.base_game_item_set.characters.push_back(character)
	item_service.invalidate_characters_cache()
	if not progress_data.characters_unlocked.has(character.my_id_hash):
		progress_data.characters_unlocked.push_back(character.my_id_hash)
	ModLoaderLog.info("Character registered: %s" % CHARACTER_ID, LOG_NAME)


func _stat_effect(key: String, value: int, effect_sign: int):
	var keys = get_node("/root/Keys")
	var effect = load("res://items/global/effect.gd").new()
	effect.key = key
	effect.key_hash = keys.generate_hash(key)
	effect.text_key = ""
	effect.value = value
	effect.custom_key = ""
	effect.custom_key_hash = keys.generate_hash("")
	effect.storage_method = 0      # SUM
	effect.effect_sign = effect_sign
	effect.custom_args = []
	return effect


# purely descriptive line in the character description
func _text_effect(text_key: String):
	var keys = get_node("/root/Keys")
	var effect = load("res://items/global/effect.gd").new()
	effect.key = ""
	effect.key_hash = keys.generate_hash("")
	effect.text_key = text_key
	effect.value = 0
	effect.custom_key = ""
	effect.custom_key_hash = keys.generate_hash("")
	effect.effect_sign = 2         # NEUTRAL
	effect.custom_args = []
	return effect


func _appearance(file: String, position: int, priority: int, depth: float):
	var appearance = load("res://items/global/item_appearance_data.gd").new()
	appearance.sprite = _load_texture(file)
	appearance.position = position
	appearance.display_priority = priority
	appearance.depth = depth
	appearance.is_character_appearance = true
	return appearance


func _load_texture(file: String) -> Texture:
	var image := Image.new()
	var path := _mod_dir.plus_file(file)
	if image.load(path) != OK:
		ModLoaderLog.error("Could not load %s" % path, LOG_NAME)
		return null
	var tex := ImageTexture.new()
	tex.create_from_image(image, Texture.FLAG_FILTER)
	return tex


# ---------------------------------------------------------------- saved runs

# The saved run is loaded before this mod registers the character - the
# game can't find it then and leaves it empty. Put it back.
func _restore_character_in_saved_run() -> void:
	if _character == null:
		return
	var progress_data = get_node_or_null("/root/ProgressData")
	if progress_data == null:
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
	for state in [progress_data.saved_run_state, progress_data.last_saved_run_state]:
		if typeof(state) != TYPE_DICTIONARY or not state.has("players_data"):
			continue
		for i in min(saved.players_data.size(), state.players_data.size()):
			var serialized = saved.players_data[i]
			if typeof(serialized) != TYPE_DICTIONARY or serialized.get("current_character", "") != CHARACTER_ID:
				continue
			var player_data = state.players_data[i]
			if player_data.current_character == null:
				player_data.current_character = _character
				restored += 1
	if restored > 0:
		ModLoaderLog.info("Restored the Moonwalker in the saved run", LOG_NAME)


# ---------------------------------------------------------------- texts

func _add_translations() -> void:
	var de := {
		"CHARACTER_BROTATOQOL_MOONWALKER": "Der Moonwalker",
		"EFFECT_BROTATOQOL_MOONWALKER_CONTROLS": "[color=#76ff76]Umgekehrte Steuerung[/color]: gleitet immer rückwärts",
		"EFFECT_BROTATOQOL_MOONWALKER_LEAN": "Neigt sich im Laufe der Welle immer weiter nach vorne",
	}
	var en := {
		"CHARACTER_BROTATOQOL_MOONWALKER": "The Moonwalker",
		"EFFECT_BROTATOQOL_MOONWALKER_CONTROLS": "[color=#76ff76]Reversed controls[/color]: always glides backwards",
		"EFFECT_BROTATOQOL_MOONWALKER_LEAN": "Leans further and further forward during the wave",
	}
	var locales := ["de", "en", "es", "fr", "it", "ja", "ko", "pl", "pt", "ru", "tr", "zh", "zh_TW"]
	for locale in locales:
		var source: Dictionary = de if locale == "de" else en
		var t := Translation.new()
		t.locale = locale
		for key in source:
			t.add_message(key, source[key])
		TranslationServer.add_translation(t)
