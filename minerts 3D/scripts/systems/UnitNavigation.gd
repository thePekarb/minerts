class_name UnitNavigation
extends RefCounted

# Shared by villagers, combatants, wildlife and ships. Orders remain owned by their systems.
var unit: Unit
var waiting_for_gate: bool = false
var yield_steps: int = 0
var retry_after: float = 0.0
var stalled_for: float = 0.0
var best_distance: float = INF
var watched_point: Vector3 = Vector3.INF
var recovery_count: int = 0
var actual_speed: float = 0.0
var nearby: Array[Unit] = []
var neighbors_timer: float = 0.0
var yield_return: Vector3 = Vector3.INF
var yield_return_delay: float = 0.0
var steering_timer: float = 0.0
var steering_point: Vector3 = Vector3.INF
var steering_velocity: Vector3 = Vector3.ZERO

func _init(owner: Unit) -> void:
	unit = owner
	neighbors_timer=float(unit.get_instance_id()%13)*.01

func reset_progress() -> void:
	waiting_for_gate=false;yield_steps=0
	watched_point = Vector3.INF
	best_distance = INF
	stalled_for = 0.0
	recovery_count = 0
	retry_after = 0.0
	yield_return = Vector3.INF

func tick(delta: float) -> void:
	steering_timer=maxf(0,steering_timer-delta)
	retry_after = maxf(0.0, retry_after - delta)
	if yield_return!=Vector3.INF:
		yield_return_delay=maxf(0,yield_return_delay-delta)
		if yield_return_delay<=0 and unit.path.is_empty() and unit.state==UnitConfigs.UnitState.IDLE:
			yield_return_delay=1.0
			# Start approaching even when a displaced ally occupies the slot. Waiting
			# for it to become empty would deadlock cyclic exchanges of positions.
			var goal: Vector3 = yield_return
			var route: Array[Vector3] = unit.grid_manager.find_unit_path(unit,goal,true)
			if not route.is_empty():
				unit.set_path(route);unit.state=UnitConfigs.UnitState.MOVING
	if unit.path.is_empty() or not unit.is_alive or unit.state==UnitConfigs.UnitState.MINING_INSIDE:return
	neighbors_timer -= delta
	if neighbors_timer <= 0.0:
		neighbors_timer = 0.15
		nearby.clear()
		if not is_instance_valid(unit.grid_manager):return
		for other in unit.grid_manager.unit_index.query(unit.get_tree(), unit.position, 6.0):
			if other != unit and same_layer(other) and unit.position.distance_squared_to(other.position) < 36.0:
				nearby.append(other)
		nearby.sort_custom(func(a,b):return a.position.distance_squared_to(unit.position)<b.position.distance_squared_to(unit.position))
		if nearby.size()>12:nearby.resize(12)

func same_layer(other: Variant) -> bool:
	return is_instance_valid(other) and other.is_alive and not is_instance_valid(other.embarked_in) and other.state != UnitConfigs.UnitState.MINING_INSIDE and other.underground_unit == unit.underground_unit and UnitConfigs.is_vessel(other.unit_type) == UnitConfigs.is_vessel(unit.unit_type) and absf(other.position.y-unit.position.y)<1.3

func observe(point: Vector3, delta: float) -> void:
	var distance: float = Vector2(point.x-unit.position.x,point.z-unit.position.z).length()
	if point.distance_squared_to(watched_point) > 0.02:
		watched_point=point;best_distance=distance;stalled_for=0.0
	if distance < best_distance-0.08:
		best_distance=distance;stalled_for=0.0;recovery_count=0
	else:stalled_for+=delta
	if stalled_for>=0.9 and retry_after<=0.0:
		recover()

func steer(point: Vector3, delta: float) -> Vector3:
	if steering_timer>0 and steering_point.distance_squared_to(point)<.001:
		var remaining: float = Vector2(point.x-unit.position.x,point.z-unit.position.z).length()
		var cached: Vector3 = steering_velocity.limit_length(remaining/delta)
		if unit.grid_manager.motion_clear(unit,unit.position,unit.position+cached*delta):return cached
	steering_timer=.08+float(unit.get_instance_id()%4)*.01
	steering_point=point
	steering_velocity=_compute_steering(point,delta)
	return steering_velocity

