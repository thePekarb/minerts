class_name GatheringSystem
extends Node

signal resources_delivered(faction: String, resource: String, amount: int)

var grid_manager: GridManager
var resource_spawner: ResourceSpawner

var storage_buildings: Array[Building] = []
var active_mines: Array[Building] = []

func init_gathering(grid_mgr: GridManager, spawner: ResourceSpawner) -> void:
	grid_manager = grid_mgr
	resource_spawner = spawner

	EventBus.building_constructed.connect(_on_building_constructed)
	EventBus.entity_died.connect(_on_entity_died)

func register_storage(b: Building) -> void:
	if is_instance_valid(b) and not storage_buildings.has(b):
		storage_buildings.append(b)

func _on_building_constructed(b: Building) -> void:
	if b.building_type == BuildingConfigs.BuildingType.STORAGE or b.building_type == BuildingConfigs.BuildingType.CAMPFIRE:
		if not storage_buildings.has(b):
			storage_buildings.append(b)
	elif b.building_type == BuildingConfigs.BuildingType.MINE:
		if not active_mines.has(b):
			active_mines.append(b)

func _on_entity_died(e: Variant) -> void:
	if e is Building:
		storage_buildings.erase(e)
		active_mines.erase(e)

func process_gathering(delta: float, all_units: Array[Unit]) -> void:
	_update_mines(delta)

	for u in all_units:
		if not is_instance_valid(u) or not u.is_alive or u.faction not in ["player","goblin"]:
			continue
		if u.state == UnitConfigs.UnitState.MINING_INSIDE:
			continue

		match u.current_order:
			UnitConfigs.UnitOrder.GATHER:
				_update_unit_gather(u, delta)
			UnitConfigs.UnitOrder.BUILD:
				_update_unit_build(u, delta)
			UnitConfigs.UnitOrder.INTERACT:
				_update_unit_interact(u, delta)

func _update_mines(delta: float) -> void:
	for mine in active_mines:
		if not is_instance_valid(mine) or not mine.is_alive or not mine.is_constructed:
			continue

		# Count active garrisoned miners
		var active_count: int = 0
		for m in mine.assigned_miners:
			if is_instance_valid(m) and m.is_alive:
				if m.state == UnitConfigs.UnitState.MINING_INSIDE:
					active_count += 1
				else:
					# Check if reached the mine
					var dist_to_mine: float = Vector2(m.global_position.x - mine.global_position.x, m.global_position.z - mine.global_position.z).length()
					if dist_to_mine < 2.5 and absf(m.position.y-mine.position.y)<1.2:
						m.garrison_in_building(mine)
						active_count += 1
					elif m.path.is_empty():
						_approach(m,mine.position)

		if active_count > 0:
			mine.mine_cycle_timer += delta
			if mine.mine_cycle_timer >= 2.5:
				mine.mine_cycle_timer = 0.0
				var stone_produced: int = active_count * 1
				FactionEconomy.add(mine.faction,"stone", stone_produced)

				if mine.level >= 2:
					var ore_produced: int = active_count * 1
					FactionEconomy.add(mine.faction,"ore", ore_produced)

				SoundManager.play_mine()

