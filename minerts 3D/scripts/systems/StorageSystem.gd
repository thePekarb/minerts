class_name StorageSystem
extends Node
# Wallets are totals of delivered stock. Producer buffers and carried loads are not spendable.
var game: Main
var pending_returns: Dictionary = {}
var timer: float = 0.0
func setup(main: Main) -> void:
	game=main;FactionEconomy.storage=self
	EventBus.entity_died.connect(_on_death)
	for faction in ["player"]+FactionEconomy.wallets.keys():
		var initial: Dictionary=FactionEconomy.resources(faction).duplicate()
		for key in initial:
			if tracks(key):
				_set_total(faction,key,0)
				refund(faction,key,initial[key])
func tracks(key: String) -> bool:
	return key not in ["water","pop","max_pop"]
func buildings(faction: String) -> Array[Building]:
	var result: Array[Building]=[]
	for b in game.all_buildings:
		if is_instance_valid(b) and b.is_alive and b.is_constructed and b.faction==faction and b.storage_capacity()>0:result.append(b)
	# Warehouses receive new stock before the starter camp.
	result.sort_custom(func(a,b):return a.building_type==BuildingConfigs.BuildingType.STORAGE and b.building_type!=BuildingConfigs.BuildingType.STORAGE)
	return result
func free_space(faction: String) -> int:
	var total: int=0
	for b in buildings(faction):total+=b.storage_free()
	return total
func _set_total(faction: String,key: String,amount: int) -> void:
	var wallet: Dictionary=FactionEconomy.resources(faction);wallet[key]=maxi(0,amount)
	if faction=="player":EventBus.resource_changed.emit(key,wallet[key])
func deposit(b: Building,key: String,amount: int) -> int:
	if not is_instance_valid(b) or not b.is_alive or not b.is_constructed:return 0
	var accepted: int=mini(maxi(0,amount),b.storage_free())
	if accepted<=0:return 0
	b.stored_resources[key]=b.stored_resources.get(key,0)+accepted
	_set_total(b.faction,key,FactionEconomy.resources(b.faction).get(key,0)+accepted)
	b.update_stock_visuals()
	return accepted
func deposit_any(faction: String,key: String,amount: int) -> int:
	var remaining: int=amount
	for b in buildings(faction):
		remaining-=deposit(b,key,remaining)
		if remaining<=0:break
	return amount-remaining
func consume(faction: String,cost: Dictionary) -> void:
	for key in cost:
		if not tracks(key):continue
		var remaining: int=cost[key]
		for b in buildings(faction):
			var used: int=mini(remaining,b.stored_resources.get(key,0))
			b.stored_resources[key]=b.stored_resources.get(key,0)-used;remaining-=used
			if used>0:b.update_stock_visuals()
			if remaining<=0:break
func refund(faction: String,key: String,amount: int) -> void:
	var left: int=amount-deposit_any(faction,key,amount)
	if left>0:
		if not pending_returns.has(faction):pending_returns[faction]={}
		pending_returns[faction][key]=pending_returns[faction].get(key,0)+left
func _process(delta: float) -> void:
	timer+=delta
	if timer<1:return
	timer=0
	for faction in pending_returns:
		for key in pending_returns[faction].keys():
			pending_returns[faction][key]-=deposit_any(faction,key,pending_returns[faction][key])
			if pending_returns[faction][key]<=0:pending_returns[faction].erase(key)
func _on_death(entity: Variant) -> void:
	if not entity is Building:return
	for key in entity.stored_resources:
		_set_total(entity.faction,key,FactionEconomy.resources(entity.faction).get(key,0)-entity.stored_resources[key])
	entity.stored_resources.clear()
func _exit_tree() -> void:
	if FactionEconomy.storage==self:FactionEconomy.storage=null
