class_name Minimap
extends Control

signal map_clicked(world_pos: Vector3)

var overview: bool = false
var map_origin := Vector2.ZERO
var map_span: float = 192.0
var underground_texture: ImageTexture
var raid_origins: Array[Vector3] = []
var grid_manager: GridManager
var camera: RTSCamera
var fog_system: FogOfWarSystem

var all_units_ref: Array[Unit] = []
var all_buildings_ref: Array[Building] = []

var fog_image: Image
var fog_texture: ImageTexture
var redraw_timer: float = 0.0
var terrain_texture: ImageTexture = null
var is_dragging_map: bool = false

func init_minimap(grid_mgr: GridManager, cam: RTSCamera, fog: FogOfWarSystem) -> void:
	grid_manager = grid_mgr
	camera = cam
	fog_system = fog
	_generate_terrain_texture()
	fog.visibility_updated.connect(_update_fog_texture)
	_update_fog_texture()

func _generate_terrain_texture() -> void:
	var img: Image = Image.create(GridManager.GRID_SIZE, GridManager.GRID_SIZE, false, Image.FORMAT_RGBA8)
	for z in range(GridManager.GRID_SIZE):
		for x in range(GridManager.GRID_SIZE):
			var t: Tile = grid_manager.get_tile(x, z)
			var col: Color = Color(0.2, 0.5, 0.2) # Default green
			if t:
				match t.biome:
					Tile.Biome.WATER: col = Color("285e69")
					Tile.Biome.SAND: col = Color("c2b483")
					Tile.Biome.PLAINS: col = Color("799557")
					Tile.Biome.FOREST: col = Color("4e754a")
					Tile.Biome.ROCK: col = Color("7b8582")
					Tile.Biome.SNOW: col = Color("d7e1dd")
					Tile.Biome.MARSH: col = Color("617c64")
			img.set_pixel(x, z, col)
	terrain_texture = ImageTexture.create_from_image(img)

func update_entities(units: Array[Unit], buildings: Array[Building]) -> void:
	all_units_ref = units
	all_buildings_ref = buildings


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			is_dragging_map = mb.pressed
			if mb.pressed:
				_handle_click(mb.position)
	elif event is InputEventMouseMotion and is_dragging_map:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		_handle_click(mm.position)

func _handle_click(local_pos: Vector2) -> void:
	var norm_x: float = clampf(local_pos.x / size.x, 0.0, 1.0)
	var norm_z: float = clampf(local_pos.y / size.y, 0.0, 1.0)
	var world_x: float = map_origin.x+norm_x*map_span
	var world_z: float = map_origin.y+norm_z*map_span
	var world_y: float = grid_manager.get_height(world_x, world_z) if grid_manager else 0.0
	map_clicked.emit(Vector3(world_x, world_y, world_z))

func _draw() -> void:
	map_span=512.0 if overview else 192.0
	if camera:map_origin=Vector2(clampf(camera.current_focus.x-map_span*.5,0,512-map_span),clampf(camera.current_focus.z-map_span*.5,0,512-map_span))
	# Draw background / terrain
	if is_instance_valid(camera) and camera.underground_view and underground_texture:
		draw_texture_rect_region(underground_texture,Rect2(Vector2.ZERO,size),Rect2(map_origin,Vector2.ONE*map_span))
	elif terrain_texture:
		draw_texture_rect_region(terrain_texture,Rect2(Vector2.ZERO,size),Rect2(map_origin,Vector2.ONE*map_span))
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.12, 0.15))

	var scale_x: float = size.x / map_span
	var scale_y: float = size.y / map_span

	if fog_texture and not (camera and camera.underground_view):
		draw_texture_rect_region(fog_texture,Rect2(Vector2.ZERO,size),Rect2(map_origin,Vector2.ONE*map_span))

	# Draw buildings
	for b in all_buildings_ref:
		if not is_instance_valid(b) or not b.is_alive or camera.underground_view or (b.faction!="player" and not b.visible):
			continue
		var bx: float = (float(b.grid_x)-map_origin.x) * scale_x
		var bz: float = (float(b.grid_z)-map_origin.y) * scale_y
		var bw: float = maxf(3.0, 2.0 * scale_x)
		var col: Color = Color("bc73bc") if b.faction=="goblin" else (Color(0.2,0.6,0.9) if b.is_constructed else Color(0.8,0.6,0.2))
		draw_rect(Rect2(bx, bz, bw, bw), col)

	# Draw units
	for u in all_units_ref:
		if not is_instance_valid(u) or not u.is_alive:
			continue
		if u.state == UnitConfigs.UnitState.MINING_INSIDE or u.underground_unit != camera.underground_view or is_instance_valid(u.embarked_in):
			continue

		var ux: float = (u.global_position.x-map_origin.x) * scale_x
		var uz: float = (u.global_position.z-map_origin.y) * scale_y

		if u.faction == "player":
			draw_circle(Vector2(ux, uz), 2.5, Color(0.2, 0.95, 0.3))
		elif u.faction=="goblin" and u.visible:
			draw_circle(Vector2(ux,uz),2.5,Color("bc73bc"))
		elif u.faction in ["enemy","predator"] and u.visible:
			draw_circle(Vector2(ux, uz), 2.5, Color(0.95, 0.2, 0.2))

	# Raid origins remain visible through fog; actual enemy positions stay hidden.
	for origin in raid_origins:
		if camera.underground_view: continue
		var point: Vector2 = Vector2((origin.x-map_origin.x) * scale_x, (origin.z-map_origin.y) * scale_y)
		draw_circle(point, 5.0, Color("ef896c"), false, 1.5)
		draw_circle(point, 2.0, Color("ffc185"))

	# Camera viewport indicator
	if is_instance_valid(camera):
		var cam_x: float = (camera.current_focus.x-map_origin.x) * scale_x
		var cam_z: float = (camera.current_focus.z-map_origin.y) * scale_y
		var box_size: float = (camera.current_zoom / 26.0) * scale_x * 22.0
		var rect: Rect2 = Rect2(cam_x - box_size * 0.5, cam_z - box_size * 0.5, box_size, box_size)
		draw_rect(rect, Color(1, 1, 1, 0.7), false, 1.2)

	# Outer border
	draw_arc(size*.5,size.x*.5-4,0,TAU,96,Color("557b91"),4.0,true)

func _process(delta: float) -> void:
	redraw_timer += delta
	if redraw_timer >= 0.1:
		redraw_timer = 0.0
		queue_redraw()

func _update_fog_texture() -> void:
	if fog_texture and fog_system.dirty_cells.is_empty():return
	if fog_image==null:
		fog_image=Image.create(GridManager.GRID_SIZE,GridManager.GRID_SIZE,false,Image.FORMAT_RGBA8)
		fog_image.fill(Color(0.025,0.04,0.07,0.96))
	for index in fog_system.dirty_cells:
		var visibility: int = fog_system.visibility_grid[index]
		fog_image.set_pixel(index%GridManager.GRID_SIZE,int(index/GridManager.GRID_SIZE),Color(0.025,0.04,0.07,0.58 if visibility==1 else 0.0))
	if fog_texture:fog_texture.update(fog_image)
	else:fog_texture=ImageTexture.create_from_image(fog_image)
	queue_redraw()
