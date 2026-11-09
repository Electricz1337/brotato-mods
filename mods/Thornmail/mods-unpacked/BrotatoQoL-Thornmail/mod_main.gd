extends Node

# Thornmail - a new rare (purple) item
#
#  - +3 armor
#  - when an enemy hits you (melee or projectile) and you don't dodge, the
#    attacker takes the incoming damage x multiplier back (per Thornmail)
#  - the multiplier is a ModOptions slider (default 100%)
#  - shown on the character as a spiked plate, damage dealt is tracked in the
#    item tooltip
#
# The player script extension is installed right away in _init, the item is
# registered on the first frame, when the game's item service exists.

const MOD_ID := "BrotatoQoL-Thornmail"
const LOG_NAME := "BrotatoQoL-Thornmail:Main"
const ITEM_ID := "item_brotatoqol_thornmail"
const MULT_META := "brotatoqol_thornmail_multiplier"
const MOD_OPTIONS_PATH := "/root/ModLoader/Oudstand-ModOptions/ModOptions"
const MOD_OPTIONS_RETRIES := 10
const OPTION_MULT := "damage_multiplier"
const DEFAULT_MULT := 1.0
const ARMOR := 3

var _mod_dir := ""
var _item = null
var _text_effect = null
var _setup_done := false
var _mod_options = null
var _mod_options_tries := 0


func _init() -> void:
	_mod_dir = ModLoaderMod.get_unpacked_dir().plus_file(MOD_ID)
	Engine.set_meta(MULT_META, DEFAULT_MULT)
	ModLoaderMod.install_script_extension(_mod_dir.plus_file("extensions/entities/units/player/player.gd"))
	_add_translations()
	ModLoaderLog.info("Loaded", LOG_NAME)


func _ready() -> void:
	set_process(true)
	call_deferred("_register_mod_options")


func _process(_delta: float) -> void:
	set_process(false)
	if _setup_done:
		return
	_setup_done = true
	_register_item()
	_restore_items_in_saved_run()


# ---------------------------------------------------------------- item

func _register_item() -> void:
	var item_service = get_node_or_null("/root/ItemService")
	var progress_data = get_node_or_null("/root/ProgressData")
	var run_data = get_node_or_null("/root/RunData")
	var keys = get_node_or_null("/root/Keys")
	if item_service == null or progress_data == null or keys == null or item_service.base_game_item_set == null:
		ModLoaderLog.error("Game singletons not found, item not registered", LOG_NAME)
		return
	for existing in item_service.base_game_item_set.items:
		if existing.my_id == ITEM_ID:
			_item = existing
			return

	var item = load("res://items/global/item_data.gd").new()
	item.my_id = ITEM_ID
	item.my_id_hash = keys.generate_hash(ITEM_ID)
	item.name = "ITEM_BROTATOQOL_THORNMAIL"
	item.icon = _load_texture("assets/thornmail_icon.png")
	item.tier = 2                    # rare / purple
	item.value = 60
	item.unlocked_by_default = true
	item.can_be_looted = true
	item.is_lockable = true
	item.max_nb = -1
	item.tags = ["stat_armor"]
	item.tracking_text = "DAMAGE_DEALT"
	item.minimum_difficulty = 0

	_text_effect = _make_text_effect("EFFECT_BROTATOQOL_THORNMAIL", _mult_percent())
	item.effects = [
		_stat_effect("stat_armor", ARMOR, 3),
		_text_effect,
	]
	var appearance = load("res://items/global/item_appearance_data.gd").new()
	appearance.sprite = _load_texture("assets/thornmail_appearance.png")
	appearance.position = 11         # TORSO
	appearance.display_priority = 2
	appearance.depth = 320.0
	appearance.is_character_appearance = false
	item.item_appearances = [appearance]
	_item = item

	item_service.base_game_item_set.items.push_back(item)
	item_service.invalidate_items_cache()
	if not progress_data.items_unlocked.has(item.my_id_hash):
		progress_data.items_unlocked.push_back(item.my_id_hash)
	# "Damage dealt" line in the tooltip
	if run_data != null and "init_tracked_items" in run_data and not run_data.init_tracked_items.has(item.my_id_hash):
		run_data.init_tracked_items[item.my_id_hash] = 0
	ModLoaderLog.info("Item registered: %s" % ITEM_ID, LOG_NAME)


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


# Description line only ("Reflects {0}% ..."), no stat change
func _make_text_effect(text_key: String, value: int):
	var keys = get_node("/root/Keys")
	var effect = load("res://items/global/effect.gd").new()
	effect.key = ""
	effect.key_hash = keys.generate_hash("")
	effect.text_key = text_key
	effect.value = value
	effect.custom_key = ""
	effect.custom_key_hash = keys.generate_hash("")
	effect.effect_sign = 0         # POSITIVE
	effect.custom_args = []
	return effect


func _load_texture(file: String) -> Texture:
	var image := Image.new()
	var path := _mod_dir.plus_file(file)
	if image.load(path) != OK:
		ModLoaderLog.error("Could not load %s" % path, LOG_NAME)
		return null
	var tex := ImageTexture.new()
	tex.create_from_image(image, Texture.FLAG_FILTER)
	return tex


