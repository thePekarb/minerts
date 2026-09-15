class_name FarmingSystem
extends Node

func tick(delta: float, buildings: Array[Building]) -> void:
	for building in buildings:
		if not is_instance_valid(building) or not building.is_alive or not building.is_constructed:
			continue
		if building.building_type == BuildingConfigs.BuildingType.WELL:
			building.production_timer += delta
			if building.production_timer >= 5.0:
				building.production_timer -= 5.0
				FactionEconomy.add(building.faction,"water", 2)
			building.production_status = "Вода +2 / 5 с"
		elif building.building_type == BuildingConfigs.BuildingType.FARM:
			var well: Building = find_well(building, buildings)
			if well == null:
				building.production_status = "Нужен колодец рядом (14 клеток)"
			elif FactionEconomy.resources(building.faction).get("water", 0) < 2:
				building.production_status = "Ожидание воды"
			else:
				building.production_timer += delta
				building.production_status = "Урожай %d%%" % int(building.production_timer * 5.0)
				if building.production_timer >= 20.0 and FactionEconomy.spend(building.faction,{"water": 2}):
					building.production_timer -= 20.0
					FactionEconomy.add(building.faction,"food", 12)
			if building.crop_plants:
				building.crop_plants.scale.y = lerpf(0.12, 1.0, clampf(building.production_timer / 20.0, 0, 1))
		else:
			continue
		if building.production_label == null:
			building.production_label = Label3D.new()
			building.production_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			building.production_label.position.y = 2.7
			building.production_label.font_size = 24
			building.production_label.pixel_size = 0.009
			building.add_child(building.production_label)
		building.production_label.text = building.production_status

func find_well(farm: Building, buildings: Array[Building]) -> Building:
	var best: Building
	var distance: float = 14.0 * 14.0
	for building in buildings:
		if is_instance_valid(building) and building.is_alive and building.is_constructed and building.building_type == BuildingConfigs.BuildingType.WELL and building.faction==farm.faction:
			var d: float = farm.global_position.distance_squared_to(building.global_position)
			if d <= distance:
				distance = d
				best = building
	return best
