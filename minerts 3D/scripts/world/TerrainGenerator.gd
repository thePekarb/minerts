class_name TerrainGenerator
extends Node3D

const CHUNK_SIZE: int = 16
const CHUNKS_X: int = GridManager.GRID_SIZE / CHUNK_SIZE
const CHUNKS_Z: int = GridManager.GRID_SIZE / CHUNK_SIZE
const GRID_SIZE: int = GridManager.GRID_SIZE # CHUNK_SIZE * CHUNKS_X

@export var noise_seed: int = 1337
var chunks: Array[TerrainChunk] = []
var tiles_cache: Array = []
var world_info: Dictionary = {}

func get_height_at(x: float, z: float) -> float:
	var ix: int = int(floor(x))
	var iz: int = int(floor(z))
	if ix >= 0 and ix < GRID_SIZE and iz >= 0 and iz < GRID_SIZE and not tiles_cache.is_empty():
		return float(tiles_cache[ix][iz].height)
	return 0.0

func generate_terrain(grid_mgr: GridManager) -> Array:
	# Blender exports the exact editable island mesh as a compact heightfield.
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/frontier/island.json"))
	world_info=data
	if data.get("size", 0) == GRID_SIZE and data.get("heights", []).size() == GRID_SIZE * GRID_SIZE:
		var authored_tiles: Array = []
		for x in range(GRID_SIZE):
			authored_tiles.append([])
			for z in range(GRID_SIZE):
				var index: int = z * GRID_SIZE + x
				var h: int = int(data.heights[index])
				authored_tiles[x].append(Tile.new(x, z, h, int(data.biomes[index]) as Tile.Biome, h > 0))
		tiles_cache = authored_tiles
		_build_chunks(authored_tiles)
		grid_mgr.init_grid(authored_tiles)
		return authored_tiles
	return _generate_fallback(grid_mgr)

func _generate_fallback(grid_mgr: GridManager) -> Array:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.022
	noise.fractal_octaves = 4

	var center_x: float = float(GRID_SIZE) * 0.5 # 64.0
	var center_z: float = float(GRID_SIZE) * 0.5 # 64.0
	var island_radius: float = float(GRID_SIZE) * 0.45 # ~57.6 tiles

	var tiles: Array = []
	for x in range(GRID_SIZE):
		tiles.append([])
		for z in range(GRID_SIZE):
			# Radial island falloff
			var dist_to_center: float = Vector2(float(x) - center_x, float(z) - center_z).length()
			var norm_dist: float = dist_to_center / island_radius
			var falloff: float = clampf(1.0 - pow(norm_dist, 2.5), 0.0, 1.0)

			var n: float = (noise.get_noise_2d(float(x), float(z)) + 1.0) * 0.5
			var raw_h: float = n * falloff * 6.5

			var h: int = int(round(raw_h))

			# Central base clearing flat at height 2
			if absi(x - GridManager.CENTER) <= 6 and absi(z - GridManager.CENTER) <= 6:
				h = 2

			# Highlands altars plateaus at height 3
			for altar_pt in RaidSystem.ALTAR_POSITIONS:
				if absi(x - altar_pt.x) <= 2 and absi(z - altar_pt.y) <= 2:
					h = maxi(h, 3)

			var biome: Tile.Biome = Tile.Biome.PLAINS
			var walkable: bool = true

			if h <= 0:
				biome = Tile.Biome.WATER
				walkable = false
				h = 0
			elif h == 1:
				biome = Tile.Biome.SAND
			elif h >= 4:
				biome = Tile.Biome.ROCK
			else:
				# Forest or Plains
				var f_noise: float = noise.get_noise_2d(float(x + 500), float(z + 500))
				biome = Tile.Biome.FOREST if f_noise > 0.08 else Tile.Biome.PLAINS

			var tile: Tile = Tile.new(x, z, h, biome, walkable)
			tiles[x].append(tile)

	tiles_cache = tiles

	# Build modular chunks
	_build_chunks(tiles)
	grid_mgr.init_grid(tiles)
	return tiles

func _build_chunks(tiles: Array) -> void:
	for c in chunks:
		if is_instance_valid(c):
			c.queue_free()
	chunks.clear()

	var biome_colors: Dictionary = {
		Tile.Biome.WATER: Color("285e69"),
		Tile.Biome.SAND: Color("c2b483"),
		Tile.Biome.PLAINS: Color("799557"),
		Tile.Biome.FOREST: Color("4e754a"),
		Tile.Biome.ROCK: Color("7b8582"),
		Tile.Biome.SNOW: Color("d7e1dd"),
		Tile.Biome.MARSH: Color("617c64")
	}

	for cx in range(CHUNKS_X):
		for cz in range(CHUNKS_Z):
			var land: bool = false
			for x in range(cx*CHUNK_SIZE,(cx+1)*CHUNK_SIZE):
				for z in range(cz*CHUNK_SIZE,(cz+1)*CHUNK_SIZE):
					if tiles[x][z].height>0: land=true; break
				if land: break
			if not land: continue
			var chunk: TerrainChunk = TerrainChunk.new()
			chunk.init_chunk(cx, cz)
			add_child(chunk)
			chunk.build_chunk_mesh(tiles, biome_colors)
			chunks.append(chunk)
