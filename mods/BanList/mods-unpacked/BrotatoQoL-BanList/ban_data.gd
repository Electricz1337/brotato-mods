extends Reference

# Shared ban logic for the shop cards and the ban list window.
#
# Bans are stored in the game's own per-run list
# RunData.players_data[i].banned_items (saved with the run, respected by the
# shop / crate item pools). A weapon is banned in all tiers and counts as one
# ban. The optional limit (ModOptions) counts the currently active bans.

const LIMIT_META := "brotatoqol_ban_limit"     # -1 = unlimited


static func _root():
	return Engine.get_main_loop().root


static func get_limit() -> int:
	return int(Engine.get_meta(LIMIT_META)) if Engine.has_meta(LIMIT_META) else -1


# [{item, hashes, weapon_id}] - one entry per item, one per weapon
static func get_entries(player_index: int) -> Array:
	var root = _root()
	var run_data = root.get_node_or_null("RunData")
	var item_service = root.get_node_or_null("ItemService")
	var keys = root.get_node_or_null("Keys")
	if run_data == null or item_service == null or keys == null:
		return []
	if run_data.players_data.size() <= player_index:
		return []
	var banned: Array = run_data.players_data[player_index].banned_items

	var by_hash := {}
	for item in item_service.get_items():
		by_hash[item.my_id_hash] = item
	for weapon in item_service.get_weapons():
		by_hash[weapon.my_id_hash] = weapon

	var entries := []
	var weapon_entries := {}
	for raw in banned:
		var h = raw
		if raw is String:
			h = keys.generate_hash(raw)
		if not by_hash.has(h):
			continue
		var item = by_hash[h]
		if item is WeaponData:
			if weapon_entries.has(item.weapon_id):
				var entry: Dictionary = weapon_entries[item.weapon_id]
				entry.hashes.push_back(raw)
				if item.tier < entry.item.tier:
					entry.item = item
				continue
			var new_entry := {"item": item, "hashes": [raw], "weapon_id": item.weapon_id}
			weapon_entries[item.weapon_id] = new_entry
			entries.push_back(new_entry)
		else:
			entries.push_back({"item": item, "hashes": [raw], "weapon_id": ""})
	return entries


static func count(player_index: int) -> int:
	return get_entries(player_index).size()


static func limit_reached(player_index: int) -> bool:
	var limit := get_limit()
	return limit >= 0 and count(player_index) >= limit


# "3/5" with a limit, "3" without
static func count_text(player_index: int) -> String:
	var limit := get_limit()
	if limit < 0:
		return str(count(player_index))
	return "%d/%d" % [count(player_index), limit]


static func ban(item, player_index: int) -> bool:
	if limit_reached(player_index):
		return false
	var root = _root()
	var run_data = root.get_node("RunData")
	var banned: Array = run_data.players_data[player_index].banned_items
	var hashes := [item.my_id_hash]
	if item is WeaponData:
		hashes.push_back(root.get_node("Keys").generate_hash(item.weapon_id))
		for weapon in root.get_node("ItemService").get_weapons():
			if weapon.weapon_id == item.weapon_id:
				hashes.push_back(weapon.my_id_hash)
	for h in hashes:
		if not banned.has(h):
			banned.push_back(h)
	ModLoaderLog.info("Banned %s (%s)" % [item.my_id, count_text(player_index)], "BrotatoQoL-BanList:Data")
	return true


static func unban(entry: Dictionary, player_index: int) -> void:
	var root = _root()
	var banned: Array = root.get_node("RunData").players_data[player_index].banned_items
	for h in entry.hashes:
		banned.erase(h)
	if entry.weapon_id != "":
		for weapon in root.get_node("ItemService").get_weapons():
			if weapon.weapon_id == entry.weapon_id:
				banned.erase(weapon.my_id_hash)
		banned.erase(root.get_node("Keys").generate_hash(entry.weapon_id))
	ModLoaderLog.info("Ban lifted: %s" % entry.item.my_id, "BrotatoQoL-BanList:Data")