func _update_unit_gather(u: Unit, delta: float) -> void:
	# 1. If returning to storage with gathered resources
	if u.state == UnitConfigs.UnitState.RETURNING_TO_STORAGE or (is_instance_valid(u.target) and u.target is Building):
		u.state = UnitConfigs.UnitState.RETURNING_TO_STORAGE
		var target_storage: Building = u.target as Building if (is_instance_valid(u.target) and u.target is Building) else null
		if not is_instance_valid(target_storage) or not target_storage.is_alive:
			target_storage = _find_closest_storage(u.global_position,u.faction)
			u.target = target_storage
			if target_storage:
				var path: Array[Vector3] = grid_manager.find_interaction_path(u,target_storage,1.5)
				u.set_path(path)

		var dist_to_storage: float = 9999.0
		if target_storage:
			dist_to_storage = Vector2(u.global_position.x - target_storage.global_position.x, u.global_position.z - target_storage.global_position.z).length()

		if target_storage and grid_manager.interaction_distance(u.position,target_storage) < 1.6 and absf(u.position.y-target_storage.position.y)<1.2:
			# Drop off resources
			if u.inventory.get("amount", 0) > 0:
				FactionEconomy.add(u.faction,u.inventory.get("type", "wood"), u.inventory.get("amount", 0))
				resources_delivered.emit(u.faction,u.inventory.get("type","wood"),u.inventory.get("amount",0))
				u.inventory["amount"] = 0
				u.inventory["type"] = ""
				SoundManager.play_click()

			u.stop()
			u.state = UnitConfigs.UnitState.IDLE
			u.target=null;u.current_order=UnitConfigs.UnitOrder.MOVE

			# If assigned to a lumber zone, lumber zone system handles next dispatch.
			# Otherwise search for another tree nearby!
			if u.assigned_lumber_zone_id == "":
				_find_next_resource_to_gather(u)
		elif target_storage and u.path.is_empty():
			_approach(u,target_storage.position,UnitConfigs.UnitState.RETURNING_TO_STORAGE)
		return

	# 2. If gathering from target resource node
	if not is_instance_valid(u.target):
		u.target = null
		u.state = UnitConfigs.UnitState.IDLE
		if u.inventory.get("amount", 0) > 0:
			_send_to_storage(u)
		elif u.assigned_lumber_zone_id == "":
			_find_next_resource_to_gather(u)
		return

	var res_node: Node = u.target as Node
	if not res_node.has_meta("resource_type"):
		u.target = null
		u.stop()
		return

	var res_pos: Vector3 = res_node.global_position if "global_position" in res_node else Vector3.ZERO
	# Planar horizontal distance ignoring stepped terrain height
	var dist: float = Vector2(u.global_position.x - res_pos.x, u.global_position.z - res_pos.z).length()

	if dist > 2.1 or absf(u.position.y-res_pos.y)>1.2:
		if u.state != UnitConfigs.UnitState.MOVING or u.path.is_empty():
			_approach(u,res_pos)
	else:
		u.stop()
		u.state = UnitConfigs.UnitState.GATHERING
		u.gather_timer += delta

		# Face resource
		var face_dir: Vector3 = (res_pos - u.global_position).normalized()
		u.rotation.y = atan2(face_dir.x, face_dir.z)

		if u.gather_timer >= 1.0:
			u.gather_timer = 0.0
			SoundManager.play_chop()

			var res_type: String = res_node.get_meta("resource_type", "wood")
			var capacity: int = int(u.config.get("inventory_capacity", 10))
			var remaining: int = res_node.get_meta("resource_amount", 0)
			var amount: int = mini(2, mini(remaining, capacity - int(u.inventory.get("amount", 0))))
			remaining -= amount
			res_node.set_meta("resource_amount", remaining)
			u.inventory["type"] = res_type
			u.inventory["amount"] = u.inventory.get("amount", 0) + amount

			# Check if resource depleted
			if remaining <= 0:
				var gx: int = res_node.get_meta("grid_x", -1)
				var gz: int = res_node.get_meta("grid_z", -1)
				if gx >= 0 and gz >= 0:
					grid_manager.free_tile(gx, gz)
				if resource_spawner:
					resource_spawner.remove_resource(res_node)
				res_node.queue_free()

				_send_to_storage(u)
			elif u.inventory.get("amount", 0) >= capacity: # Capacity from unit balance config
				_send_to_storage(u)

func _find_next_resource_to_gather(u: Unit) -> void:
	if u.navigation.retry_after>0:return
	u.navigation.retry_after=1.0
	if not resource_spawner:
		return
	var nearest_res: Node = null
	var min_d: float = 14.0
	for res_id in resource_spawner.resources:
		var res: Node = resource_spawner.resources[res_id]
		if is_instance_valid(res) and res.has_meta("resource_type") and (not u.has_meta("gather_kind") or res.get_meta("resource_type")==u.get_meta("gather_kind")):
			var d: float = Vector2(u.global_position.x - res.global_position.x, u.global_position.z - res.global_position.z).length()
			if d < min_d and not grid_manager.find_path(u.position,res.position,u.faction).is_empty():
				min_d = d
				nearest_res = res

	if nearest_res:
		u.current_order = UnitConfigs.UnitOrder.GATHER
		u.target = nearest_res
		var path: Array[Vector3] = grid_manager.find_interaction_path(u,nearest_res,2.0)
		u.set_path(path)
		u.state = UnitConfigs.UnitState.MOVING

