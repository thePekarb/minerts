class_name GroupNavigation
extends RefCounted

const MAX_JOBS: int = 4
var grid: GridManager
var jobs: Array[Dictionary] = []
var fields_built: int = 0
var shared_routes: int = 0
var canceled_orders: int = 0
var last_tick_usec: int = 0

func _init(owner: GridManager) -> void:grid=owner

func enqueue(units: Array[Unit], targets: Array[Vector3]) -> void:
	var requests: Array[Dictionary] = []
	for i in range(units.size()):
		var unit: Unit = units[i]
		unit.set_path([]);unit.velocity=Vector3.ZERO
		unit.destination=targets[i]
		requests.append({"unit":weakref(unit),"version":unit.route_version,"goal":targets[i]})
	# Keep requests when the field budget is full, but turn older jobs into
	# individually scheduled fallbacks so no order is silently dropped.
	if jobs.size()>=MAX_JOBS:
		for job in jobs:job.field=null;job.fallback=true
		jobs[0].requests.append_array(requests)
	else:
		jobs.append({"requests":requests,"field":null,"fallback":false,"revision":grid.terrain_revision,"wait_ticks":0})

func tick(budget_usec: int = 2000) -> void:
	var begin: int = Time.get_ticks_usec()
	while not jobs.is_empty() and Time.get_ticks_usec()-begin<budget_usec:
		var job: Dictionary = jobs[0]
		job.requests=job.requests.filter(_valid_request)
		if job.requests.is_empty():jobs.pop_front();continue
		if job.revision!=grid.terrain_revision:
			job.field=null;job.revision=grid.terrain_revision
		if not job.fallback and job.field==null:
			if not grid.hierarchy.dirty.is_empty():
				job.wait_ticks+=1
				if job.wait_ticks<30:break
				job.fallback=true
			else:
				var origins: Array[int] = []
				for request in job.requests:
					var unit: Unit = request.unit.get_ref()
					origins.append(grid.get_point_id(floori(unit.position.x),floori(unit.position.z)))
				var target: Vector3 = job.requests[0].goal
				var goal: int = grid.get_point_id(floori(target.x),floori(target.z))
				job.field=GroupFlowField.new(grid,goal,origins);fields_built+=1
		if job.field!=null and not job.field.ready:
			job.field.advance(maxi(100,budget_usec-(Time.get_ticks_usec()-begin)))
			break
		var request: Dictionary = job.requests.pop_front()
		var unit: Unit = request.unit.get_ref()
		var route: Array[Vector3] = []
		if job.field!=null:
			var origin: int = grid.get_point_id(floori(unit.position.x),floori(unit.position.z))
			route=job.field.route(origin,request.goal,20.0)
			if not route.is_empty():shared_routes+=1
		if route.is_empty():route=grid.find_unit_path(unit,request.goal)
		unit.set_path(route)
		unit.state=UnitConfigs.UnitState.MOVING if not route.is_empty() else UnitConfigs.UnitState.IDLE
	last_tick_usec=Time.get_ticks_usec()-begin

func _valid_request(request: Dictionary) -> bool:
	var unit: Unit = request.unit.get_ref()
	var valid: bool = is_instance_valid(unit) and unit.is_alive and unit.route_version==request.version and not unit.underground_unit and not is_instance_valid(unit.embarked_in) and unit.current_order==UnitConfigs.UnitOrder.MOVE
	if not valid:canceled_orders+=1
	return valid
