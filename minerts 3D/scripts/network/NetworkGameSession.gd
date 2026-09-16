class_name NetworkGameSession
extends Node
# Only the creator runs simulation. Clients interpolate authoritative entities.
var game: Main
var entities: Dictionary={}
var next_id: int=1
var motion_targets: Dictionary={}
var saved_process: Dictionary={}
var started: bool=false
var motion_timer: float=0
var state_timer: float=0
var resource_cache: Dictionary={}
var resource_nodes: Dictionary={}
var world_changes: Dictionary={}
var frames_received: int=0
var accepted_commands: int=0
var rejected_commands: int=0
func setup(main: Main) -> void:
	game=main;name="NetworkSession";process_mode=Node.PROCESS_MODE_ALWAYS
	NetworkManager.session=self
	NetworkManager.game_command.connect(_on_command)
	NetworkManager.snapshot_received.connect(_receive)
	_index_resources()
	if NetworkManager.is_host():
		for entity in game.all_units+game.all_buildings:node_id(entity)
		_pause_simulation()
	else:
		_pause_simulation()
		for u in game.all_units:u.queue_free()
		game.all_units.clear()
		for b in game.all_buildings:
			game.grid_manager.free_area(b.grid_x,b.grid_z,b.footprint.x,b.footprint.y);b.queue_free()
		game.all_buildings.clear();game.gathering_system.storage_buildings.clear();game.gathering_system.active_mines.clear()
		game.selection_system.clear_selection()
	NetworkManager.mark_loaded()
func _pause_simulation() -> void:
	var nodes: Array=[game,game.goblin_ai,game.goblin_ai.expedition,game.raid_system,game.wildlife_system,game.underground_system,game.time_of_day_system,game.storage_system,game.guardian_system]
	for node in nodes:
		if not is_instance_valid(node):continue
		saved_process[node]=node.is_processing();node.set_process(false)
	for unit in game.all_units:unit.set_physics_process(false)
func _resume_host() -> void:
	for node in saved_process:
		if is_instance_valid(node):node.set_process(saved_process[node])
	for unit in game.all_units:unit.set_physics_process(true)
	started=true
func node_id(node: Node) -> int:
	if not is_instance_valid(node):return 0
	if node.has_meta("network_id"):return int(node.get_meta("network_id"))
	if not NetworkManager.is_host():return 0
	var id: int=next_id;next_id+=1;node.set_meta("network_id",id);entities[id]=node;return id
func selected_ids() -> Array:
	var result: Array=[]
	for u in game.selection_system.selected_units:
		if is_instance_valid(u):result.append(node_id(u))
	return result
func send(action: String,extra: Dictionary={}) -> bool:
	var order: Dictionary=extra.duplicate();order.action=action
	if not order.has("units"):order.units=selected_ids()
	return NetworkManager.submit(order)
func context(point: Vector3,target: Object,mode: String="") -> bool:
	var data: Dictionary={"point":point,"mode":mode,"building":node_id(game.selection_system.selected_building)}
	if target is Unit or target is Building:data.target=node_id(target)
	elif target is Node3D:data.resource=resource_key(target)
	return send("context",data)
func resource_key(node: Node3D) -> String:
	return str(node.get_meta("resource_type",node.get_meta("poi_type","")))+":"+str(node.position.snapped(Vector3.ONE*.01))
func _index_resources() -> void:
	resource_nodes.clear()
	for node in game.resource_spawner.resources.values()+game.resource_spawner.pois.values():
		if not is_instance_valid(node):continue
		var key: String=resource_key(node);resource_nodes[key]=node
		if not resource_cache.has(key):resource_cache[key]=[node.position,node.get_meta("resource_type",""),node.get_meta("resource_amount",0),node.get_meta("opened",false)]
func _mapped(faction: String) -> String:
	if faction==NetworkManager.local_faction():return "player"
	return "peer_1" if faction=="player" else faction
