class_name TerrainGenerator
extends Node3D

const CHUNK_SIZE: int = 16
const CHUNKS_X: int = GridManager.GRID_SIZE / CHUNK_SIZE
const CHUNKS_Z: int = GridManager.GRID_SIZE / CHUNK_SIZE
const GRID_SIZE: int = GridManager.GRID_SIZE # CHUNK_SIZE * CHUNKS_X

const BIOME_COLORS: Dictionary = {
	Tile.Biome.WATER: Color("285e69"),
	Tile.Biome.SAND: Color("c2b483"),
	Tile.Biome.PLAINS: Color("799557"),
	Tile.Biome.FOREST: Color("4e754a"),
	Tile.Biome.ROCK: Color("7b8582"),
	Tile.Biome.SNOW: Color("d7e1dd"),
	Tile.Biome.MARSH: Color("617c64")
}

@export var noise_seed: int = 1337
var chunks: Array[TerrainChunk] = []
var chunk_map: Dictionary = {}
var tiles_cache: Array = []
var world_info: Dictionary = {}

func get_height_at(x: float, z: float) -> float:
	var ix: int = int(floor(x))
	var iz: int = int(floor(z))
	if ix >= 0 and ix < GRID_SIZE and iz >= 0 and iz < GRID_SIZE and not tiles_cache.is_empty():
		return float(tiles_cache[ix][iz].height)
	return 0.0

func generate_terrain(grid_mgr: GridManager) -> Array:
	return generate_procedural_archipelago(grid_mgr)

