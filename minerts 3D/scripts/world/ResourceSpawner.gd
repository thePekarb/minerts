class_name ResourceSpawner
extends Node3D

@export var tree_scene: PackedScene
@export var bush_scene: PackedScene
@export var chest_scene: PackedScene

var resources: Dictionary = {} # id -> node
var pois: Dictionary = {}

func spawn_world_resources(grid_mgr: GridManager, container: Node3D) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42

	var res_counter: int = 0

	for x in range(4, GridManager.GRID_SIZE - 4):
		for z in range(4, GridManager.GRID_SIZE - 4):
			# Leave central base clearing free (around 64, 64)
			if (absi(x - GridManager.CENTER) <= 9 and absi(z - GridManager.CENTER) <= 9) or (absi(x-402)<=19 and absi(z-80)<=19):
				continue

			# Leave altar areas free (radius 3 around each altar)
			var near_altar: bool = false
			for altar_pt in RaidSystem.ALTAR_POSITIONS:
				if absi(x - altar_pt.x) <= 3 and absi(z - altar_pt.y) <= 3:
					near_altar = true
					break
			if near_altar:
				continue

			var tile: Tile = grid_mgr.get_tile(x, z)
			if not tile or not tile.walkable:
				continue

			# Keep approach valleys and river crossings navigable.
			if absi(x - GridManager.CENTER) <= 2 or absi(z - GridManager.CENTER) <= 2 or (absi(x-402)<=2 or absi(z-80)<=2):
				continue

			if tile.biome == Tile.Biome.FOREST or tile.biome == Tile.Biome.MARSH:
				if x % 2 == 0 and z % 2 == 0 and rng.randf() < 0.65:
					var species: String = ["pine", "oak", "birch", "autumn"][rng.randi_range(0, 3)]
					if tile.height >= 5:
						species = "pine"
					var tree_body: StaticBody3D = StaticBody3D.new()
					tree_body.name = "Tree_%d" % res_counter
					tree_body.collision_layer = 8
					tree_body.collision_mask = 0

					# Visuals
					var tree_mesh: Node3D = VoxelMeshFactory.create_tree_mesh(species)
					tree_mesh.rotation.y = rng.randf() * TAU
					tree_mesh.scale = Vector3.ONE * rng.randf_range(0.85, 1.25)
					tree_body.add_child(tree_mesh)

					# Physics Collision Shape for raycasting and selection
					var col: CollisionShape3D = CollisionShape3D.new()
					var box: BoxShape3D = BoxShape3D.new()
					box.size = Vector3(1.2, 2.6, 1.2)
					col.shape = box
					col.position = Vector3(0, 1.3, 0)
					tree_body.add_child(col)

					var tree_pos: Vector3 = Vector3(float(x) + 0.5, float(tile.height), float(z) + 0.5)
					tree_body.position = tree_pos
					tree_body.set_meta("resource_type", "wood")
					tree_body.set_meta("resource_amount", 50)
					tree_body.set_meta("health", 5.0)
					tree_body.set_meta("max_health", 5.0)
					tree_body.set_meta("grid_x", x)
					tree_body.set_meta("grid_z", z)
					tree_body.set_meta("res_id", tree_body.name)

					container.add_child(tree_body)
					tile.resource_id = tree_body.name
					tile.walkable = false
					resources[tree_body.name] = tree_body
					res_counter += 1

			elif tile.biome == Tile.Biome.PLAINS:
				if rng.randf() < 0.035:
					var bush_body: StaticBody3D = StaticBody3D.new()
					bush_body.name = "Bush_%d" % res_counter
					bush_body.collision_layer = 8
					bush_body.collision_mask = 0

					var bush_mesh: Node3D = VoxelMeshFactory.create_bush_mesh()
					bush_body.add_child(bush_mesh)

					var col: CollisionShape3D = CollisionShape3D.new()
					var box: BoxShape3D = BoxShape3D.new()
					box.size = Vector3(1.0, 1.0, 1.0)
					col.shape = box
					col.position = Vector3(0, 0.5, 0)
					bush_body.add_child(col)

					bush_body.position = Vector3(float(x) + 0.5, float(tile.height), float(z) + 0.5)
					bush_body.set_meta("resource_type", "food")
					bush_body.set_meta("resource_amount", 30)
					bush_body.set_meta("health", 4.0)
					bush_body.set_meta("max_health", 4.0)
					bush_body.set_meta("grid_x", x)
					bush_body.set_meta("grid_z", z)
					bush_body.set_meta("res_id", bush_body.name)

					container.add_child(bush_body)
					tile.resource_id = bush_body.name
					tile.walkable = false
					resources[bush_body.name] = bush_body
					res_counter += 1

	# Spawn 4 POI Treasure Chests across island
	var chest_coords: Array[Vector2i] = [
		Vector2i(52, 52),
		Vector2i(140, 52),
		Vector2i(52, 140),
		Vector2i(140, 140)
	]

	var world_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/frontier/island.json"))
	for coords in world_data.get("treasures",[]):
		var position: Vector3 = grid_mgr.find_free_position(Vector3(coords[0],0,coords[1]))
		chest_coords.append(Vector2i(floori(position.x),floori(position.z)))
	for i in range(chest_coords.size()):
		var c_pos: Vector2i = chest_coords[i]
		var t: Tile = grid_mgr.get_tile(c_pos.x, c_pos.y)
		if t and t.walkable and t.resource_id == "":
			var chest_body: StaticBody3D = StaticBody3D.new()
			chest_body.name = "Chest_%d" % i
			chest_body.collision_layer = 8
			chest_body.collision_mask = 0

			var chest_mesh: Node3D = VoxelMeshFactory.create_chest_mesh()
			chest_body.add_child(chest_mesh)

			var col: CollisionShape3D = CollisionShape3D.new()
			var box: BoxShape3D = BoxShape3D.new()
			box.size = Vector3(0.9, 0.8, 0.7)
			col.shape = box
			col.position = Vector3(0, 0.4, 0)
			chest_body.add_child(col)

			chest_body.position = Vector3(float(c_pos.x) + 0.5, float(t.height), float(c_pos.y) + 0.5)
			chest_body.set_meta("poi_type", "chest")
			chest_body.set_meta("opened", false)
			chest_body.set_meta("loot", {"wood": 50, "stone": 40, "food": 50, "ore": 20})
			container.add_child(chest_body)
			pois[chest_body.name] = chest_body
			t.resource_id = chest_body.name
			t.walkable = false

func remove_resource(node: Node) -> void:
	if node and resources.has(node.name):
		resources.erase(node.name)