func _process(delta: float) -> void:
	if not NetworkManager.is_active():return
	if NetworkManager.is_host():
		if not started:
			if not NetworkManager.all_loaded():return
			_resume_host()
		motion_timer+=delta;state_timer+=delta
		if motion_timer>=.1:
			motion_timer=0
			var rows: Array=[]
			for u in game.all_units:
				if is_instance_valid(u) and u.is_alive:rows.append([node_id(u),u.position,u.rotation.y,u.health,int(u.state),int(u.current_order),u.underground_unit])
			for id in NetworkManager.multiplayer.get_peers():
				if NetworkManager.ready_peers.has(id):
					for start in range(0,rows.size(),40):NetworkManager.send_snapshot(id,"motion",rows.slice(start,start+40),false)
		if state_timer>=.5:
			state_timer=0;_send_state()
	else:
		for id in motion_targets:
			var u: Unit=entities.get(id)
			if not is_instance_valid(u):continue
			var old: Vector3=u.position;var target: Vector3=motion_targets[id][0]
			u.position=u.position.lerp(target,1-exp(-delta*14)) if u.position.distance_squared_to(target)<64 else target
			u.rotation.y=lerp_angle(u.rotation.y,motion_targets[id][1],1-exp(-delta*14))
			u.velocity=(u.position-old)/maxf(delta,.001);u._update_animation_and_tools(delta)
		state_timer+=delta
		if state_timer>=.2:
			var elapsed: float=state_timer;state_timer=0
			game.fog_system.update_fog(game.all_units,game.all_buildings,elapsed)
			game.underground_system._update_visibility()
			game.hud.minimap.update_entities(game.all_units,game.all_buildings)
			game.hud.update_time_display(game.time_of_day_system.current_day,game.time_of_day_system.get_formatted_time())
			game.hud.update_raid_display(game.raid_system,game.time_of_day_system)
func _send_state() -> void:
	var unit_rows: Array=[];var building_rows: Array=[];var alive: Array=[]
	for u in game.all_units:
		if not is_instance_valid(u) or not u.is_alive:continue
		var id: int=node_id(u);alive.append(id)
		unit_rows.append([id,int(u.unit_type),u.faction,u.position,u.max_health,u.inventory,int(u.state),u.health,node_id(u.embarked_in),node_id(u.garrisoned_tower),u.passengers.map(func(p):return node_id(p))])
	for b in game.all_buildings:
		if not is_instance_valid(b) or not b.is_alive:continue
		var id: int=node_id(b);alive.append(id)
		building_rows.append([id,int(b.building_type),b.faction,b.grid_x,b.grid_z,b.position,b.rotation_degrees_y,b.footprint,b.is_constructed,b.construction_progress,b.health,b.is_open,b.level,b.training_queue,b.crafting_queue,b.stored_resources,b.output_buffer,b.production_status,b.rally_point,b.assigned_miners.map(func(u):return node_id(u))])
	var resource_delta: Dictionary={};var current: Dictionary={}
	for node in game.resource_spawner.resources.values()+game.resource_spawner.pois.values():
		if not is_instance_valid(node):continue
		var key: String=resource_key(node);resource_nodes[key]=node
		current[key]=[node.position,node.get_meta("resource_type",""),node.get_meta("resource_amount",0),node.get_meta("opened",false)]
		if current[key]!=resource_cache.get(key):resource_delta[key]=current[key]
	for key in resource_cache:
		if not current.has(key):resource_delta[key]=null;resource_nodes.erase(key)
	resource_cache=current
	for id in NetworkManager.multiplayer.get_peers():
		if not NetworkManager.ready_peers.has(id):continue
		for start in range(0,unit_rows.size(),40):NetworkManager.send_snapshot(id,"units",unit_rows.slice(start,start+40))
		for start in range(0,building_rows.size(),20):NetworkManager.send_snapshot(id,"buildings",building_rows.slice(start,start+20))
		NetworkManager.send_snapshot(id,"world",{"alive":alive,"wallet":FactionEconomy.resources(NetworkManager.faction_for_peer(id)),"time":game.time_of_day_system.time_of_day,"day":game.time_of_day_system.current_day,"resources":resource_delta,"caves":game.underground_system.cells.keys(),"terrain":world_changes,"zones":_zone_rows(NetworkManager.faction_for_peer(id))})
	for id in entities.keys():
		if not is_instance_valid(entities[id]):entities.erase(id)
