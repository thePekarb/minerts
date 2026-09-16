class_name FactionRules
extends RefCounted
static func is_colony(faction: String) -> bool:return faction in ["player","goblin"] or faction.begins_with("peer_")
static func peer_id(faction: String) -> int:
	if faction=="player":return NetworkManager.local_peer_id if NetworkManager.is_active() else 1
	return int(faction.trim_prefix("peer_")) if faction.begins_with("peer_") else 0
static func race(faction: String) -> String:
	if faction=="goblin":return "goblin"
	if faction=="player":return GameSettings.player_faction
	return NetworkManager.slot_for_peer(peer_id(faction)).get("faction","player")
static func team(faction: String) -> String:
	var id: int=peer_id(faction)
	if id>0:return str(NetworkManager.slot_for_peer(id).get("team",faction))
	return faction
static func hostile(a: String,b: String) -> bool:
	if a==b:return false
	if b=="neutral":return true # Hunting is an explicit order, never an auto-target.
	if is_colony(a) and is_colony(b) and NetworkManager.is_active():return team(a)!=team(b)
	return true