func _mult_percent() -> int:
	return int(round(float(Engine.get_meta(MULT_META)) * 100.0))


# keep the "{0}%" in the description in sync with the slider
func _update_item_text() -> void:
	var percent := _mult_percent()
	if _text_effect != null:
		_text_effect.value = percent
	var run_data = get_node_or_null("/root/RunData")
	if run_data == null or _item == null:
		return
	for player_index in run_data.players_data.size():
		for owned in run_data.get_player_items_ref(player_index):
			if owned.my_id_hash == _item.my_id_hash:
				for effect in owned.effects:
					if effect.text_key == "EFFECT_BROTATOQOL_THORNMAIL":
						effect.value = percent


# ---------------------------------------------------------------- saved runs

# The saved run is loaded before this mod registers the item - the game can't
# find it then and drops it from the inventory (its armor stays applied).
# Put the Thornmails back.
func _restore_items_in_saved_run() -> void:
	if _item == null:
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
			if typeof(serialized) != TYPE_DICTIONARY:
				continue
			var player_data = state.players_data[i]
			var already := 0
			for owned in player_data.items:
				if owned != null and owned.my_id == ITEM_ID:
					already += 1
			var wanted := 0
			var cursed := []
			for saved_item in serialized.get("items", []):
				if typeof(saved_item) == TYPE_DICTIONARY and saved_item.get("my_id", "") == ITEM_ID:
					wanted += 1
					cursed.push_back(bool(saved_item.get("is_cursed", false)))
			for n in range(already, wanted):
				var copy = _item.duplicate()
				copy.is_cursed = cursed[n]
				player_data.items.push_back(copy)
				restored += 1
	if restored > 0:
		ModLoaderLog.info("Restored %d Thornmail(s) in the saved run" % restored, LOG_NAME)


# ---------------------------------------------------------------- ModOptions

func _register_mod_options() -> void:
	_mod_options = get_node_or_null(MOD_OPTIONS_PATH)
	if _mod_options == null:
		_mod_options_tries += 1
		if _mod_options_tries < MOD_OPTIONS_RETRIES:
			var _t = get_tree().create_timer(0.5).connect("timeout", self, "_register_mod_options")
		else:
			ModLoaderLog.info("ModOptions not installed - multiplier 100%", LOG_NAME)
		return
	if not _mod_options.get_registered_mods().has(MOD_ID):
		_mod_options.register_mod_options(MOD_ID, {
			"tab_title": "Thornmail",
			"options": [
				{
					"type": "slider",
					"id": OPTION_MULT,
					"label": "BROTATOQOL_TM_OPTION_MULT",
					"default": DEFAULT_MULT,
					"min": 0.1,
					"max": 10.0,
					"step": 0.1
				}
			],
			"info_text": "BROTATOQOL_TM_OPTION_INFO"
		})
	var value = _mod_options.get_value(MOD_ID, OPTION_MULT)
	if value != null:
		_set_multiplier(value)
	if not _mod_options.is_connected("config_changed", self, "_on_config_changed"):
		_mod_options.connect("config_changed", self, "_on_config_changed")
	ModLoaderLog.info("Registered with ModOptions (multiplier=%d%%)" % _mult_percent(), LOG_NAME)


func _on_config_changed(mod_id: String, option_id: String, new_value) -> void:
	if mod_id == MOD_ID and option_id == OPTION_MULT:
		_set_multiplier(new_value)


func _set_multiplier(value) -> void:
	Engine.set_meta(MULT_META, clamp(float(value), 0.1, 10.0))
	_update_item_text()


# ---------------------------------------------------------------- texts

func _add_translations() -> void:
	var de := {
		"ITEM_BROTATOQOL_THORNMAIL": "Dornenpanzer",
		"EFFECT_BROTATOQOL_THORNMAIL": "Wirft {0}% des erlittenen Schadens (vor Rüstung) auf den Angreifer zurück",
		"BROTATOQOL_TM_OPTION_MULT": "Schadensmultiplikator",
		"BROTATOQOL_TM_OPTION_INFO": "Wie viel des eingehenden Schadens der Dornenpanzer auf den Angreifer zurückwirft. 100% = gleicher Schaden, 200% = doppelter Schaden. Mehrere Dornenpanzer stapeln sich.",
	}
	var en := {
		"ITEM_BROTATOQOL_THORNMAIL": "Thornmail",
		"EFFECT_BROTATOQOL_THORNMAIL": "Reflects {0}% of the damage you take (before armor) back to the attacker",
		"BROTATOQOL_TM_OPTION_MULT": "Damage multiplier",
		"BROTATOQOL_TM_OPTION_INFO": "How much of the incoming damage the Thornmail reflects to the attacker. 100% = same damage, 200% = double damage. Multiple Thornmails stack.",
	}
	var locales := ["de", "en", "es", "fr", "it", "ja", "ko", "pl", "pt", "ru", "tr", "zh", "zh_TW"]
	for locale in locales:
		var source: Dictionary = de if locale == "de" else en
		var t := Translation.new()
		t.locale = locale
		for key in source:
			t.add_message(key, source[key])
		TranslationServer.add_translation(t)
