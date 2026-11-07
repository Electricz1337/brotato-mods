extends Node

# ArtilleryStrike – adds a new item "Artillerieschlag / Artillery Strike"
#
#  - Tier: rare (purple), price 75, unique (max 1 per run), tag "explosive"
#  - Every 15s (divided by 1 + attack speed %) a crosshair appears at a random
#    spot on the map; 3s later an explosion hits there.
#  - Damage: 40 + 250% Engineering, boosted by % Damage and % Explosion Damage
#  - Radius: game explosion size 1.0, +2% per point of Elemental Damage,
#    plus the game's own % Explosion Size
#
# No game scripts are replaced. The item is added to the base game's item set
# at runtime and a controller node is attached to every wave scene.
# Game singletons are accessed via /root/... on purpose, because this script
# is compiled while the game's autoloads are still being created.

const MOD_ID := "BrotatoQoL-ArtilleryStrike"
const LOG_NAME := "BrotatoQoL-ArtilleryStrike:Main"
const ITEM_ID := "item_brotatoqol_artillery_strike"
const MAIN_SCENE_PATH := "res://main.tscn"

var _mod_dir := ""
var _item = null
var _whistle_sound = null
var _setup_done := false


func _init() -> void:
	_mod_dir = ModLoaderMod.get_unpacked_dir().plus_file(MOD_ID)
	_add_translations()
	ModLoaderLog.info("Loaded", LOG_NAME)


func _ready() -> void:
	var _err = get_tree().connect("node_added", self, "_on_node_added")
	set_process(true)


# First frame: all game singletons exist -> register the item
func _process(_delta: float) -> void:
	set_process(false)
	if _setup_done:
		return
	_setup_done = true
	_whistle_sound = _load_pcm(_mod_dir.plus_file("assets/whistle.pcm"))
	_register_item()
	_restore_item_in_saved_run()


# ---------------------------------------------------------------- item

func _register_item() -> void:
	var item_service = get_node_or_null("/root/ItemService")
	var progress_data = get_node_or_null("/root/ProgressData")
	var run_data = get_node_or_null("/root/RunData")
	var keys = get_node_or_null("/root/Keys")
	if item_service == null or progress_data == null or keys == null or run_data == null:
		ModLoaderLog.error("Game singletons not found, item not registered", LOG_NAME)
		return

	var effect = load("res://items/global/effect.gd").new()
	effect.key = ""                       # purely descriptive, applies nothing
	effect.text_key = "EFFECT_BROTATOQOL_ARTILLERY_STRIKE"
	effect.value = 15
	effect.effect_sign = 2                # Sign.NEUTRAL
	effect.custom_args = []

	var item = load("res://items/global/item_data.gd").new()
	item.my_id = ITEM_ID
	item.my_id_hash = keys.generate_hash(ITEM_ID)
	item.name = "ITEM_BROTATOQOL_ARTILLERY_STRIKE"
	item.icon = _load_texture(_mod_dir.plus_file("assets/artillery_strike_icon.png"))
	item.tier = 2                         # RARE (purple)
	item.value = 75
	item.max_nb = 1                       # unique
	item.unlocked_by_default = true
	item.can_be_looted = true
	item.is_lockable = true
	item.effects = [effect]
	item.item_appearances = []
	item.tags = ["explosive", "stat_engineering"]
	item.tracking_text = "DAMAGE_DEALT"
	item.minimum_difficulty = 0
	_item = item

	# "Damage dealt" tracking in the item tooltip
	if not run_data.init_tracked_items.has(item.my_id_hash):
		run_data.init_tracked_items[item.my_id_hash] = 0

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


func _load_pcm(path: String) -> AudioStreamSample:
	var file := File.new()
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
# So read the run save again and put the item back.
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
		ModLoaderLog.info("Restored %s Artillery Strike item(s) in the saved run" % restored, LOG_NAME)


# ---------------------------------------------------------------- wave scene

func _on_node_added(node: Node) -> void:
	if node.filename != MAIN_SCENE_PATH:
		return
	var controller = load(_mod_dir.plus_file("artillery_controller.gd")).new()
	controller.name = "BrotatoQoLArtilleryController"
	controller.item_id_hash = _item.my_id_hash if _item != null else 0
	controller.whistle_sound = _whistle_sound
	controller.crosshair_script = load(_mod_dir.plus_file("crosshair.gd"))
	node.call_deferred("add_child", controller)


# ---------------------------------------------------------------- texts

func _add_translations() -> void:
	var de := {
		"ITEM_BROTATOQOL_ARTILLERY_STRIKE": "Artillerieschlag",
		"EFFECT_BROTATOQOL_ARTILLERY_STRIKE": "Alle [color=#76ff76]15s[/color] fordert das Funkgerät einen Artillerieschlag an. Ein Fadenkreuz markiert eine zufällige Stelle, [color=#76ff76]3s[/color] später schlägt er ein.\nSchaden: [color=#76ff76]40[/color] (+250% Technik)\nRadius steigt mit Elementarschaden\nAbklingzeit sinkt mit % Angriffstempo",
	}
	var en := {
		"ITEM_BROTATOQOL_ARTILLERY_STRIKE": "Artillery Strike",
		"EFFECT_BROTATOQOL_ARTILLERY_STRIKE": "Every [color=#76ff76]15s[/color] the radio calls in an artillery strike. A crosshair marks a random spot, the shell hits it [color=#76ff76]3s[/color] later.\nDamage: [color=#76ff76]40[/color] (+250% Engineering)\nRadius increases with Elemental Damage\nCooldown is reduced by % Attack Speed",
	}
	var locales := ["de", "en", "es", "fr", "it", "ja", "ko", "pl", "pt", "ru", "tr", "zh", "zh_TW"]
	for locale in locales:
		var source: Dictionary = de if locale == "de" else en
		var t := Translation.new()
		t.locale = locale
		for key in source:
			t.add_message(key, source[key])
		TranslationServer.add_translation(t)