func _receive(kind: String,data: Variant) -> void:
	if NetworkManager.is_host():return
	frames_received+=1
	match kind:
		"units":
			for row in data:
				var u: Unit=entities.get(row[0])
				if not is_instance_valid(u):
					u=game.spawn_unit(row[1],_mapped(row[2]),row[3]);u.set_meta("network_id",row[0]);entities[row[0]]=u;u.set_physics_process(false)
				u.max_health=row[4];u.inventory=row[5];u.state=row[6];u.health=row[7]
				u.set_meta("net_embarked",row[8]);u.set_meta("net_tower",row[9]);u.set_meta("net_passengers",row[10]);u.health_changed.emit(u.health,u.max_health)
		"motion":
			for row in data:
				var u: Unit=entities.get(row[0])
				if not is_instance_valid(u):continue
				motion_targets[row[0]]=[row[1],row[2]];u.health=row[3];u.state=row[4];u.current_order=row[5];u.underground_unit=row[6]
				u.collision_layer=32 if u.underground_unit else (16 if UnitConfigs.is_vessel(u.unit_type) else 2)
		"buildings":
			for row in data:
				var b: Building=entities.get(row[0])
				if not is_instance_valid(b):
					b=Building.new();b.faction=_mapped(row[2]);game.buildings_container.add_child(b);b.init_building(row[1],row[3],row[4],row[8],row[6],row[7]);b.position=row[5];b.rotation.y=deg_to_rad(row[6]);b.set_meta("network_id",row[0]);entities[row[0]]=b;game.all_buildings.append(b)
					game.grid_manager.occupy_area(b.grid_x,b.grid_z,b.footprint.x,b.footprint.y,b,b.is_gate);game.fog_system.apply_world_materials(b)
				b.is_constructed=row[8];b.construction_progress=row[9];b.health=row[10];b._update_construction_visuals();b.set_gate_open(row[11],game.grid_manager)
				if row[12]>b.level:b.upgrade_mine()
				b.training_queue.assign(row[13]);b.crafting_queue.assign(row[14]);b.stored_resources=row[15];b.output_buffer=row[16];b.production_status=row[17];b.rally_point=row[18];b.update_stock_visuals()
				b.assigned_miners.clear()
				for id in row[19]:
					if is_instance_valid(entities.get(id)):b.assigned_miners.append(entities[id])
		"world":_apply_world(data)
		"message":game.hud.show_banner(str(data))
func _apply_world(data: Dictionary) -> void:
	var alive: Dictionary={}
	for id in data.alive:alive[id]=true
	for id in entities.keys():
		if alive.has(id):continue
		var entity=entities[id]
		if is_instance_valid(entity):
			game.selection_system.remove_entity(entity)
			if entity is Unit:game.all_units.erase(entity)
			else:game.all_buildings.erase(entity);game.grid_manager.free_area(entity.grid_x,entity.grid_z,entity.footprint.x,entity.footprint.y)
			entity.queue_free()
		entities.erase(id);motion_targets.erase(id)
	for u in game.all_units:
		u.embarked_in=entities.get(u.get_meta("net_embarked",0));u.garrisoned_tower=entities.get(u.get_meta("net_tower",0));u.passengers.clear()
		for id in u.get_meta("net_passengers",[]):
			if is_instance_valid(entities.get(id)):u.passengers.append(entities[id])
	EconomyManager.resources=data.wallet.duplicate();EconomyManager.emit_all_resources();game._refresh_population()
	game.time_of_day_system.time_of_day=data.time;game.time_of_day_system.current_day=data.day;game.time_of_day_system._update_lighting()
	for key in data.resources:_apply_resource(key,data.resources[key])
	var cave_changed: bool=false
	for cell in data.caves:
		if not game.underground_system.cells.has(cell):game.underground_system.cells[cell]=true;cave_changed=true
	if cave_changed:game.underground_system._rebuild_navigation();game.underground_system._rebuild_visuals()
	_apply_zones(data.get("zones",[]))
	for cell in data.terrain:
		if game.grid_manager.get_height(cell.x,cell.y)!=data.terrain[cell]:game.terrain_generator.update_tile_height(cell.x,cell.y,data.terrain[cell],game.grid_manager)
func _apply_resource(key: String,value: Variant) -> void:
	var node: Node3D=resource_nodes.get(key)
	if value==null:
		if is_instance_valid(node):
			var cell:=Vector2i(floori(node.position.x),floori(node.position.z));game.grid_manager.free_tile(cell.x,cell.y)
			game.resource_spawner.remove_resource(node);game.resource_spawner.pois.erase(str(node.get_meta("res_id",node.name)));node.queue_free()
		resource_nodes.erase(key);return
	if not is_instance_valid(node):
		var body:=StaticBody3D.new();body.collision_layer=8;body.position=value[0];game.world_container.add_child(body)
		body.add_child(VoxelMeshFactory.create_box_mesh(Vector3(.7,.3,.5),Color("986255")))
		var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(.8,.6,.7);collision.shape=shape;body.add_child(collision)
		node=body;resource_nodes[key]=node;node.set_meta("res_id",key);game.resource_spawner.resources[key]=node
		node.set_meta("grid_x",floori(node.position.x));node.set_meta("grid_z",floori(node.position.z));node.set_meta("resource_type",value[1]);game.fog_system.apply_world_materials(node)
	node.set_meta("resource_amount",value[2]);node.set_meta("opened",value[3])
