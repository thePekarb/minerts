class_name CombatSystem
extends Node

var grid_manager: GridManager
var projectiles_container: Node3D

func init_combat(grid_mgr: GridManager, proj_container: Node3D) -> void:
	grid_manager = grid_mgr
	projectiles_container = proj_container

func process_combat(delta: float, all_units: Array[Unit], all_buildings: Array[Building]) -> void:
	# Death signals remove entries immediately; iterate a stable snapshot.
	for u in all_units.duplicate():
		if not is_instance_valid(u) or not u.is_alive or u.state == UnitConfigs.UnitState.MINING_INSIDE or is_instance_valid(u.embarked_in):
			continue
		u.repath_timer = maxf(0.0, u.repath_timer - delta)
		if u.get_meta("guardian",false):continue
		if u.faction == "enemy":
			_process_enemy_unit(u, delta, all_units, all_buildings)
		elif u.faction in ["player","goblin"]:
			_process_player_combat_unit(u, delta, all_units)
	for b in all_buildings.duplicate():
		if is_instance_valid(b) and b.is_alive and b.is_constructed and b.building_type == BuildingConfigs.BuildingType.TOWER:
			b.mine_cycle_timer += delta
			if b.mine_cycle_timer >= 1.3:
				var target: Unit = _find_nearest_target(b.global_position, all_units, "enemy", 10.0,b.faction=="goblin")
				if target:
					b.mine_cycle_timer = 0.0
					_spawn_projectile(b.global_position + Vector3(0, 3.2, 0), target, 16.0,b.faction)
					SoundManager.play_arrow(b.global_position)

func _process_player_combat_unit(u: Unit, delta: float, units: Array[Unit]) -> void:
	u.target_scan_timer-=delta
	if u.target_scan_timer<=0 and (u.state == UnitConfigs.UnitState.IDLE or (u.faction=="goblin" and u.current_order==UnitConfigs.UnitOrder.PATROL)) and not UnitConfigs.is_worker(u.unit_type) and not UnitConfigs.is_vessel(u.unit_type) and u.attack_damage>0:
		u.target_scan_timer=.3+float(u.get_instance_id()%11)*.01
		var target: Unit = _find_nearest_target(u.global_position, units, "enemy", u.config.get("vision_range", 8.0), u.faction=="goblin")
		if target:
			u.target = target
			u.current_order = UnitConfigs.UnitOrder.ATTACK
	if u.current_order != UnitConfigs.UnitOrder.ATTACK:
		return
	if not _valid_target(u.target):
		u.target = null
		u.stop()
		return
	_attack_or_chase(u, u.target, delta)

func _process_enemy_unit(u: Unit, delta: float, units: Array[Unit], buildings: Array[Building]) -> void:
	if u.unit_type == UnitConfigs.UnitType.CREEPER and u.fuse_timer >= 0.0:
		_process_fuse(u, delta, units, buildings)
		return
	u.target_scan_timer -= delta
	if u.target_scan_timer <= 0.0:
		u.target_scan_timer = 0.35
		var nearby: Unit = find_colonist(u.global_position, units, 12.0)
		if nearby and nearby != u.target and (not _valid_target(u.target) or not (u.target is Unit) or nearby.position.distance_to(u.position)+0.7<u.target.position.distance_to(u.position)):
			u.target = nearby
			u.path.clear()
			u.repath_timer = 0.0
	if not _valid_target(u.target):
		u.target = find_colonist(u.global_position, units, 16.0)
		if not u.target:
			u.target = _find_nearest_building(u.global_position, buildings)
		if not u.target:
			if not u.underground_unit:
				u.stop()
			return
		u.current_order = UnitConfigs.UnitOrder.ATTACK
	if u.unit_type == UnitConfigs.UnitType.CREEPER and _target_distance(u, u.target) <= u.attack_range:
		u.stop()
		u.fuse_timer = 0.0
		_show_blast_warning(u)
		SoundManager.play_creeper_fuse(u.global_position)
		return
	_attack_or_chase(u, u.target, delta)
	if u.state == UnitConfigs.UnitState.IDLE and u.path.is_empty() and not (u.target is Unit):
		var breach_target: Building = _find_nearest_building(u.global_position, buildings)
		if breach_target and breach_target != u.target:
			u.target = breach_target
			u.last_combat_destination = Vector3.INF