func generate_procedural_archipelago(grid_mgr: GridManager) -> Array:
	var n_participants: int = 5
	if Engine.has_singleton("GameSettings") or get_tree().root.has_node("GameSettings"):
		n_participants = GameSettings.get_participant_count()
	n_participants = maxi(1, n_participants)

	# 1. Island Layout: 1 Central (Crown) Island + N Participant Islands
	var crown_center := Vector2i(256, 256)
	var crown_radius: int = 88
	var crown_island: Dictionary = {
		"id": "crown",
		"name": "Crown of the Sea",
		"center": [crown_center.x, crown_center.y],
		"radius": crown_radius
	}

	# Participant islands centers
	var participant_islands: Array = []
	var participant_spawns: Array = []

	if n_participants == 5:
		# Standard 5 participant layout (preserves home at 96,96 and goblin at 402,80)
		var centers: Array = [
			Vector2i(96, 96),
			Vector2i(402, 80),
			Vector2i(86, 411),
			Vector2i(445, 437),
			Vector2i(47, 251)
		]
		for i in range(5):
			var c: Vector2i = centers[i]
			var rad: int = 54
			var isl_id: String = "home" if i == 0 else ("goblin" if i == 1 else "participant_%d" % i)
			var isl_name: String = "Frontier" if i == 0 else ("Brambleclaw" if i == 1 else "Остров %d" % (i + 1))
			participant_islands.append({
				"id": isl_id,
				"name": isl_name,
				"center": [c.x, c.y],
				"radius": rad,
				"spawn": c
			})
			participant_spawns.append(c)
	else:
		# Dynamic radial distribution for any N participants
		var base_angle: float = 5.0 * PI / 4.0 # 225 degrees -> bottom-left (96, 96)
		var orbit_dist: float = 226.0
		for i in range(n_participants):
			var angle: float = base_angle + (TAU * float(i)) / float(n_participants)
			var cx: int = int(round(float(crown_center.x) + orbit_dist * cos(angle)))
			var cz: int = int(round(float(crown_center.y) + orbit_dist * sin(angle)))
			cx = clampi(cx, 65, GRID_SIZE - 65)
			cz = clampi(cz, 65, GRID_SIZE - 65)
			var pt := Vector2i(cx, cz)
			var rad: int = 54
			var isl_id: String = "home" if i == 0 else ("goblin" if i == 1 else "participant_%d" % i)
			var isl_name: String = "Frontier" if i == 0 else ("Brambleclaw" if i == 1 else "Остров %d" % (i + 1))
			participant_islands.append({
				"id": isl_id,
				"name": isl_name,
				"center": [cx, cz],
				"radius": rad,
				"spawn": pt
			})
			participant_spawns.append(pt)

	# Full islands list: [home, crown, ...other participants]
	# Crown island at index 1 is guaranteed larger than home island at index 0
	var all_islands: Array = []
	all_islands.append(participant_islands[0])
	all_islands.append(crown_island)
	for i in range(1, participant_islands.size()):
		all_islands.append(participant_islands[i])

	# Treasures placed on the central island (Crown of the Sea)
	var treasures: Array = [
		[crown_center.x - 22, crown_center.y - 18],
		[crown_center.x + 24, crown_center.y - 20],
		[crown_center.x - 18, crown_center.y + 24],
		[crown_center.x + 22, crown_center.y + 20],
		[crown_center.x, crown_center.y]
	]

	var goblin_spawn_coord: Array = participant_islands[1]["center"] if participant_islands.size() > 1 else [crown_center.x, crown_center.y]

	world_info = {
		"size": GRID_SIZE,
		"seed": noise_seed,
		"islands": all_islands,
		"spawns": participant_spawns,
		"player_spawn": participant_islands[0]["center"],
		"goblin_spawn": goblin_spawn_coord,
		"treasures": treasures
	}

	# 2. Allocate Grid Tiles (Water by default)
	var tiles: Array = []
	for x in range(GRID_SIZE):
		tiles.append([])
		for z in range(GRID_SIZE):
			tiles[x].append(Tile.new(x, z, 0, Tile.Biome.WATER, false))

	# 3. Procedural Height and Biomes with Perlin/Simplex noise per island bounding box
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.02
	noise.fractal_octaves = 3

	for isl in all_islands:
		var cx: int = isl.center[0]
		var cz: int = isl.center[1]
		var rad: int = isl.radius
		var rad_f: float = float(rad)
		var is_crown: bool = (isl.id == "crown")

		var min_x: int = maxi(0, cx - rad)
		var max_x: int = mini(GRID_SIZE - 1, cx + rad)
		var min_z: int = maxi(0, cz - rad)
		var max_z: int = mini(GRID_SIZE - 1, cz + rad)

		for x in range(min_x, max_x + 1):
			var dx: float = float(x - cx)
			for z in range(min_z, max_z + 1):
				var dz: float = float(z - cz)
				var dist: float = sqrt(dx * dx + dz * dz)
				if dist <= rad_f:
					var norm_dist: float = dist / rad_f
					var falloff: float = clampf(1.0 - norm_dist * norm_dist, 0.0, 1.0)
					var n1: float = (noise.get_noise_2d(float(x), float(z)) + 1.0) * 0.5
					var n2: float = (noise.get_noise_2d(float(x * 2.2), float(z * 2.2)) + 1.0) * 0.5
					var raw_h: float = falloff * (n1 * 3.6 + n2 * 1.6 + 1.2)
					if is_crown:
						raw_h *= 1.3
					var h: int = int(round(raw_h))
					var tile: Tile = tiles[x][z]
					if h > tile.height:
						tile.height = h
						if h <= 0:
							tile.biome = Tile.Biome.WATER
							tile.walkable = false
						elif h == 1:
							tile.biome = Tile.Biome.SAND
							tile.walkable = true
						elif h >= 4:
							tile.biome = Tile.Biome.ROCK
							tile.walkable = true
						else:
							var f_noise: float = noise.get_noise_2d(float(x + 600), float(z + 600))
							tile.biome = Tile.Biome.FOREST if f_noise > 0.1 else Tile.Biome.PLAINS
							tile.walkable = true

	# 4. Guaranteed Base Clearings (Flat Plains at height 2) for each participant island
	for p in participant_islands:
		var cx: int = p.center[0]
		var cz: int = p.center[1]
		# Leave room for the complete production chain and one-cell walking lanes.
		for x in range(maxi(0, cx - 10), mini(GRID_SIZE, cx + 11)):
			for z in range(maxi(0, cz - 10), mini(GRID_SIZE, cz + 11)):
				var tile: Tile = tiles[x][z]
				tile.height = 2
				tile.biome = Tile.Biome.PLAINS
				tile.walkable = true
		# Smooth transition apron in radius 12
		for x in range(maxi(0, cx - 12), mini(GRID_SIZE, cx + 13)):
			for z in range(maxi(0, cz - 12), mini(GRID_SIZE, cz + 13)):
				var tile: Tile = tiles[x][z]
				tile.height = maxi(tile.height, 2)
				tile.walkable = true
				if tile.biome == Tile.Biome.WATER:
					tile.biome = Tile.Biome.PLAINS

	# 5. Highlands Altars Plateaus at height 3
	for altar_pt in RaidSystem.ALTAR_POSITIONS:
		for x in range(maxi(0, altar_pt.x - 2), mini(GRID_SIZE, altar_pt.x + 3)):
			for z in range(maxi(0, altar_pt.y - 2), mini(GRID_SIZE, altar_pt.y + 3)):
				var tile: Tile = tiles[x][z]
				if tile.height > 0:
					tile.height = maxi(tile.height, 3)
					tile.walkable = true

	tiles_cache = tiles
	_build_chunks(tiles)
	grid_mgr.init_grid(tiles)
	return tiles


