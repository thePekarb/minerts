class_name UnitSpatialIndex
extends RefCounted

# One broad-phase snapshot per physics frame, shared by all local movement queries.
# Exact distance, life state and movement layer are checked by the caller.
const CELL_SIZE: float = 6.0
var buckets: Dictionary = {}
var snapshot_frame: int = -1
var rebuilds: int = 0
var candidates_examined: int = 0

func invalidate() -> void:
	snapshot_frame = -1

func rebuild(units: Array) -> void:
	buckets.clear()
	for unit in units:
		if not is_instance_valid(unit) or not unit.is_alive:
			continue
		var cell := Vector2i(floori(unit.position.x / CELL_SIZE), floori(unit.position.z / CELL_SIZE))
		if not buckets.has(cell):
			buckets[cell] = []
		buckets[cell].append(unit)
	snapshot_frame = Engine.get_physics_frames()
	rebuilds += 1

func query(tree: SceneTree, point: Vector3, radius: float) -> Array[Unit]:
	if snapshot_frame != Engine.get_physics_frames():
		rebuild(tree.get_nodes_in_group("units"))
	var result: Array[Unit] = []
	# Include a neighboring cell beyond the snapshot radius: actors can move during
	# this physics frame, before the next snapshot. Narrow-phase uses live positions.
	var extent: float = radius + 1.0
	for x in range(floori((point.x-extent)/CELL_SIZE), floori((point.x+extent)/CELL_SIZE)+1):
		for z in range(floori((point.z-extent)/CELL_SIZE), floori((point.z+extent)/CELL_SIZE)+1):
			for unit in buckets.get(Vector2i(x,z), []):
				candidates_examined += 1
				if is_instance_valid(unit):
					result.append(unit)
	return result