func _valid_target(target: Variant) -> bool:
	return is_instance_valid(target) and (target is Entity or target is Building) and target.is_alive and not (target is Unit and (target.state == UnitConfigs.UnitState.MINING_INSIDE or is_instance_valid(target.embarked_in)))

func _target_distance(u: Unit, target: Node3D) -> float:
	if target is Building:
		var fp: Vector2i = target.footprint
		var offset: Vector3 = u.global_position - target.global_position
		return Vector2(maxf(0.0, absf(offset.x) - fp.x * 0.5), maxf(0.0, absf(offset.z) - fp.y * 0.5)).length()
	return u.global_position.distance_to(target.global_position)

func _attack_or_chase(u: Unit, target: Node3D, delta: float) -> void:
	if target is Unit and target.underground_unit != u.underground_unit:
		u.target = null
		u.stop()
		return
	if u.config.get("ranged",false) and target is Unit and u.position.distance_to(target.position)<2.4 and u.repath_timer<=0 and u.health<u.max_health*.65:
		u.repath_timer=1.2
		var retreat: Vector3 = u.position+(u.position-target.position).normalized()*3.0
		var route: Array[Vector3] = grid_manager.find_unit_path(u,retreat,true)
		if not route.is_empty():u.set_path(route);u.state=UnitConfigs.UnitState.MOVING;return
	if _target_distance(u, target) <= u.attack_range and (not (target is Unit) or grid_manager.has_line_of_sight(u.global_position, target.global_position)):
		u.stop()
		u.state = UnitConfigs.UnitState.ATTACKING
		u.attack_timer += delta
		var direction: Vector3 = target.global_position - u.global_position
		if direction.length_squared() > 0.001:
			u.rotation.y = atan2(direction.x, direction.z)
		if u.attack_timer >= u.attack_cooldown:
			u.attack_timer = 0.0
			if u.config.get("ranged", false):
				_spawn_projectile(u.global_position + Vector3(0, 1.1, 0), target, u.attack_damage,u.faction,u.unit_type==UnitConfigs.UnitType.STORM_WARDEN)
				SoundManager.play_arrow(u.global_position)
			else:
				target.set_meta("last_hit_faction",u.faction)
				target.take_damage(u.attack_damage)
				if u.unit_type == UnitConfigs.UnitType.ZOMBIE:
					SoundManager.play_zombie(u.global_position)
				elif u.unit_type in [UnitConfigs.UnitType.WARRIOR, UnitConfigs.UnitType.KNIGHT, UnitConfigs.UnitType.GUARD, UnitConfigs.UnitType.GOBLIN_WARRIOR]:
					SoundManager.play_knife_scrape(u.global_position)
				elif u.unit_type == UnitConfigs.UnitType.WOLF:
					SoundManager.play_wolf_growl(u.global_position)
				else:
					SoundManager.play_attack()
	elif u.repath_timer <= 0.0:
		# Throttle expensive A* calls and refresh paths when targets move.
		u.repath_timer = 0.65
		if u.path.is_empty() or u.last_combat_destination.distance_squared_to(target.global_position) > 2.0:
			u.last_combat_destination = target.global_position
			var path: Array[Vector3] = grid_manager.find_interaction_path(u,target,u.attack_range)
			u.set_path(path)
			u.state = UnitConfigs.UnitState.MOVING if not path.is_empty() else UnitConfigs.UnitState.DEFENDING
			if path.is_empty():u.repath_timer=1.3+float(u.get_instance_id()%7)*.1

func _show_blast_warning(u: Unit) -> void:
	u.blast_warning = MeshInstance3D.new()
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = u.config.get("blast_radius", 3.2) - 0.09
	ring.outer_radius = u.config.get("blast_radius", 3.2)
	ring.rings = 40
	ring.ring_segments = 4
	u.blast_warning.mesh = ring
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("ffb85b")
	u.blast_warning.material_override = material
	u.add_child(u.blast_warning)
	u.blast_warning.position.y = 0.15

