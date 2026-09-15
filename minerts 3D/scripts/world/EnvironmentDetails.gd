class_name EnvironmentDetails
extends Node3D

# Decorative Blender meshes are instanced in 16x16 groups for frustum culling.
func populate(grid: GridManager) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7391
	var groups: Dictionary = {}
	for x in range(3, GridManager.GRID_SIZE - 3):
		for z in range(3, GridManager.GRID_SIZE - 3):
			var tile: Tile = grid.get_tile(x, z)
			if not tile.walkable or tile.building_id != "" or Vector2(x - GridManager.CENTER, z - GridManager.CENTER).length() < 5.0:
				continue
			if rng.randf() > 0.21:
				continue
			var prop: String = "grass"
			match tile.biome:
				Tile.Biome.FOREST: prop = "fern" if rng.randf() < 0.7 else "stump"
				Tile.Biome.PLAINS: prop = "grass" if rng.randf() < 0.8 else "flowers"
				Tile.Biome.ROCK, Tile.Biome.SNOW, Tile.Biome.SAND: prop = "rock"
				Tile.Biome.MARSH: prop = "fern"
			var key: String = "%d_%d_%s" % [int(x / 16), int(z / 16), prop]
			if not groups.has(key):
				groups[key] = {"prop": prop, "transforms": []}
			var basis: Basis = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.65, 1.25))
			groups[key].transforms.append(Transform3D(basis, Vector3(x + rng.randf(), tile.height + 0.01, z + rng.randf())))
	for group in groups.values():
		var source: Node3D = FrontierAssets.instantiate_asset("prop_" + group.prop)
		if source == null:
			continue
		_add_mesh_batches(source, Transform3D.IDENTITY, group.transforms)
		source.free()
	var water: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(GridManager.GRID_SIZE + 60, GridManager.GRID_SIZE + 60)
	plane.subdivide_width = 100
	plane.subdivide_depth = 100
	water.mesh = plane
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://assets/shaders/water.gdshader")
	water.material_override = material
	water.position = Vector3(GridManager.GRID_SIZE * 0.5, 0.16, GridManager.GRID_SIZE * 0.5)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

func _add_mesh_batches(node: Node3D, parent_transform: Transform3D, placements: Array) -> void:
	var local_transform: Transform3D = parent_transform * node.transform
	if node is MeshInstance3D:
		var batch: MultiMeshInstance3D = MultiMeshInstance3D.new()
		var multimesh: MultiMesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = node.mesh
		multimesh.instance_count = placements.size()
		for i in range(placements.size()):
			multimesh.set_instance_transform(i, placements[i] * local_transform)
		batch.multimesh = multimesh
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.visibility_range_end = 85.0
		batch.visibility_range_end_margin = 8.0
		add_child(batch)
	for child in node.get_children():
		if child is Node3D:
			_add_mesh_batches(child, local_transform, placements)
