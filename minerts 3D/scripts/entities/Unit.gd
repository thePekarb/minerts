class_name Unit
extends Entity

@export var unit_type: UnitConfigs.UnitType = UnitConfigs.UnitType.WORKER

static var profile_frame: int = -1
static var navigation_profile: Dictionary = {}

static func record_navigation(key: String, elapsed: int) -> void:
	if profile_frame!=Engine.get_physics_frames():
		profile_frame=Engine.get_physics_frames();navigation_profile.clear()
	navigation_profile[key]=navigation_profile.get(key,0)+elapsed

var embarked_in: Unit
var passengers: Array[Unit] = []
var navigation: UnitNavigation
var navigation_radius: float = 0.3
var config: Dictionary = {}
var speed: float = 4.0
var attack_damage: float = 8.0
var attack_range: float = 1.5
var attack_cooldown: float = 1.0

var current_order: UnitConfigs.UnitOrder = UnitConfigs.UnitOrder.MOVE
var state: UnitConfigs.UnitState = UnitConfigs.UnitState.IDLE
var target: Variant = null
var inventory: Dictionary = {"type": "", "amount": 0}

var path: Array[Vector3] = []
var route_version: int = 0
var visual_suspended: bool = false
var visual_focus: bool = false
var waypoint_index: int = 0

var target_scan_timer: float = 0.0
var underground_unit: bool = false
var stuck_timer: float = 0.0
var previous_position: Vector3 = Vector3.INF
var destination: Vector3 = Vector3.INF
var jump_progress: float = 1.0
var jump_start: Vector3
var jump_end: Vector3
var repath_timer: float = 0.0
var last_combat_destination: Vector3 = Vector3.INF
var fuse_timer: float = -1.0
var blast_warning: MeshInstance3D

var attack_timer: float = 0.0
var gather_timer: float = 0.0
var build_timer: float = 0.0
var anim_time: float = 0.0

var assigned_lumber_zone_id: String = ""
var mining_building_id: String = ""
var grid_manager: GridManager = null

# Model and animation references
var model_root: Node3D = null
var anim_player: AnimationPlayer = null
var axe_ctrl: Node3D = null
var hammer_ctrl: Node3D = null
var sword_ctrl: Node3D = null
var bow_ctrl: Node3D = null
var is_knight: bool = false
var is_archer: bool = false

# Fallback limb references for box model
var left_arm: Node3D = null
var right_arm: Node3D = null
var left_leg: Node3D = null
var right_leg: Node3D = null
var health_display: Label3D
var selection_ring: MeshInstance3D = null
var is_selected: bool = false

func _ready() -> void:
	add_to_group("units")
	if grid_manager:
		grid_manager.unit_index.invalidate()
	config = UnitConfigs.get_config(unit_type)
	armor = config.get("armor", 0.0)
	max_health = config.get("health", 100.0)
	health = max_health
	speed = config.get("speed", 4.0)
	attack_damage = config.get("damage", 10.0)
	attack_range = config.get("attack_range", 1.5)
	attack_cooldown = config.get("attack_cooldown", 1.0)
	attack_timer=maxf(0,attack_cooldown-.25)

	navigation = UnitNavigation.new(self)
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	safe_margin = 0.01
	# Collision setup: Layer 2 for Units, mask 2 | 4 (Units and Buildings)
	# Terrain on layer 1 is excluded so units don't get stuck on vertical voxel step walls
	collision_layer = 2
	collision_mask = 2 | 4
	if UnitConfigs.is_vessel(unit_type):
		collision_layer=16
		collision_mask=16

	_build_model()
	_build_selection_ring()
	health_changed.connect(_update_health_display)
	_build_health_display()

	if not find_child("CollisionShape3D", false, false):
		var col: CollisionShape3D = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var cap: CapsuleShape3D = CapsuleShape3D.new()
		cap.radius = 0.40 if unit_type == UnitConfigs.UnitType.SPIDER else 0.25
		cap.height = 0.8 if unit_type == UnitConfigs.UnitType.SPIDER else 1.7
		col.shape = cap
		col.position.y = cap.height * 0.5
		add_child(col)
	var capsule: CapsuleShape3D = $CollisionShape3D.shape.duplicate()
	navigation_radius = 0.4 if unit_type in [UnitConfigs.UnitType.SPIDER,UnitConfigs.UnitType.SPIDER_RIDER] or UnitConfigs.is_vessel(unit_type) else 0.3
	capsule.radius = navigation_radius
	$CollisionShape3D.shape = capsule