func _owned(id: int,faction: String) -> Node:
	var node=entities.get(id)
	return node if is_instance_valid(node) and node.is_alive and node.faction==faction else null
func _point(value: Variant) -> Vector3:
	if not value is Vector3 or not value.is_finite() or value.x<0 or value.z<0 or value.x>=512 or value.z>=512:return Vector3.INF
	return value
func _on_command(sender: int,command: Dictionary) -> void:
	if not NetworkManager.is_host() or not started:return
	var faction: String=NetworkManager.faction_for_peer(sender)
	var units: Array[Unit]=[]
	var raw_units=command.get("units",[])
	if not raw_units is Array or raw_units.size()>128:rejected_commands+=1;return
	for id in raw_units:
		if not id is int:rejected_commands+=1;return
		var unit=_owned(id,faction)
		if unit is Unit and not units.has(unit):units.append(unit)
	for key in ["building","target","index","type","rotation"]:
		if command.has(key) and not command[key] is int:rejected_commands+=1;return
	var b: Building=_owned(int(command.get("building",0)),faction) as Building
	NetworkManager.applying_command=true
	var error: String=_execute(faction,units,b,command)
	NetworkManager.applying_command=false
	if error=="":accepted_commands+=1
	else:
		rejected_commands+=1
		if sender==1:game.hud.show_banner(error)
		else:NetworkManager.send_snapshot(sender,"message",error)
