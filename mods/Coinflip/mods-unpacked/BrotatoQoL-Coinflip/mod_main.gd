extends Node

# Coinflip
#
# At the end of every wave (right before level-ups / crates / shop) a popup
# offers to bet all materials collected in that wave on a coin flip:
#   Heads / Tails -> win: materials doubled, lose: materials gone
#   Skip          -> nothing happens
#
# No game script is replaced: the wave scene's EndWaveTimer "timeout" is
# re-routed to this mod, which shows the popup and afterwards calls the
# game's own _on_EndWaveTimer_timeout() unchanged.
#
# Game singletons are accessed via /root/... on purpose, because this script
# is compiled while the game's autoloads are still being created.

const MOD_ID := "BrotatoQoL-Coinflip"
const LOG_NAME := "BrotatoQoL-Coinflip:Main"
const MAIN_SCENE_PATH := "res://main.tscn"
const VANILLA_METHOD := "_on_EndWaveTimer_timeout"
const META_START_GOLD := "brotatoqol_coinflip_start_gold"

var _mod_dir := ""


func _init() -> void:
	_mod_dir = ModLoaderMod.get_unpacked_dir().plus_file(MOD_ID)
	_add_translations()
	ModLoaderLog.info("Loaded", LOG_NAME)


func _ready() -> void:
	var _err = get_tree().connect("node_added", self, "_on_node_added")


# ---------------------------------------------------------------- hooks

func _on_node_added(node: Node) -> void:
	if node.filename != MAIN_SCENE_PATH:
		return

	var timer = node.get_node_or_null("EndWaveTimer")
	if timer == null:
		ModLoaderLog.error("EndWaveTimer not found", LOG_NAME)
		return
	if timer.is_connected("timeout", node, VANILLA_METHOD):
		timer.disconnect("timeout", node, VANILLA_METHOD)
	var _e1 = timer.connect("timeout", self, "_on_end_wave_timer_timeout", [node])

	# Remember the material count at the start of the wave
	var spawner = node.get_node_or_null("EntitySpawner")
	if spawner != null:
		var _e2 = spawner.connect("players_spawned", self, "_on_players_spawned", [node], CONNECT_DEFERRED | CONNECT_ONESHOT)


func _on_players_spawned(_players, main: Node) -> void:
	var run_data = get_node_or_null("/root/RunData")
	if run_data == null or not is_instance_valid(main):
		return
	main.set_meta(META_START_GOLD, run_data.get_player_gold(0))


func _on_end_wave_timer_timeout(main: Node) -> void:
	if not is_instance_valid(main):
		return
	var amount := _get_bet_amount(main)
	if amount <= 0:
		main.call(VANILLA_METHOD)
		return

	ModLoaderLog.info("Offering coin flip for %s materials (wave %s)" % [amount, get_node("/root/RunData").current_wave], LOG_NAME)

	var tree := get_tree()
	var pause_menu = main.get("_pause_menu")
	var pause_menu_was_enabled = pause_menu.enabled if pause_menu != null else true
	var pause_menu_had_input = pause_menu.is_processing_input() if pause_menu != null else false
	if pause_menu != null:
		# Otherwise ESC would unpause the game while the popup is open
		pause_menu.enabled = false
		pause_menu.set_process_input(false)

	var utils = get_node_or_null("/root/Utils")
	if utils != null and utils.has_method("set_default_cursor"):
		utils.set_default_cursor()
	var previous_mouse_mode := Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var popup = load(_mod_dir.plus_file("coinflip_popup.gd")).new()
	popup.setup(amount, 0)
	main.add_child(popup)
	tree.paused = true

	yield(popup, "finished")

	popup.queue_free()
	tree.paused = false
	Input.set_mouse_mode(previous_mouse_mode)
	if pause_menu != null and is_instance_valid(pause_menu):
		pause_menu.enabled = pause_menu_was_enabled
		pause_menu.set_process_input(pause_menu_had_input)

	if is_instance_valid(main):
		main.call(VANILLA_METHOD)


# Materials collected in this wave, or 0 if no coin flip should be offered
func _get_bet_amount(main: Node) -> int:
	var run_data = get_node_or_null("/root/RunData")
	if run_data == null:
		return 0
	if run_data.is_coop_run:
		return 0
	# Lost / run over: let the game continue normally (retry dialog etc.)
	if main.get("_is_wave_failed") or main.get("_is_run_lost") or main.get("_is_run_won"):
		return 0
	if not main.has_meta(META_START_GOLD):
		return 0
	# Characters that use materials as health are excluded (it would be their HP)
	var players = main.get("_players")
	if players != null and players.size() > 0 and is_instance_valid(players[0]):
		if players[0].has_method("uses_materials_as_health") and players[0].uses_materials_as_health():
			return 0
	var gained: int = run_data.get_player_gold(0) - int(main.get_meta(META_START_GOLD))
	return gained if gained > 0 else 0


# ---------------------------------------------------------------- texts

func _add_translations() -> void:
	var de := {
		"MOD_COINFLIP_TITLE": "Münzwurf!",
		"MOD_COINFLIP_QUESTION": "Du hast in dieser Welle {amount} Materialien gesammelt.\nSetzt du sie auf einen Münzwurf?\nGewonnen: verdoppelt – Verloren: weg.",
		"MOD_COINFLIP_HEADS": "Kopf",
		"MOD_COINFLIP_TAILS": "Zahl",
		"MOD_COINFLIP_SKIP": "Überspringen",
		"MOD_COINFLIP_FLIPPING": "Die Münze fliegt ...",
		"MOD_COINFLIP_WIN": "{side}! Gewonnen: +{amount} Materialien",
		"MOD_COINFLIP_LOSE": "{side}! Verloren: -{amount} Materialien",
		"MOD_COINFLIP_CONTINUE": "Weiter",
		"MOD_COINFLIP_HEADS_SHORT": "K",
		"MOD_COINFLIP_TAILS_SHORT": "Z",
	}
	var en := {
		"MOD_COINFLIP_TITLE": "Coin Flip!",
		"MOD_COINFLIP_QUESTION": "You collected {amount} materials this wave.\nBet them on a coin flip?\nWin: doubled – Lose: gone.",
		"MOD_COINFLIP_HEADS": "Heads",
		"MOD_COINFLIP_TAILS": "Tails",
		"MOD_COINFLIP_SKIP": "Skip",
		"MOD_COINFLIP_FLIPPING": "The coin is flying ...",
		"MOD_COINFLIP_WIN": "{side}! You won: +{amount} materials",
		"MOD_COINFLIP_LOSE": "{side}! You lost: -{amount} materials",
		"MOD_COINFLIP_CONTINUE": "Continue",
		"MOD_COINFLIP_HEADS_SHORT": "H",
		"MOD_COINFLIP_TAILS_SHORT": "T",
	}
	var locales := ["de", "en", "es", "fr", "it", "ja", "ko", "pl", "pt", "ru", "tr", "zh", "zh_TW"]
	for locale in locales:
		var source: Dictionary = de if locale == "de" else en
		var t := Translation.new()
		t.locale = locale
		for key in source:
			t.add_message(key, source[key])
		TranslationServer.add_translation(t)