func _build_model() -> void:
	var mesh_dict: Dictionary = VoxelMeshFactory.create_unit_mesh(unit_type, faction)
	model_root = mesh_dict.get("root", null)
	anim_player = mesh_dict.get("anim_player", null)
	axe_ctrl = mesh_dict.get("axe_ctrl", null)
	hammer_ctrl = mesh_dict.get("hammer_ctrl", null)
	sword_ctrl = mesh_dict.get("sword_ctrl", null)
	bow_ctrl = mesh_dict.get("bow_ctrl", null)
	is_knight = (sword_ctrl != null) or (unit_type == UnitConfigs.UnitType.GUARD or unit_type == UnitConfigs.UnitType.WARRIOR)
	is_archer = (bow_ctrl != null) or (unit_type == UnitConfigs.UnitType.ARCHER)
	left_arm = mesh_dict.get("left_arm", null)
	right_arm = mesh_dict.get("right_arm", null)
	left_leg = mesh_dict.get("left_leg", null)
	right_leg = mesh_dict.get("right_leg", null)

	if model_root:
		add_child(model_root)

func _build_selection_ring() -> void:
	selection_ring = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.65
	torus.rings = 24
	torus.ring_segments = 4
	selection_ring.mesh = torus

	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color("22c55e") if faction == "player" else Color("ef4444")
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	selection_ring.material_override = m
	selection_ring.position.y = 0.05
	selection_ring.visible = false
	add_child(selection_ring)

func set_selected(sel: bool) -> void:
	is_selected = sel
	if selection_ring:
		selection_ring.visible = sel
	_update_health_display(health, max_health)

func _process(delta: float) -> void:
	if not is_alive:
		return

	if is_instance_valid(embarked_in):
		visible=false
		collision_layer=0
		return
	if state == UnitConfigs.UnitState.MINING_INSIDE:
		visible = false
		collision_layer = 0
		collision_mask = 0
		if selection_ring:
			selection_ring.visible = false
		if health_display:
			health_display.visible = false
		return
	elif faction == "player" and not underground_unit:
		visible = not (grid_manager and is_instance_valid(grid_manager.underground) and grid_manager.underground.cutaway)
		collision_layer = 16 if UnitConfigs.is_vessel(unit_type) else 2

func garrison_in_building(b: Building) -> void:
	stop()
	set_selected(false)
	current_order = UnitConfigs.UnitOrder.MOVE
	state = UnitConfigs.UnitState.MINING_INSIDE
	visible = false
	collision_layer = 0
	collision_mask = 0
	if selection_ring:
		selection_ring.visible = false
	if health_display:
		health_display.visible = false
	if is_instance_valid(b):
		mining_building_id = str(b.get_instance_id())
		global_position = b.global_position
		previous_position = b.global_position

func ungarrison_from_building(exit_pos: Vector3) -> void:
	global_position = exit_pos
	if grid_manager:grid_manager.unit_index.invalidate()
	previous_position = exit_pos
	state = UnitConfigs.UnitState.IDLE
	current_order = UnitConfigs.UnitOrder.MOVE
	mining_building_id = ""
	target = null
	path.clear()
	waypoint_index = 0
	velocity = Vector3.ZERO
	visible = true
	collision_layer = 2
	collision_mask = 2 | 4
	set_selected(false)

func set_path(new_path: Array[Vector3]) -> void:
	route_version+=1
	if navigation:navigation.yield_return=Vector3.INF
	if navigation and not new_path.is_empty() and destination.distance_squared_to(new_path.back())>0.1:
		navigation.reset_progress()
	if navigation:navigation.yield_steps=0;navigation.waiting_for_gate=false
	path = new_path
	if not path.is_empty():
		destination = path.back()
	waypoint_index = 0

