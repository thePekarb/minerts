class_name RTSCamera
extends Camera3D

@export var move_speed: float = 24.0
@export var zoom_speed: float = 3.0
@export var min_zoom: float = 10.0
@export var max_zoom: float = 120.0
@export var min_pitch: float = 0.45
@export var max_pitch: float = 1.25

var command_keys_active: bool = false
var target_focus: Vector3 = Vector3(GridManager.CENTER, 2.0, GridManager.CENTER)
var current_focus: Vector3 = Vector3(GridManager.CENTER, 2.0, GridManager.CENTER)

var target_zoom: float = 24.0
var current_zoom: float = 24.0

var target_yaw: float = -PI * 0.25 # 45 degrees isometric
var current_yaw: float = -PI * 0.25

var pitch: float = 0.85 # ~49 degrees downward tilt

var is_orbiting: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO

var underground_view: bool = false
var terrain_generator: TerrainGenerator = null

func _ready() -> void:
	current_focus = target_focus
	current_zoom = target_zoom
	current_yaw = target_yaw
	_update_transform()

func set_terrain(tg: TerrainGenerator) -> void:
	terrain_generator = tg

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = clampf(target_zoom - zoom_speed, min_zoom, max_zoom)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = clampf(target_zoom + zoom_speed, min_zoom, max_zoom)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			is_orbiting = mb.pressed
			last_mouse_pos = mb.position
	elif event is InputEventMouseMotion and is_orbiting:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		var delta_pos: Vector2 = mm.position - last_mouse_pos
		last_mouse_pos = mm.position
		target_yaw += delta_pos.x * 0.008

func _process(delta: float) -> void:
	# WASD / Arrow keys pan
	var input_vec: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_vec.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_vec.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_vec.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_vec.x += 1.0

	# Q / E rotate
	if Input.is_key_pressed(KEY_Q) and (not command_keys_active or Input.is_key_pressed(KEY_CTRL)):
		target_yaw -= 2.0 * delta
	if Input.is_key_pressed(KEY_E) and (not command_keys_active or Input.is_key_pressed(KEY_CTRL)):
		target_yaw += 2.0 * delta

	if input_vec.length_squared() > 0.0:
		input_vec = input_vec.normalized()
		# Calculate forward and right in world space relative to yaw
		var fwd: Vector3 = Vector3(sin(target_yaw), 0, cos(target_yaw)).normalized()
		var right: Vector3 = Vector3(cos(target_yaw), 0, -sin(target_yaw)).normalized()
		var move: Vector3 = (right * input_vec.x + fwd * input_vec.y) * move_speed * delta * (2.5 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
		target_focus += move
		target_focus.x = clampf(target_focus.x, 4.0, float(GridManager.GRID_SIZE - 4))
		target_focus.z = clampf(target_focus.z, 4.0, float(GridManager.GRID_SIZE - 4))

	# Terrain height follow
	if terrain_generator:
		var ground_h: float = terrain_generator.get_height_at(target_focus.x, target_focus.z)
		target_focus.y = -4.0 if underground_view else ground_h

	# Smooth lerps
	current_focus = current_focus.lerp(target_focus, delta * 12.0)
	current_zoom = lerpf(current_zoom, target_zoom, delta * 12.0)
	current_yaw = lerp_angle(current_yaw, target_yaw, delta * 12.0)

	_update_transform()

func _update_transform() -> void:
	# Offset from focus point
	var offset: Vector3 = Vector3(
		sin(current_yaw) * cos(pitch) * current_zoom,
		sin(pitch) * current_zoom,
		cos(current_yaw) * cos(pitch) * current_zoom
	)
	global_position = current_focus + offset
	look_at(current_focus, Vector3.UP)

func raycast_ground(screen_pos: Vector2) -> Vector3:
	var ray_origin: Vector3 = project_ray_origin(screen_pos)
	var ray_dir: Vector3 = project_ray_normal(screen_pos)

	if underground_view:
		var underground_hit: Variant = Plane(Vector3.UP, -4.0).intersects_ray(ray_origin, ray_dir)
		return underground_hit if underground_hit != null else current_focus

	# Try direct physics raycast first (hits terrain collision)
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * 200.0)
	query.collision_mask = 1 # Terrain on layer 1
	var result: Dictionary = space_state.intersect_ray(query)
	if not result.is_empty():
		return result.position

	# Fallback mathematical plane intersection at focus height
	var plane: Plane = Plane(Vector3.UP, -current_focus.y)
	var hit: Variant = plane.intersects_ray(ray_origin, ray_dir)
	if hit != null:
		return hit as Vector3
	return Vector3(current_focus.x, 0, current_focus.z)

func raycast_objects(screen_pos: Vector2, collision_mask: int = 0xFFFFFFFF) -> Dictionary:
	var ray_origin: Vector3 = project_ray_origin(screen_pos)
	var ray_dir: Vector3 = project_ray_normal(screen_pos)
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * 200.0)
	query.collision_mask = 32 if underground_view else collision_mask & ~32
	query.collide_with_areas = true
	query.collide_with_bodies = true
	return space_state.intersect_ray(query)
