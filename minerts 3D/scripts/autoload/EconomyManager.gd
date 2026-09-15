extends Node

var resources: Dictionary = {
	"wood": 120,
	"stone": 40,
	"food": 80,
	"ore": 0,
	"water": 0,
	"pop": 4,
	"max_pop": 10
}

var current_population: int:
	get: return resources.get("pop", 0)
	set(val): resources["pop"] = val

var max_population: int:
	get: return resources.get("max_pop", 10)
	set(val): resources["max_pop"] = val

func spend_resources(cost: Dictionary) -> bool:
	return deduct_cost(cost)

func _ready() -> void:
	emit_all_resources()

func emit_all_resources() -> void:
	for k in resources:
		if k == "pop" or k == "max_pop":
			EventBus.population_changed.emit(resources["pop"], resources["max_pop"])
		else:
			EventBus.resource_changed.emit(k, resources[k])

func can_afford(cost: Dictionary) -> bool:
	for res in cost:
		var amount: int = cost[res]
		if resources.get(res, 0) < amount:
			return false
	return true

func deduct_cost(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for res in cost:
		var amount: int = cost[res]
		resources[res] -= amount
		EventBus.resource_changed.emit(res, resources[res])
	return true

func add_resource(type_name: String, amount: int) -> void:
	resources[type_name] = resources.get(type_name, 0) + amount
	EventBus.resource_changed.emit(type_name, resources[type_name])

func update_population(current: int, maximum: int) -> void:
	resources["pop"] = current
	resources["max_pop"] = maximum
	EventBus.population_changed.emit(current, maximum)

func can_train_unit(type: UnitConfigs.UnitType) -> Dictionary:
	if resources["pop"] >= resources["max_pop"]:
		return {"ok": false, "reason": "Population limit reached! Build more Huts [1]."}
	var cfg: Dictionary = UnitConfigs.get_config(type)
	var cost: Dictionary = cfg.get("cost", {})
	if not can_afford(cost):
		var missing_parts: Array[String] = []
		for r in cost:
			if resources.get(r, 0) < cost[r]:
				missing_parts.append("%d %s" % [cost[r], r.capitalize()])
		return {"ok": false, "reason": "Not enough resources! Need: " + ", ".join(missing_parts)}
	return {"ok": true}