func stop() -> void:
	route_version+=1
	path.clear()
	waypoint_index = 0
	velocity = Vector3.ZERO
	state = UnitConfigs.UnitState.IDLE
	if navigation:navigation.reset_progress()

func _compute_separation() -> Vector3:
	var sep: Vector3 = Vector3.ZERO
	var neighbors: Array = grid_manager.unit_index.query(get_tree(), position, 0.85)
	var count: int = 0
	for node in neighbors:
		if node == self or not (node is Unit):
			continue
		var other: Unit = node as Unit
		if not is_instance_valid(other) or not other.is_alive or other.state == UnitConfigs.UnitState.MINING_INSIDE or is_instance_valid(other.embarked_in) or UnitConfigs.is_vessel(other.unit_type)!=UnitConfigs.is_vessel(unit_type) or other.underground_unit != underground_unit:
			continue
		var diff: Vector3 = global_position - other.global_position
		diff.y = 0.0
		var d: float = diff.length()
		if d > 0.001 and d < 0.85:
			var strength: float = (1.0 - d / 0.85)
			sep += (diff / d) * strength
			count += 1
	if count > 0:
		sep = sep / float(count)
	return sep

func _physics_process(delta: float) -> void:
	if is_instance_valid(embarked_in):return
	var tick_start: int = Time.get_ticks_usec()
	navigation.tick(delta)
	record_navigation("neighbors",Time.get_ticks_usec()-tick_start)
	if UnitConfigs.is_vessel(unit_type):
		_physics_ship(delta)
		return
	if not is_alive or state == UnitConfigs.UnitState.MINING_INSIDE or fuse_timer>=0.0:
		velocity=Vector3.ZERO;navigation.actual_speed=0.0
		_update_animation_and_tools(delta)
		return
	var before: Vector3 = position
	if jump_progress < 1.0:
		jump_progress=minf(1.0,jump_progress+delta*speed/maxf(jump_start.distance_to(jump_end),0.5))
		position=jump_start.lerp(jump_end,jump_progress)+Vector3.UP*sin(jump_progress*PI)*0.35
	else:
		var moving: bool = state in [UnitConfigs.UnitState.MOVING,UnitConfigs.UnitState.RETURNING_TO_STORAGE,UnitConfigs.UnitState.FLEEING]
		velocity=Vector3.ZERO
		if moving and waypoint_index<path.size():
			var wp: Vector3 = path[waypoint_index]
			var offset: Vector3 = Vector3(wp.x-position.x,0,wp.z-position.z)
			if offset.length()<0.16:
				waypoint_index+=1
				if waypoint_index>=path.size():
					path.clear()
					if state in [UnitConfigs.UnitState.MOVING,UnitConfigs.UnitState.FLEEING]:state=UnitConfigs.UnitState.IDLE
			else:
				var observe_start: int = Time.get_ticks_usec()
				navigation.observe(wp,delta)
				record_navigation("recovery",Time.get_ticks_usec()-observe_start)
				if not grid_manager.can_step(position,wp,faction):
					if navigation.retry_after<=0.0:navigation.recover()
				elif grid_manager.wait_for_passage(self):
					navigation.waiting_for_gate=true
				elif absf(wp.y-position.y)>0.5 and offset.length()<0.85:
					if grid_manager.unit_position_free(self,wp) and grid_manager.motion_clear(self,position,wp):
						jump_start=position;jump_end=wp;jump_progress=0.0
				else:
					navigation.waiting_for_gate=false
					var steer_start: int = Time.get_ticks_usec()
					velocity=navigation.steer(wp,delta)
					record_navigation("steering",Time.get_ticks_usec()-steer_start)
					var motion_start: int = Time.get_ticks_usec()
					move_and_slide()
					record_navigation("physics_motion",Time.get_ticks_usec()-motion_start)
					if velocity.length_squared()>0.01:rotation.y=lerp_angle(rotation.y,atan2(velocity.x,velocity.z),minf(1,delta*12))
		if grid_manager and jump_progress>=1.0:position.y=-4.0 if underground_unit else grid_manager.get_height(position.x,position.z)
	navigation.actual_speed=Vector2(position.x-before.x,position.z-before.z).length()/delta
	previous_position=position
	_update_animation_and_tools(delta)

