class_name FactionEconomy
extends RefCounted

static var storage: Node
static var wallets: Dictionary = {"goblin": {"wood": 180, "stone": 90, "food": 180, "ore": 20, "water": 0}}
static func reset_bot() -> void:
	wallets["goblin"]={"wood":180,"stone":90,"food":180,"ore":20,"water":0}
static func resources(faction: String) -> Dictionary:
	if faction == "player": return EconomyManager.resources
	return wallets.get(faction,{})
static func can_afford(faction: String, cost: Dictionary) -> bool:
	var wallet: Dictionary = resources(faction)
	for key in cost:
		if wallet.get(key,0)<cost[key]:return false
	return true
static func spend(faction: String, cost: Dictionary) -> bool:
	if faction == "player":return EconomyManager.spend_resources(cost)
	if not can_afford(faction,cost):return false
	for key in cost:wallets[faction][key]-=cost[key]
	if is_instance_valid(storage):storage.consume(faction,cost)
	return true
static func add(faction: String, key: String, amount: int) -> void:
	if is_instance_valid(storage) and storage.tracks(key):
		storage.refund(faction,key,amount);return
	if faction == "player":EconomyManager.add_resource(key,amount)
	elif wallets.has(faction):wallets[faction][key]=wallets[faction].get(key,0)+amount