func _compute_steering(point: Vector3, delta: float) -> Vector3:
	var offset: Vector3 = point-unit.position;offset.y=0
	var distance: float = offset.length()
	if distance < 0.02:return Vector3.ZERO
	var forward: Vector3 = offset/distance
	var max_speed: float = minf(unit.speed,distance/delta)
	var desired: Vector3 = forward*max_speed
	var look_time: float = minf(0.25,distance/max_speed)
	var clear_ahead: bool = true
	for other in nearby:
		if not same_layer(other):continue
		var relative: Vector3 = other.position-unit.position;relative.y=0
		var relative_velocity: Vector3 = desired-other.velocity;relative_velocity.y=0
		var t: float = clampf(relative.dot(relative_velocity)/maxf(relative_velocity.length_squared(),0.001),0,look_time)
		if (relative-relative_velocity*t).length()<unit.navigation_radius+other.navigation_radius+0.20:clear_ahead=false;break
	if clear_ahead and unit.grid_manager.motion_clear(unit,unit.position,unit.position+desired*look_time) and not unit.test_move(unit.global_transform,desired*delta):return desired
	var best: Vector3 = Vector3.ZERO
	var best_score: float = -INF
	# Consistent right-hand passing prevents symmetric left/right oscillation.
	for angle in [0.0,-0.55,0.55,-1.05,1.05,-1.55,1.55,-2.1,2.1]:
		var direction: Vector3 = forward.rotated(Vector3.UP,angle)
		var candidate: Vector3 = direction*max_speed
		var next: Vector3 = unit.position+candidate*delta
		if not unit.grid_manager.motion_clear(unit,unit.position,next):continue
		if unit.test_move(unit.global_transform,candidate*delta):continue
		var score: float = forward.dot(direction)*2.0-absf(angle)*0.10
		if angle<0:score+=0.06
		var horizon: float = minf(0.3,distance/max_speed)
		var ahead: Vector3 = unit.position+candidate*horizon
		if not unit.grid_manager.motion_clear(unit,unit.position,ahead):score-=2.5
		for other in nearby:
			if not same_layer(other):continue
			var relative: Vector3 = other.position-unit.position;relative.y=0
			var relative_velocity: Vector3 = candidate-other.velocity;relative_velocity.y=0
			var t: float = clampf(relative.dot(relative_velocity)/maxf(relative_velocity.length_squared(),0.001),0.0,horizon)
			var gap: float = (relative-relative_velocity*t).length()
			var clearance: float = unit.navigation_radius+other.navigation_radius+0.10
			if gap<clearance:score-=8.0*(1.0-gap/clearance)
		if score>best_score:best_score=score;best=candidate
	return best if best_score>-1.5 else Vector3.ZERO

func recover() -> void:
	retry_after=0.75+minf(recovery_count*0.25,1.5)
	stalled_for=0.0;recovery_count+=1
	# Ask an idle ally to clear a doorway without changing anyone's work/attack target.
	for other in nearby:
		if same_layer(other) and other.faction==unit.faction and ((other.state==UnitConfigs.UnitState.IDLE and other.path.is_empty() and other.current_order in [UnitConfigs.UnitOrder.MOVE,UnitConfigs.UnitOrder.PATROL]) or other.navigation.waiting_for_gate) and other.position.distance_to(unit.position)<(3.2 if waiting_for_gate else 1.6):
			_yield_idle(other)
	if is_instance_valid(unit.target) and unit.current_order in [UnitConfigs.UnitOrder.ATTACK,UnitConfigs.UnitOrder.GATHER,UnitConfigs.UnitOrder.BUILD,UnitConfigs.UnitOrder.INTERACT]:
		var approach: Array[Vector3] = unit.grid_manager.find_interaction_path(unit,unit.target,unit.grid_manager.interaction_reach(unit))
		if not approach.is_empty():
			unit.path=approach;unit.destination=approach.back();unit.waypoint_index=0;watched_point=Vector3.INF
			return
	for other in nearby:
		if same_layer(other) and other.position.distance_to(unit.position)<1.5 and unit.get_instance_id()>other.get_instance_id() and not waiting_for_gate:
			if _side_step():return
	var route: Array[Vector3] = unit.grid_manager.find_interaction_path(unit,unit.target,unit.grid_manager.interaction_reach(unit)) if is_instance_valid(unit.target) and unit.current_order in [UnitConfigs.UnitOrder.ATTACK,UnitConfigs.UnitOrder.GATHER,UnitConfigs.UnitOrder.BUILD,UnitConfigs.UnitOrder.INTERACT] else unit.grid_manager.find_unit_path(unit,unit.destination,true)
	if not route.is_empty():
		unit.path=route;unit.destination=route.back();unit.waypoint_index=0;watched_point=Vector3.INF
	# A temporarily blocked route keeps its order and retries at bounded intervals.