func _update_animation_and_tools(delta: float) -> void:
	if visual_suspended:return
	if not anim_player:
		_animate_limbs_fallback(delta)
		return

	if model_root and model_root.has_meta("frontier_animations"):
		var moving: bool = state in [UnitConfigs.UnitState.MOVING, UnitConfigs.UnitState.RETURNING_TO_STORAGE, UnitConfigs.UnitState.FLEEING]
		set_tool_visibility(state == UnitConfigs.UnitState.GATHERING or state == UnitConfigs.UnitState.ATTACKING, state == UnitConfigs.UnitState.BUILDING)
		if moving and navigation.actual_speed>0.1:
			play_anim("Run" if speed > 5.0 else "Walk", speed / 3.8)
		elif state == UnitConfigs.UnitState.ATTACKING:
			play_anim("Attack", 1.0 / maxf(attack_cooldown, 0.1))
		elif state == UnitConfigs.UnitState.GATHERING:
			play_anim("Gather")
		elif state == UnitConfigs.UnitState.BUILDING:
			play_anim("Build")
		else:
			play_anim("Idle")
		return

	if is_knight:
		match state:
			UnitConfigs.UnitState.MOVING, UnitConfigs.UnitState.RETURNING_TO_STORAGE, UnitConfigs.UnitState.FLEEING:
				if speed >= 5.5 or state == UnitConfigs.UnitState.FLEEING:
					play_anim("KNG_Run", speed / 5.0)
				else:
					play_anim("KNG_Walk", speed / 3.8)

			UnitConfigs.UnitState.ATTACKING:
				play_anim("KNG_SwordSlash", 1.3)

			UnitConfigs.UnitState.IDLE, _:
				play_anim("KNG_Idle", 1.0)
		return

	if is_archer:
		match state:
			UnitConfigs.UnitState.MOVING, UnitConfigs.UnitState.RETURNING_TO_STORAGE, UnitConfigs.UnitState.FLEEING:
				if speed >= 5.5 or state == UnitConfigs.UnitState.FLEEING:
					play_anim("ARC_Run", speed / 5.0)
				else:
					play_anim("ARC_Walk", speed / 4.0)

			UnitConfigs.UnitState.ATTACKING:
				play_anim("ARC_Shoot", 1.3)

			UnitConfigs.UnitState.IDLE, _:
				play_anim("ARC_Idle", 1.0)
		return

	match state:
		UnitConfigs.UnitState.MOVING, UnitConfigs.UnitState.RETURNING_TO_STORAGE, UnitConfigs.UnitState.FLEEING:
			set_tool_visibility(false, false)
			if speed >= 5.5 or state == UnitConfigs.UnitState.FLEEING:
				play_anim("VIL_Run", speed / 5.0)
			else:
				play_anim("VIL_Walk", speed / 3.8)

		UnitConfigs.UnitState.GATHERING:
			set_tool_visibility(true, false)
			play_anim("VIL_AxeSwing", 1.2)

		UnitConfigs.UnitState.BUILDING:
			set_tool_visibility(false, true)
			play_anim("VIL_HammerSwing", 1.2)

		UnitConfigs.UnitState.ATTACKING:
			if unit_type == UnitConfigs.UnitType.ARCHER:
				set_tool_visibility(false, false)
				play_anim("VIL_Walk", 0.0)
			else:
				set_tool_visibility(true, false)
				play_anim("VIL_AxeSwing", 1.3)

		UnitConfigs.UnitState.IDLE, _:
			set_tool_visibility(false, false)
			if anim_player.current_animation != "":
				anim_player.pause()