func _execute(faction: String,units: Array[Unit],b: Building,c: Dictionary) -> String:
	var action: String=str(c.get("action",""))
	match action:
		"train":return game.production_system.enqueue(b,int(c.get("type",-1))) if b and UnitConfigs.UnitType.values().has(c.get("type")) else "Неверное здание или юнит."
		"craft":return game.workshop_system.enqueue(b,str(c.get("item",""))) if b else "Чужая мастерская."
		"cancel":
			if not b:return "Чужое здание."
			var index: int=int(c.get("index",-1))
			if b.building_type==BuildingConfigs.BuildingType.WORKSHOP:game.workshop_system.cancel(b,index)
			else:game.production_system.cancel(b,index)
		"zone_create":
			var point: Vector3=_point(c.get("point"))
			if point==Vector3.INF or not c.get("radius") is float:return "Неверная зона."
			if game.lumber_zone_system.zones.size()>=128:return "Слишком много зон."
			if not game.all_units.any(func(u):return u.faction==faction and u.position.distance_squared_to(point)<1024):return "Зона далеко от поселения."
			game.lumber_zone_system.create_zone(point,clampf(c.radius,2,15),game.all_units,faction)
		"zone_plus","zone_minus","zone_delete":
			var found=null
			for zone in game.lumber_zone_system.zones:
				if zone.id==c.get("zone") and zone.faction==faction:found=zone;break
			if found==null:return "Чужая зона."
			if action=="zone_plus":game.lumber_zone_system.add_worker(found,game.all_units)
			elif action=="zone_minus":game.lumber_zone_system.remove_worker(found)
			else:game.lumber_zone_system.delete_zone(found)
		"dig_area":
			var first=c.get("from");var last=c.get("to")
			if not first is Vector2i or not last is Vector2i:return "Неверная область."
			if first.x<0 or first.y<0 or last.x>=512 or last.y>=512 or last.x<first.x or last.y<first.y or (last.x-first.x+1)*(last.y-first.y+1)>256:return "Выберите область до 256 блоков."
			for x in range(first.x,last.x+1):
				for z in range(first.y,last.y+1):
					var cell:=Vector2i(x,z)
					if not game.all_units.any(func(u):return u.faction==faction and Vector2(u.position.x-x,u.position.z-z).length_squared()<256):continue
					if game.terraforming_system.is_tile_diggable(cell) and not game.terraforming_system.is_cell_queued(cell):game.terraforming_system._queue_dig_task(cell,faction)
			game.terraforming_system.dispatch_idle_workers(game.all_units)
		"tower":
			if not b or b.building_type!=BuildingConfigs.BuildingType.TOWER:return "Чужая башня."
			if is_instance_valid(b.garrisoned_archer):b.ungarrison_archer()
			else:
				for u in units:
					if not u.config.get("ranged",false):continue
					game.selection_system.cancel_assignments(u);u.target=b;u.current_order=UnitConfigs.UnitOrder.INTERACT;u.set_path(game.grid_manager.find_unit_path(u,b.position,true));u.state=UnitConfigs.UnitState.MOVING;break
		"gate":
			if not b or not b.is_gate:return "Чужие ворота."
			b.toggle_gate(game.grid_manager)
		"rally":
			if not b or _point(c.get("point"))==Vector3.INF:return "Неверная точка сбора."
			game.production_system.set_rally(b,c.point)
		"place":return _place(faction,units,c)
		"demolish":
			if not b:return "Чужая постройка."
			game.construction_system.demolish_building(b,game.all_units)
		"mine_plus","mine_minus","mine_eject","mine_upgrade":
			if not b or b.building_type!=BuildingConfigs.BuildingType.MINE:return "Чужая шахта."
			if action=="mine_eject":b.eject_all_miners(game.grid_manager)
			elif action=="mine_minus":
				if not b.assigned_miners.is_empty():
					var u: Unit=b.assigned_miners.pop_back();u.ungarrison_from_building(game.production_system.spawn_position(b,false))
			elif action=="mine_upgrade":
				if b.level==1 and FactionEconomy.spend(faction,{"stone":40,"wood":20}):b.upgrade_mine()
			else:
				var candidates: Array=game.all_units.filter(func(u):return u.faction==faction and UnitConfigs.is_worker(u.unit_type) and u.mining_building_id=="" and not is_instance_valid(u.embarked_in))
				candidates.sort_custom(func(a,d):return a.position.distance_squared_to(b.position)<d.position.distance_squared_to(b.position))
				if b.assigned_miners.size()>=b.max_miners or candidates.is_empty():return "Нет свободного рабочего."
				var u: Unit=candidates[0]
				if not u.get_meta("mining_tool",false) and not FactionEconomy.spend(faction,{"pickaxe":1}):return "Изготовьте кирку."
				u.set_meta("mining_tool",true);game.selection_system.cancel_assignments(u);b.assigned_miners.append(u);u.mining_building_id=str(b.get_instance_id());u.target=b;u.current_order=UnitConfigs.UnitOrder.MOVE;u.set_path(game.grid_manager.find_unit_path(u,b.position,true));u.state=UnitConfigs.UnitState.MOVING
		"stop","hold","carry","unload","exit_cave":
			if units.is_empty():return "Приказ относится только к вашим юнитам."
			for u in units:
				if action=="unload":game.transport_system.unload(u);continue
				if action=="exit_cave":game.underground_system.request_exit(u);continue
				game.selection_system.cancel_assignments(u);u.target=null;u.stop();u.current_order=UnitConfigs.UnitOrder.MOVE
				if action=="hold":u.current_order=UnitConfigs.UnitOrder.HOLD_POSITION;u.hold_position_anchor=u.position;u.state=UnitConfigs.UnitState.DEFENDING
				elif action=="carry" and u.inventory.amount>0:u.current_order=UnitConfigs.UnitOrder.GATHER;game.gathering_system._send_to_storage(u)
		"context":
			var point: Vector3=_point(c.get("point"))
			if point==Vector3.INF:return "Неверная координата."
			if units.is_empty():
				if b:game.production_system.set_rally(b,point);return ""
				return "Выберите свои юниты."
			if c.get("mode")=="patrol":
				for u in units:
					game.selection_system.cancel_assignments(u);u.patrol_start=u.position;u.patrol_end=point;u.current_order=UnitConfigs.UnitOrder.PATROL;u.target=null;u.set_path(game.grid_manager.find_unit_path(u,point,true));u.state=UnitConfigs.UnitState.MOVING
			elif c.get("mode")=="underground":
				var cell:=Vector2i(point.x,point.z)
				for u in units:
					if u.underground_unit and game.underground_system.caves.any(func(cave):return (cell-cave.entry).length_squared()<=2):game.underground_system.request_exit(u)
					else:game.underground_system.issue_order(u,cell)
			else:
				var target: Node3D=entities.get(int(c.get("target",0)))
				if not target:target=resource_nodes.get(str(c.get("resource","")))
				if target and (target is Unit or target is Building) and target.faction!=faction and not FactionRules.hostile(faction,target.faction):return "Союзников атаковать нельзя."
				var selection: SelectionSystem=game.selection_system;var previous: Array[Unit]=selection.selected_units
				selection.selected_units=units;selection.command_faction=faction
				if target is Building and target.faction==faction and not target.is_constructed:
					for u in units:
						if UnitConfigs.is_worker(u.unit_type):selection.cancel_assignments(u);u.target=target;u.current_order=UnitConfigs.UnitOrder.BUILD;u.set_path(game.grid_manager.find_unit_path(u,target.position,true));u.state=UnitConfigs.UnitState.MOVING
				else:selection.handle_right_click({"collider":target},point)
				selection.selected_units=previous;selection.command_faction="player"
		_:return "Неизвестный приказ."
	return ""