func _process_fuse(u: Unit, delta: float, units: Array[Unit], buildings: Array[Building]) -> void:
	u.fuse_timer += delta
	var pulse: float = 1.0 + 0.08 * sin(u.fuse_timer * 30.0)
	u.model_root.scale = Vector3.ONE * pulse
	if u.blast_warning:
		u.blast_warning.visible = fmod(u.fuse_timer, 0.18) < 0.12
	if u.fuse_timer < u.config.get("fuse_seconds", 1.6):
		return
	var pos: Vector3 = u.global_position
	var radius: float = u.config.get("blast_radius", 3.2)
	var damage: float = u.config.get("blast_damage", 65.0)
	for victim in units.duplicate():
		if is_instance_valid(victim) and victim.is_alive and victim != u and victim.state != UnitConfigs.UnitState.MINING_INSIDE:
			var distance: float = victim.global_position.distance_to(pos)
			if distance < radius:
				victim.take_damage(damage * lerpf(1.0, 0.3, distance / radius))
	for building in buildings.duplicate():
		if is_instance_valid(building) and building.is_alive:
			var distance: float = _target_distance(u, building)
			if distance < radius:
				building.take_damage(damage * 1.8 * lerpf(1.0, 0.3, distance / radius))
	_spawn_blast(pos, radius)
	SoundManager.play_creeper_explosion(pos)
	u.set_meta("self_destructed", true)
	u.take_damage(u.health + u.armor)

func _spawn_blast(pos: Vector3, radius: float) -> void:
	var flash: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	flash.mesh = sphere
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.65, 0.22, 0.65)
	flash.material_override = material
	projectiles_container.add_child(flash)
	flash.global_position = pos + Vector3(0, 0.5, 0)
	flash.scale = Vector3.ONE * 0.2
	var tween: Tween = flash.create_tween().set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * radius, 0.35)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.45)
	tween.chain().tween_callback(flash.queue_free)

func _spawn_projectile(from_pos: Vector3, target: Node3D, damage: float, faction: String = "player", arcane: bool = false) -> void:
	var projectile: Projectile = Projectile.new()
	projectiles_container.add_child(projectile)
	projectile.source_faction=faction
	projectile.arcane=arcane
	projectile.init_projectile(from_pos, target, damage)

func _find_nearest_target(pos: Vector3, units: Array[Unit], faction: String, radius: float, ignore_player_fog: bool = false) -> Unit:
	var best: Unit
	var distance_squared: float = radius * radius
	for unit in grid_manager.unit_index.query(get_tree(),pos,radius):
		if not is_instance_valid(unit) or not unit.is_alive or (unit.faction != faction and not (faction=="enemy" and (unit.faction=="predator" or unit.faction==("player" if ignore_player_fog else "goblin")))) or unit.state == UnitConfigs.UnitState.MINING_INSIDE or is_instance_valid(unit.embarked_in):
			continue
		if faction == "enemy" and not unit.underground_unit and not ignore_player_fog:
			var tile: Tile = grid_manager.get_tile(floori(unit.position.x), floori(unit.position.z))
			if tile == null or not tile.is_visible:
				continue
		var d: float = pos.distance_squared_to(unit.global_position)
		if d>=distance_squared:continue
		if (pos.y < -1.0) != unit.underground_unit or not grid_manager.has_line_of_sight(pos, unit.global_position):
			continue
		if d < distance_squared:
			distance_squared = d
			best = unit
	return best

func _find_nearest_building(pos: Vector3, buildings: Array[Building]) -> Building:
	var best: Building
	var distance_squared: float = INF
	for building in buildings:
		if is_instance_valid(building) and building.is_alive and pos.y >= -1.0:
			var d: float = pos.distance_squared_to(building.global_position)
			if d < distance_squared:
				distance_squared = d
				best = building
	return best

func find_colonist(pos: Vector3, units: Array[Unit], radius: float) -> Unit:
	var nearest: Unit
	var distance: float = radius*radius
	for unit in grid_manager.unit_index.query(get_tree(),pos,radius):
		if not is_instance_valid(unit) or not unit.is_alive or unit.faction not in ["player","goblin"] or unit.state==UnitConfigs.UnitState.MINING_INSIDE or is_instance_valid(unit.embarked_in):continue
		if (pos.y < -1.0)!=unit.underground_unit:continue
		var d: float = pos.distance_squared_to(unit.position)
		if d<distance and grid_manager.has_line_of_sight(pos,unit.position):nearest=unit;distance=d
	return nearest