func _yield_idle(other: Unit) -> void:
	var obstructs: bool = false
	for i in range(unit.waypoint_index,mini(unit.path.size(),unit.waypoint_index+4)):
		if other.position.distance_to(unit.path[i])<unit.navigation_radius+other.navigation_radius+.14:obstructs=true;break
	if not obstructs:return
	var best: Vector3 = Vector3.INF
	var cost: float = INF
	for dx in range(-2,3):
		for dz in range(-2,3):
			var p: Vector3 = Vector3(floorf(other.position.x)+dx+0.5,other.position.y,floorf(other.position.z)+dz+0.5)
			if p.distance_to(unit.position)<1.3 or not unit.grid_manager._navigation_cell_open(other,p):continue
			if not unit.grid_manager.unit_position_free(other,p):continue
			var on_route: bool = false
			for index in range(unit.waypoint_index,mini(unit.path.size(),unit.waypoint_index+5)):
				if p.distance_to(unit.path[index])<0.8:on_route=true;break
			if on_route:continue
			if p.distance_squared_to(other.position)<cost and not unit.grid_manager.find_unit_path(other,p).is_empty():best=p;cost=p.distance_squared_to(other.position)
	if best!=Vector3.INF:
		# A second request to yield must retain the original order, not the first detour.
		var previous_goal: Vector3 = other.navigation.yield_return if other.navigation.yield_return!=Vector3.INF else other.destination
		var return_to_slot: bool = (other.navigation.yield_return!=Vector3.INF or not other.navigation.waiting_for_gate) and other.current_order==UnitConfigs.UnitOrder.MOVE and previous_goal!=Vector3.INF
		var detour: Array[Vector3] = unit.grid_manager.find_unit_path(other,best)
		var steps: int = detour.size()
		if other.navigation.waiting_for_gate and not return_to_slot:
			detour.append_array(unit.grid_manager.find_path(best,other.destination,other.faction))
		other.set_path(detour)
		if return_to_slot:
			other.navigation.yield_return=previous_goal;other.navigation.yield_return_delay=1.5
		other.navigation.yield_steps=steps
		if not other.path.is_empty():other.state=UnitConfigs.UnitState.MOVING

func _side_step() -> bool:
	var forward: Vector3 = unit.destination-unit.position;forward.y=0
	forward=forward.normalized()
	for angle in [-PI/2,PI/2,PI]:
		var point: Vector3 = unit.position+forward.rotated(Vector3.UP,angle)*1.1
		point=Vector3(floorf(point.x)+0.5,unit.position.y,floorf(point.z)+0.5)
		if not unit.grid_manager.motion_clear(unit,unit.position,point) or not unit.grid_manager.unit_position_free(unit,point):continue
		if unit.test_move(unit.global_transform,point-unit.position):continue
		var tail: Array[Vector3] = unit.grid_manager.find_sea_path(point,unit.destination) if UnitConfigs.is_vessel(unit.unit_type) else unit.grid_manager.find_path(point,unit.destination,unit.faction)
		if tail.is_empty():continue
		tail.push_front(point);unit.path=tail;unit.waypoint_index=0;yield_steps=1;watched_point=Vector3.INF
		return true
	return false
