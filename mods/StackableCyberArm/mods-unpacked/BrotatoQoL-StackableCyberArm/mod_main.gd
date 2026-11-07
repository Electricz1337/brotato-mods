extends Node

# StackableCyberArm  (needs the Primal Dread DLC)
#
# The Cybernetic Arm (+1 weapon slot) is normally unique (max_nb = 1).
# This mod sets max_nb to -1 (unlimited), so it keeps showing up in the shop
# and can be bought several times - every copy gives one more weapon slot.
# Weapons beyond 6 are arranged in a circle by the game itself.
#
# Owned items of a saved run are stored with their own max_nb, so the owned
# copies are patched too whenever a wave or shop starts.

const LOG_NAME := "BrotatoQoL-StackableCyberArm:Main"
const ARM_PATH := "res://items/all/04_primal_dread/cybernetic_arm/cybernetic_arm.tres"
const ARM_ID := "item_cybernetic_arm"
const PATCH_SCENES := [
	"res://main.tscn",
	"res://ui/menus/shop/shop.tscn",
	"res://ui/menus/shop/coop_shop.tscn",
]

var _arm = null      # keeps the patched resource in the cache
var _arm_hash := 0


func _init() -> void:
	if ResourceLoader.exists(ARM_PATH):
		_arm = load(ARM_PATH)
		if _arm != null:
			_arm.max_nb = -1
			ModLoaderLog.info("Cybernetic Arm is no longer unique", LOG_NAME)
	else:
		ModLoaderLog.info("Cybernetic Arm not found (Primal Dread missing?) - nothing to do", LOG_NAME)


func _ready() -> void:
	var _e = get_tree().connect("node_added", self, "_on_node_added")
	call_deferred("_patch_all")


func _on_node_added(node: Node) -> void:
	if node.filename in PATCH_SCENES:
		_patch_all()


func _get_arm_hash() -> int:
	if _arm_hash == 0:
		var keys = get_node_or_null("/root/Keys")
		if keys != null:
			_arm_hash = keys.generate_hash(ARM_ID)
	return _arm_hash


func _patch_all() -> void:
	var arm_hash := _get_arm_hash()
	if arm_hash == 0:
		return
	var changed := false

	# item pool
	var item_service = get_node_or_null("/root/ItemService")
	if item_service != null:
		for item in item_service.get_items():
			if item.my_id_hash == arm_hash and item.max_nb != -1:
				item.max_nb = -1
				changed = true

	# owned copies (e.g. loaded from a saved run) and locked shop items
	var run_data = get_node_or_null("/root/RunData")
	if run_data != null:
		for player_index in run_data.players_data.size():
			for item in run_data.get_player_items_ref(player_index):
				if item.my_id_hash == arm_hash and item.max_nb != -1:
					item.max_nb = -1
					changed = true
			for locked in run_data.get_player_locked_shop_items(player_index):
				var locked_item = locked[0]
				if locked_item != null and locked_item.get("max_nb") != null and locked_item.my_id_hash == arm_hash and locked_item.max_nb != -1:
					locked_item.max_nb = -1
					changed = true

	if changed and item_service != null and "_limited_item_origins_dirty" in item_service:
		item_service._limited_item_origins_dirty = true