func play_anim(anim_name: String, speed_scale: float = 1.0) -> void:
	if not anim_player:
		return
	if anim_player.current_animation == anim_name and anim_player.is_playing():
		anim_player.speed_scale = speed_scale
		return
	if anim_player.has_animation(anim_name):
		anim_player.speed_scale = speed_scale
		anim_player.play(anim_name, 0.12)
		return
	for full_name in anim_player.get_animation_list():
		if full_name.ends_with(anim_name) or full_name == anim_name:
			if anim_player.current_animation == full_name and anim_player.is_playing():
				anim_player.speed_scale = speed_scale
				return
			anim_player.speed_scale = speed_scale
			anim_player.play(full_name, 0.12)
			return

func set_tool_visibility(show_axe: bool, show_hammer: bool) -> void:
	if is_instance_valid(axe_ctrl):
		axe_ctrl.visible = show_axe
	if is_instance_valid(hammer_ctrl):
		hammer_ctrl.visible = show_hammer

func _animate_limbs_fallback(delta: float) -> void:
	if not left_arm or not right_arm or not left_leg or not right_leg:
		return

	if state == UnitConfigs.UnitState.MOVING or state == UnitConfigs.UnitState.RETURNING_TO_STORAGE or state == UnitConfigs.UnitState.FLEEING:
		anim_time += delta * (speed * 3.2)
		var swing: float = sin(anim_time) * 0.65
		left_leg.rotation.x = swing
		right_leg.rotation.x = -swing
		left_arm.rotation.x = -swing * 0.7
		right_arm.rotation.x = swing * 0.7
	elif state == UnitConfigs.UnitState.GATHERING or state == UnitConfigs.UnitState.BUILDING:
		anim_time += delta * 8.0
		var chop: float = sin(anim_time) * 0.85 - 0.2
		right_arm.rotation.x = chop
		left_arm.rotation.x = 0.0
		left_leg.rotation.x = 0.0
		right_leg.rotation.x = 0.0
	elif state == UnitConfigs.UnitState.ATTACKING:
		if is_archer:
			left_arm.rotation.x = -1.4
			right_arm.rotation.x = -0.9
			left_leg.rotation.x = 0.0
			right_leg.rotation.x = 0.0
		else:
			anim_time += delta * 10.0
			var slash: float = sin(anim_time) * 0.95
			right_arm.rotation.x = slash
			left_arm.rotation.x = -slash * 0.3
	else:
		anim_time += delta * 2.0
		left_leg.rotation.x = 0.0
		right_leg.rotation.x = 0.0
		left_arm.rotation.x = sin(anim_time) * 0.08
		right_arm.rotation.x = -sin(anim_time) * 0.08


func _build_health_display() -> void:
	health_display = Label3D.new()
	health_display.position.y = 2.05
	health_display.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_display.font_size = 28
	health_display.pixel_size = 0.009
	health_display.outline_size = 8
	add_child(health_display)
	_update_health_display(health, max_health)

func _update_health_display(current: float, maximum: float) -> void:
	if not is_instance_valid(health_display):
		return
	var ratio: float = clampf(current / maxf(maximum, 1.0), 0.0, 1.0)
	health_display.text = "━".repeat(int(ceil(ratio * 8.0)))
	health_display.modulate = Color("f07167") if ratio < 0.35 else (Color("8ed6aa") if faction == "player" else Color("ef896c"))
	health_display.visible = current > 0.0 and (current < maximum or selection_ring.visible)

func _physics_ship(delta: float) -> void:
	if not is_alive:return
	velocity=Vector3.ZERO
	if waypoint_index<path.size():
		var point: Vector3 = path[waypoint_index]
		var offset: Vector3 = point-position;offset.y=0
		if offset.length()<0.25:
			waypoint_index+=1
			if waypoint_index>=path.size():path.clear();state=UnitConfigs.UnitState.IDLE
		else:
			navigation.observe(point,delta)
			velocity=navigation.steer(point,delta)
			move_and_slide()
			if velocity.length_squared()>0.01:rotation.y=lerp_angle(rotation.y,atan2(velocity.x,velocity.z),minf(1,delta*3))
	position.y=0.22
	if model_root:model_root.rotation.z=sin(Time.get_ticks_msec()*0.0017+get_instance_id())*0.018