func _send_to_storage(u: Unit) -> void:
	var storage: Building = _find_closest_storage(u.global_position,u.faction)
	if storage:
		u.target = storage
		u.state = UnitConfigs.UnitState.RETURNING_TO_STORAGE
		var path: Array[Vector3] = grid_manager.find_interaction_path(u,storage,1.5)
		u.set_path(path)
	else:
		u.state = UnitConfigs.UnitState.IDLE

func _update_unit_interact(u: Unit, delta: float) -> void:
	if not is_instance_valid(u.target):
		u.target = null
		u.state = UnitConfigs.UnitState.IDLE
		return

	var poi: Node = u.target as Node

	var poi_pos: Vector3 = poi.global_position
	var dist: float = Vector2(u.global_position.x - poi_pos.x, u.global_position.z - poi_pos.z).length()
	if dist > 2.0:
		if u.state != UnitConfigs.UnitState.MOVING or u.path.is_empty():
			_approach(u,poi_pos)
	else:
		u.stop()
		u.state = UnitConfigs.UnitState.IDLE
		u.current_order = UnitConfigs.UnitOrder.MOVE
		if poi.get_meta("poi_type", "") == "cave_entrance":
			grid_manager.underground.enter(u, poi.get_meta("entry_cell"))
			if u.faction=="player" and not grid_manager.underground.cutaway:
				grid_manager.underground.toggle_view()
		elif poi.get_meta("poi_type", "") == "chest" and not poi.get_meta("opened", false):
			poi.set_meta("opened", true)
			var loot: Dictionary = poi.get_meta("loot", {})
			for res in loot:
				FactionEconomy.add(u.faction,res, loot[res])
			SoundManager.play_chest()
			EventBus.toast.emit("Chest opened! +%s" % str(loot), "success")
			var gx: int = poi.get_meta("grid_x", -1)
			var gz: int = poi.get_meta("grid_z", -1)
			if gx >= 0 and gz >= 0:
				grid_manager.free_tile(gx, gz)
			poi.queue_free()

func _update_unit_build(u: Unit, delta: float) -> void:
	if not is_instance_valid(u.target) or not (u.target is Building):
		u.target = null
		u.state = UnitConfigs.UnitState.IDLE
		return

	var b: Building = u.target as Building
	if not b.is_alive:
		u.target = null
		u.state = UnitConfigs.UnitState.IDLE
		return

	if b.is_constructed:
		u.target = null
		u.current_order = UnitConfigs.UnitOrder.MOVE
		u.state = UnitConfigs.UnitState.IDLE
		return

	var fp: Vector2i = b.footprint
	var dist: float = Vector2(maxf(0, absf(u.position.x - b.position.x) - fp.x * 0.5), maxf(0, absf(u.position.z - b.position.z) - fp.y * 0.5)).length()
	if dist > 1.1:
		if u.state != UnitConfigs.UnitState.MOVING or u.path.is_empty():
			_approach(u,b.global_position)
	else:
		u.stop()
		u.state = UnitConfigs.UnitState.BUILDING
		u.build_timer += delta
		if u.build_timer >= 0.5:
			u.build_timer = 0.0
			SoundManager.play_build()

		var done: bool = b.advance_construction(delta * 100.0 / maxf(b.config.get("build_time", 5.0), 0.1))
		if done:
			u.target = null
			u.current_order = UnitConfigs.UnitOrder.MOVE
			u.state = UnitConfigs.UnitState.IDLE

func _find_closest_storage(pos: Vector3, faction: String = "player") -> Building:
	var closest: Building = null
	var min_dist: float = 99999.0
	for b in storage_buildings:
		if is_instance_valid(b) and b.is_alive and b.is_constructed and b.faction==faction:
			var d: float = Vector2(pos.x - b.global_position.x, pos.z - b.global_position.z).length()
			if d < min_dist:
				min_dist = d
				closest = b
	return closest

func _approach(unit: Unit, point: Vector3, move_state: UnitConfigs.UnitState = UnitConfigs.UnitState.MOVING) -> void:
	if unit.navigation.retry_after>0.0:return
	unit.set_path(grid_manager.find_interaction_path(unit,unit.target,grid_manager.interaction_reach(unit)) if is_instance_valid(unit.target) else grid_manager.find_unit_path(unit,point,true))
	unit.navigation.retry_after=0.75
	unit.state=move_state
