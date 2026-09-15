class_name TerrainChunk
extends Node3D

const CHUNK_SIZE: int = 16

var chunk_x: int = 0
var chunk_z: int = 0
var mesh_instance: MeshInstance3D = null
var static_body: StaticBody3D = null
var collision_shape: CollisionShape3D = null

func init_chunk(cx: int, cz: int) -> void:
	chunk_x = cx
	chunk_z = cz
	name = "Chunk_%d_%d" % [cx, cz]

func build_chunk_mesh(tiles: Array, biome_colors: Dictionary) -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var start_x: int = chunk_x * CHUNK_SIZE
	var start_z: int = chunk_z * CHUNK_SIZE
	var end_x: int = start_x + CHUNK_SIZE
	var end_z: int = start_z + CHUNK_SIZE
	var total_grid_x: int = tiles.size()
	var total_grid_z: int = tiles[0].size() if total_grid_x > 0 else 0

	for x in range(start_x, end_x):
		for z in range(start_z, end_z):
			var tile: Tile = tiles[x][z]
			var col: Color = biome_colors.get(tile.biome, Color("4ade80"))
			var variation: float = float((x * 73 + z * 137) % 19) / 180.0
			col = col.darkened(variation)
			st.set_color(col)

			var h: float = float(tile.height)

			# Top face
			_add_quad(st,
				Vector3(x, h, z),
				Vector3(x + 1, h, z),
				Vector3(x + 1, h, z + 1),
				Vector3(x, h, z + 1)
			)

			# Stepped side faces
			# North neighbor (z - 1)
			var n_h: float = float(tiles[x][z - 1].height) if z > 0 else 0.0
			if h > n_h:
				st.set_color(col.darkened(0.18))
				_add_quad(st,
					Vector3(x + 1, h, z),
					Vector3(x, h, z),
					Vector3(x, n_h, z),
					Vector3(x + 1, n_h, z)
				)

			# South neighbor (z + 1)
			var s_h: float = float(tiles[x][z + 1].height) if z < total_grid_z - 1 else 0.0
			if h > s_h:
				st.set_color(col.darkened(0.18))
				_add_quad(st,
					Vector3(x, h, z + 1),
					Vector3(x + 1, h, z + 1),
					Vector3(x + 1, s_h, z + 1),
					Vector3(x, s_h, z + 1)
				)

			# West neighbor (x - 1)
			var w_h: float = float(tiles[x - 1][z].height) if x > 0 else 0.0
			if h > w_h:
				st.set_color(col.darkened(0.28))
				_add_quad(st,
					Vector3(x, h, z),
					Vector3(x, h, z + 1),
					Vector3(x, w_h, z + 1),
					Vector3(x, w_h, z)
				)

			# East neighbor (x + 1)
			var e_h: float = float(tiles[x + 1][z].height) if x < total_grid_x - 1 else 0.0
			if h > e_h:
				st.set_color(col.darkened(0.28))
				_add_quad(st,
					Vector3(x + 1, h, z + 1),
					Vector3(x + 1, h, z),
					Vector3(x + 1, e_h, z),
					Vector3(x + 1, e_h, z + 1)
				)

	st.generate_normals()
	var arr_mesh: ArrayMesh = st.commit()

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.85
	arr_mesh.surface_set_material(0, mat)

	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		add_child(mesh_instance)
	mesh_instance.mesh = arr_mesh

	if not static_body:
		static_body = StaticBody3D.new()
		static_body.collision_layer = 1
		static_body.collision_mask = 0
		add_child(static_body)
		collision_shape = CollisionShape3D.new()
		static_body.add_child(collision_shape)
	collision_shape.shape = arr_mesh.create_trimesh_shape()

func _add_quad(st: SurfaceTool, p1: Vector3, p2: Vector3, p3: Vector3, p4: Vector3) -> void:
	st.add_vertex(p1)
	st.add_vertex(p2)
	st.add_vertex(p3)

	st.add_vertex(p1)
	st.add_vertex(p3)
	st.add_vertex(p4)