func _place(faction: String,units: Array[Unit],c: Dictionary) -> String:
	var type: int=int(c.get("type",-1));var cell=c.get("cell")
	if not BuildingConfigs.BuildingType.values().has(type) or not cell is Vector2i:return "Неверная постройка."
	var config: Dictionary=BuildingConfigs.get_config(type);var rotation: int=posmod(int(c.get("rotation",0)),360)
	if rotation%90!=0:return "Неверный поворот."
	var fp: Vector2i=config.footprint
	if rotation in [90,270]:fp=Vector2i(fp.y,fp.x)
	if not game.grid_manager.is_area_buildable(cell.x,cell.y,fp.x,fp.y,false):return "Площадка занята или неровная."
	var center:=Vector3(cell.x+fp.x*.5,game.grid_manager.get_height(cell.x,cell.y),cell.y+fp.y*.5)
	if not game.all_units.any(func(u):return u.is_alive and u.faction==faction and u.position.distance_squared_to(center)<256):return "Сначала разведайте место своими юнитами."
	if type==BuildingConfigs.BuildingType.PORT and not game.grid_manager.is_coastal_site(cell.x,cell.y,fp.x,fp.y):return "Порт строится у воды."
	for u in game.all_units:
		if u.is_alive and not u.underground_unit and not u.embarked_in and Rect2(Vector2(cell),Vector2(fp)).has_point(Vector2(u.position.x,u.position.z)):return "На площадке стоит юнит."
	if not FactionEconomy.spend(faction,config.cost):return "Недостаточно ресурсов."
	var b:=Building.new();b.faction=faction;game.buildings_container.add_child(b);b.init_building(type,cell.x,cell.y,false,rotation,fp);b.position=center;b.rotation.y=deg_to_rad(rotation)
	game.all_buildings.append(b);game.construction_system.buildings.append(b);game.grid_manager.occupy_area(cell.x,cell.y,fp.x,fp.y,b,b.is_gate);game.fog_system.apply_world_materials(b);node_id(b)
	var workers: Array=units.filter(func(u):return UnitConfigs.is_worker(u.unit_type))
	if workers.is_empty():workers=game.all_units.filter(func(u):return u.faction==faction and UnitConfigs.is_worker(u.unit_type) and u.state==UnitConfigs.UnitState.IDLE)
	for u in workers:
		var route: Array[Vector3]=game.grid_manager.find_unit_path(u,b.position,true)
		if route.is_empty():continue
		game.selection_system.cancel_assignments(u);u.target=b;u.current_order=UnitConfigs.UnitOrder.BUILD;u.set_path(route);u.state=UnitConfigs.UnitState.MOVING;break
	return ""

func _zone_rows(faction: String) -> Array:
	var rows: Array=[]
	for z in game.lumber_zone_system.zones:
		if z.faction==faction:rows.append([z.id,z.center,z.radius,z.assigned_workers.filter(func(u):return is_instance_valid(u)).map(func(u):return node_id(u))])
	return rows
func _apply_zones(rows: Array) -> void:
	NetworkManager.applying_command=true
	var keep: Array=[]
	for row in rows:
		keep.append(row[0]);var zone=null
		for z in game.lumber_zone_system.zones:
			if z.id==row[0]:zone=z;break
		if zone==null:zone=game.lumber_zone_system.create_zone(row[1],row[2],game.all_units);zone.id=row[0]
		zone.assigned_workers.clear()
		for id in row[3]:
			if is_instance_valid(entities.get(id)):zone.assigned_workers.append(entities[id])
	for zone in game.lumber_zone_system.zones.duplicate():
		if not keep.has(zone.id):game.lumber_zone_system.delete_zone(zone)
	NetworkManager.applying_command=false