func _build_chunks(tiles: Array) -> void:
	for c in chunks:
		if is_instance_valid(c):
			c.queue_free()
	chunks.clear()
	chunk_map.clear()

	for cx in range(CHUNKS_X):
		for cz in range(CHUNKS_Z):
			var land: bool = false
			for x in range(cx * CHUNK_SIZE, (cx + 1) * CHUNK_SIZE):
				for z in range(cz * CHUNK_SIZE, (cz + 1) * CHUNK_SIZE):
					if tiles[x][z].height > 0:
						land = true
						break
				if land:
					break
			if not land:
				continue
			var chunk: TerrainChunk = TerrainChunk.new()
			chunk.init_chunk(cx, cz)
			add_child(chunk)
			chunk.build_chunk_mesh(tiles, BIOME_COLORS)
			chunks.append(chunk)
			chunk_map[Vector2i(cx, cz)] = chunk

func _rebuild_chunk(cx: int, cz: int) -> void:
	var key := Vector2i(cx, cz)
	if chunk_map.has(key):
		var chunk: TerrainChunk = chunk_map[key]
		if is_instance_valid(chunk):
			chunk.build_chunk_mesh(tiles_cache, BIOME_COLORS)

func update_tile_height(gx: int, gz: int, new_height: int, grid_mgr: GridManager) -> void:
	if NetworkManager.in_match and NetworkManager.is_host() and is_instance_valid(NetworkManager.session):
		NetworkManager.session.world_changes[Vector2i(gx,gz)]=new_height
	if gx < 0 or gx >= GRID_SIZE or gz < 0 or gz >= GRID_SIZE:
		return
	if not tiles_cache.is_empty():
		tiles_cache[gx][gz].height = new_height
	if grid_mgr:
		grid_mgr.update_tile_height(gx, gz, new_height)

	var cx: int = gx / CHUNK_SIZE
	var cz: int = gz / CHUNK_SIZE
	_rebuild_chunk(cx, cz)

	if gx % CHUNK_SIZE == 0 and cx > 0:
		_rebuild_chunk(cx - 1, cz)
	elif gx % CHUNK_SIZE == CHUNK_SIZE - 1 and cx < CHUNKS_X - 1:
		_rebuild_chunk(cx + 1, cz)
	if gz % CHUNK_SIZE == 0 and cz > 0:
		_rebuild_chunk(cx, cz - 1)
	elif gz % CHUNK_SIZE == CHUNK_SIZE - 1 and cz < CHUNKS_Z - 1:
		_rebuild_chunk(cx, cz + 1)

