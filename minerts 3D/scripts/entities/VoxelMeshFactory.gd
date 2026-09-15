class_name VoxelMeshFactory
extends RefCounted

static var mat_cache: Dictionary = {}

static func get_mat(color: Color, roughness: float = 0.8, metallic: float = 0.0) -> StandardMaterial3D:
	var key: String = "%s_%.2f_%.2f" % [color.to_html(), roughness, metallic]
	if mat_cache.has(key):
		return mat_cache[key]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	mat_cache[key] = m
	return m

static func create_box_mesh(size: Vector3, color: Color, roughness: float = 0.8, metallic: float = 0.0) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	box.material = get_mat(color, roughness, metallic)
	mi.mesh = box
	return mi

# ==========================================
# UNITS
# ==========================================
static func create_unit_mesh(type: UnitConfigs.UnitType, faction: String) -> Dictionary:
	var frontier: Dictionary = FrontierAssets.create_unit(type, faction)
	if not frontier.is_empty():
		return frontier
	if type == UnitConfigs.UnitType.GUARD or type == UnitConfigs.UnitType.WARRIOR:
		var knight_dict: Dictionary = KnightFactory.create_knight_unit(faction)
		if not knight_dict.is_empty():
			return knight_dict

	if type == UnitConfigs.UnitType.ARCHER:
		var archer_dict: Dictionary = ArcherFactory.create_archer_unit(faction)
		if not archer_dict.is_empty():
			return archer_dict

	var villager_dict: Dictionary = VillagerFactory.create_villager_unit(type, faction)
	if not villager_dict.is_empty():
		return villager_dict

	var root: Node3D = Node3D.new()
	root.name = "ModelRoot"

	var skin_color: Color = Color("fbcfe8")
	var body_color: Color = Color("3b82f6") # Blue worker default
	var pants_color: Color = Color("1e293b")
	var metal_color: Color = Color("cbd5e1")
	var wood_color: Color = Color("b45309")

	if faction == "enemy":
		if type == UnitConfigs.UnitType.ENEMY_FAST:
			body_color = Color("7f1d1d") # Dark blood red
			skin_color = Color("991b1b")
		else:
			body_color = Color("4c0519") # Deep crimson brute
			skin_color = Color("701a75")
	else:
		match type:
			UnitConfigs.UnitType.WORKER:
				body_color = Color("2563eb") # Blue
			UnitConfigs.UnitType.SCOUT:
				body_color = Color("16a34a") # Green
			UnitConfigs.UnitType.GUARD, UnitConfigs.UnitType.WARRIOR:
				body_color = Color("64748b") # Silver plate
			UnitConfigs.UnitType.ARCHER:
				body_color = Color("d97706") # Amber / Leather

	# Body / Torso
	var is_brute: bool = (type == UnitConfigs.UnitType.ENEMY_MELEE or type == UnitConfigs.UnitType.RAIDER)
	var body_w: float = 0.65 if is_brute else 0.44
	var body_h: float = 0.75 if is_brute else 0.55
	var body: MeshInstance3D = create_box_mesh(Vector3(body_w, body_h, 0.3), body_color)
	body.position.y = 0.65
	root.add_child(body)

	# Head
	var head_size: float = 0.42 if is_brute else 0.32
	var head: MeshInstance3D = create_box_mesh(Vector3(head_size, head_size, head_size), skin_color)
	head.position.y = body_h * 0.5 + head_size * 0.5 + 0.02
	body.add_child(head)

	# Guard Helmet
	if type == UnitConfigs.UnitType.GUARD or type == UnitConfigs.UnitType.WARRIOR:
		var helm: MeshInstance3D = create_box_mesh(Vector3(head_size + 0.06, head_size * 0.6, head_size + 0.06), metal_color, 0.4, 0.6)
		helm.position.y = head_size * 0.25
		head.add_child(helm)

	# Limbs
	var leg_w: float = 0.22 if is_brute else 0.16
	var leg_h: float = 0.42
	var leg_off_x: float = body_w * 0.25

	var left_leg: MeshInstance3D = create_box_mesh(Vector3(leg_w, leg_h, 0.18), pants_color)
	left_leg.position = Vector3(-leg_off_x, 0.21, 0)
	root.add_child(left_leg)

	var right_leg: MeshInstance3D = create_box_mesh(Vector3(leg_w, leg_h, 0.18), pants_color)
	right_leg.position = Vector3(leg_off_x, 0.21, 0)
	root.add_child(right_leg)

	var arm_w: float = 0.2 if is_brute else 0.14
	var arm_h: float = 0.45
	var arm_off_x: float = body_w * 0.5 + arm_w * 0.5

	var left_arm: MeshInstance3D = create_box_mesh(Vector3(arm_w, arm_h, 0.16), skin_color)
	left_arm.position = Vector3(-arm_off_x, 0.65, 0)
	root.add_child(left_arm)

	var right_arm: MeshInstance3D = create_box_mesh(Vector3(arm_w, arm_h, 0.16), skin_color)
	right_arm.position = Vector3(arm_off_x, 0.65, 0)
	root.add_child(right_arm)

	# Equipment Tool / Weapon attached to right arm
	var tool_node: Node3D = null
	match type:
		UnitConfigs.UnitType.WORKER:
			# Pickaxe/Axe combo
			tool_node = Node3D.new()
			var handle: MeshInstance3D = create_box_mesh(Vector3(0.06, 0.5, 0.06), wood_color)
			handle.position.y = -0.1
			tool_node.add_child(handle)
			var blade: MeshInstance3D = create_box_mesh(Vector3(0.25, 0.1, 0.08), metal_color, 0.3, 0.7)
			blade.position.y = 0.12
			tool_node.add_child(blade)
			right_arm.add_child(tool_node)
		UnitConfigs.UnitType.GUARD, UnitConfigs.UnitType.WARRIOR:
			# Sword
			tool_node = Node3D.new()
			var blade: MeshInstance3D = create_box_mesh(Vector3(0.08, 0.65, 0.04), metal_color, 0.2, 0.8)
			blade.position.y = 0.2
			tool_node.add_child(blade)
			var cross: MeshInstance3D = create_box_mesh(Vector3(0.24, 0.06, 0.08), Color("d97706"), 0.3, 0.5)
			cross.position.y = -0.1
			tool_node.add_child(cross)
			right_arm.add_child(tool_node)
		UnitConfigs.UnitType.ARCHER:
			# Bow
			tool_node = Node3D.new()
			var bow_stave: MeshInstance3D = create_box_mesh(Vector3(0.06, 0.65, 0.06), wood_color)
			tool_node.add_child(bow_stave)
			left_arm.add_child(tool_node)

	return {
		"root": root,
		"body": body,
		"head": head,
		"left_leg": left_leg,
		"right_leg": right_leg,
		"left_arm": left_arm,
		"right_arm": right_arm,
		"tool": tool_node
	}

# ==========================================
# BUILDINGS
# ==========================================
static func create_building_mesh(type: BuildingConfigs.BuildingType) -> Node3D:
	var frontier: Node3D = FrontierAssets.create_building(type)
	if frontier:
		return frontier
	var root: Node3D = Node3D.new()
	root.name = "BuildingMesh"

	var wood_col: Color = Color("92400e")
	var plank_col: Color = Color("b45309")
	var stone_col: Color = Color("475569")
	var dark_stone: Color = Color("334155")
	var thatch_col: Color = Color("eab308")

	match type:
		BuildingConfigs.BuildingType.CAMPFIRE:
			var ring: MeshInstance3D = create_box_mesh(Vector3(1.8, 0.2, 1.8), stone_col)
			ring.position.y = 0.1
			root.add_child(ring)
			var log1: MeshInstance3D = create_box_mesh(Vector3(1.2, 0.2, 0.25), wood_col)
			log1.position.y = 0.25
			log1.rotation.y = 0.6
			root.add_child(log1)
			var log2: MeshInstance3D = create_box_mesh(Vector3(1.2, 0.2, 0.25), wood_col)
			log2.position.y = 0.25
			log2.rotation.y = -0.6
			root.add_child(log2)
			var fire_ember: MeshInstance3D = create_box_mesh(Vector3(0.5, 0.4, 0.5), Color("f97316"), 0.2)
			fire_ember.position.y = 0.35
			root.add_child(fire_ember)

		BuildingConfigs.BuildingType.HUT:
			# Timber cabin base
			var base: MeshInstance3D = create_box_mesh(Vector3(1.8, 1.3, 1.8), plank_col)
			base.position.y = 0.65
			root.add_child(base)
			# Slanted thatch roof
			var roof: MeshInstance3D = create_box_mesh(Vector3(2.1, 0.7, 2.1), thatch_col)
			roof.position.y = 1.6
			roof.rotation.x = 0.05
			root.add_child(roof)
			# Door aperture
			var door_frame: MeshInstance3D = create_box_mesh(Vector3(0.5, 0.8, 0.1), Color("1e293b"))
			door_frame.position = Vector3(0, 0.4, 0.91)
			root.add_child(door_frame)

		BuildingConfigs.BuildingType.STORAGE:
			var platform: MeshInstance3D = create_box_mesh(Vector3(1.9, 0.25, 1.9), wood_col)
			platform.position.y = 0.125
			root.add_child(platform)
			# 3 big crates
			var c1: MeshInstance3D = create_box_mesh(Vector3(0.7, 0.7, 0.7), plank_col)
			c1.position = Vector3(-0.4, 0.6, -0.4)
			root.add_child(c1)
			var c2: MeshInstance3D = create_box_mesh(Vector3(0.65, 0.65, 0.65), plank_col)
			c2.position = Vector3(0.45, 0.55, -0.3)
			root.add_child(c2)
			var c3: MeshInstance3D = create_box_mesh(Vector3(0.6, 0.6, 0.6), plank_col)
			c3.position = Vector3(0.0, 0.55, 0.45)
			root.add_child(c3)

		BuildingConfigs.BuildingType.WALL:
			var spike: MeshInstance3D = create_box_mesh(Vector3(0.9, 1.6, 0.35), wood_col)
			spike.position.y = 0.8
			root.add_child(spike)
			var top_point: MeshInstance3D = create_box_mesh(Vector3(0.8, 0.4, 0.25), plank_col)
			top_point.position.y = 1.7
			root.add_child(top_point)

		BuildingConfigs.BuildingType.GATE:
			# Left & Right posts
			var post1: MeshInstance3D = create_box_mesh(Vector3(0.35, 1.8, 0.5), wood_col)
			post1.position = Vector3(-0.85, 0.9, 0)
			root.add_child(post1)

			var post2: MeshInstance3D = create_box_mesh(Vector3(0.35, 1.8, 0.5), wood_col)
			post2.position = Vector3(0.85, 0.9, 0)
			root.add_child(post2)

			var lintel: MeshInstance3D = create_box_mesh(Vector3(2.0, 0.35, 0.4), wood_col)
			lintel.position = Vector3(0, 1.8, 0)
			root.add_child(lintel)

			# Hinged Door panel
			var door: MeshInstance3D = create_box_mesh(Vector3(1.4, 1.4, 0.15), plank_col)
			door.name = "GateDoor"
			door.position = Vector3(0, 0.8, 0)
			root.add_child(door)

		BuildingConfigs.BuildingType.TOWER:
			var base: MeshInstance3D = create_box_mesh(Vector3(1.6, 1.8, 1.6), stone_col)
			base.position.y = 0.9
			root.add_child(base)
			var platform: MeshInstance3D = create_box_mesh(Vector3(2.0, 0.3, 2.0), plank_col)
			platform.position.y = 1.95
			root.add_child(platform)
			var battlements: MeshInstance3D = create_box_mesh(Vector3(1.9, 0.45, 0.2), wood_col)
			battlements.position = Vector3(0, 2.3, 0.85)
			root.add_child(battlements)

		BuildingConfigs.BuildingType.WORKSHOP:
			var workshop_base: MeshInstance3D = create_box_mesh(Vector3(2.8, 1.4, 2.8), plank_col)
			workshop_base.position.y = 0.7
			root.add_child(workshop_base)
			var chimney: MeshInstance3D = create_box_mesh(Vector3(0.6, 2.4, 0.6), dark_stone)
			chimney.position = Vector3(-1.0, 1.2, -1.0)
			root.add_child(chimney)
			var roof: MeshInstance3D = create_box_mesh(Vector3(3.0, 0.5, 3.0), stone_col)
			roof.position.y = 1.6
			root.add_child(roof)

		BuildingConfigs.BuildingType.BARRACKS:
			# Heavy fortified stone ground floor (3x3 footprint)
			var stone_base: MeshInstance3D = create_box_mesh(Vector3(2.8, 1.3, 2.8), dark_stone, 0.9, 0.0)
			stone_base.position.y = 0.65
			root.add_child(stone_base)

			# Upper timber gallery / barracks quarters
			var timber_quarters: MeshInstance3D = create_box_mesh(Vector3(2.4, 1.1, 2.4), plank_col, 0.8, 0.0)
			timber_quarters.position.y = 1.85
			root.add_child(timber_quarters)

			# Pitched gable roof (dark terracotta/slate)
			var barracks_roof: MeshInstance3D = create_box_mesh(Vector3(2.7, 0.5, 2.7), Color("7f1d1d"), 0.7, 0.0)
			barracks_roof.position.y = 2.65
			root.add_child(barracks_roof)

			# Entrance reinforced arched door
			var door: MeshInstance3D = create_box_mesh(Vector3(0.7, 1.0, 0.15), wood_col, 0.6, 0.1)
			door.position = Vector3(0.0, 0.5, 1.42)
			root.add_child(door)

			# Flanking heraldic banners (Crimson & Gold)
			var banner_l: MeshInstance3D = create_box_mesh(Vector3(0.2, 0.9, 0.05), Color("b91c1c"), 0.8, 0.0)
			banner_l.position = Vector3(-0.6, 1.1, 1.43)
			root.add_child(banner_l)

			var banner_r: MeshInstance3D = create_box_mesh(Vector3(0.2, 0.9, 0.05), Color("b91c1c"), 0.8, 0.0)
			banner_r.position = Vector3(0.6, 1.1, 1.43)
			root.add_child(banner_r)

			# Weapon training rack (right side)
			var rack_post1: MeshInstance3D = create_box_mesh(Vector3(0.08, 0.9, 0.08), wood_col)
			rack_post1.position = Vector3(1.48, 0.45, 0.5)
			root.add_child(rack_post1)

			var rack_post2: MeshInstance3D = create_box_mesh(Vector3(0.08, 0.9, 0.08), wood_col)
			rack_post2.position = Vector3(1.48, 0.45, 0.9)
			root.add_child(rack_post2)

			var sword_prop: MeshInstance3D = create_box_mesh(Vector3(0.06, 0.8, 0.08), Color("94a3b8"), 0.3, 0.8)
			sword_prop.position = Vector3(1.48, 0.45, 0.7)
			root.add_child(sword_prop)

			# Archery practice target (left side)
			var target_post: MeshInstance3D = create_box_mesh(Vector3(0.08, 1.1, 0.08), wood_col)
			target_post.position = Vector3(-1.48, 0.55, 0.6)
			root.add_child(target_post)

			var target_disc: MeshInstance3D = create_box_mesh(Vector3(0.06, 0.6, 0.6), Color("fef08a"), 0.9, 0.0)
			target_disc.position = Vector3(-1.48, 0.8, 0.6)
			root.add_child(target_disc)

			var bullseye: MeshInstance3D = create_box_mesh(Vector3(0.08, 0.22, 0.22), Color("dc2626"), 0.8, 0.0)
			bullseye.position = Vector3(-1.48, 0.8, 0.6)
			root.add_child(bullseye)

		BuildingConfigs.BuildingType.MINE:
			# Ground pit collar
			var collar: MeshInstance3D = create_box_mesh(Vector3(1.9, 0.3, 1.9), dark_stone)
			collar.position.y = 0.15
			root.add_child(collar)

			# Pit hole
			var pit: MeshInstance3D = create_box_mesh(Vector3(1.2, 0.32, 1.2), Color("090d16"))
			pit.position.y = 0.16
			root.add_child(pit)

			# Timber A-frame headframe
			var frame1: MeshInstance3D = create_box_mesh(Vector3(0.2, 1.9, 0.2), wood_col)
			frame1.position = Vector3(-0.7, 1.0, 0)
			frame1.rotation.z = -0.1
			root.add_child(frame1)

			var frame2: MeshInstance3D = create_box_mesh(Vector3(0.2, 1.9, 0.2), wood_col)
			frame2.position = Vector3(0.7, 1.0, 0)
			frame2.rotation.z = 0.1
			root.add_child(frame2)

			var beam: MeshInstance3D = create_box_mesh(Vector3(1.6, 0.2, 0.2), wood_col)
			beam.position = Vector3(0, 1.9, 0)
			root.add_child(beam)

			# Pulley wheel
			var pulley: MeshInstance3D = create_box_mesh(Vector3(0.4, 0.4, 0.1), Color("f59e0b"), 0.3, 0.5)
			pulley.position = Vector3(0, 1.7, 0)
			root.add_child(pulley)

			# Deep Ore indicator (hidden by default until upgraded)
			var ore_indicator: MeshInstance3D = create_box_mesh(Vector3(0.45, 0.45, 0.45), Color("38bdf8"), 0.2, 0.8)
			ore_indicator.name = "DeepOreBlock"
			ore_indicator.position = Vector3(0.65, 0.4, 0.65)
			ore_indicator.visible = false
			root.add_child(ore_indicator)

	return root

# ==========================================
# PROPS & RESOURCES
# ==========================================
static func create_tree_mesh(tree_type: String = "pine") -> Node3D:
	var frontier: Node3D = FrontierAssets.instantiate_asset("tree_" + tree_type)
	if frontier:
		return frontier
	var root: Node3D = Node3D.new()
	root.name = "TreeMesh"

	var trunk_col: Color = Color("78350f")
	var leaf_col: Color = Color("15803d") if tree_type == "pine" else Color("16a34a")

	var trunk: MeshInstance3D = create_box_mesh(Vector3(0.4, 1.4, 0.4), trunk_col)
	trunk.position.y = 0.7
	root.add_child(trunk)

	if tree_type == "pine":
		# 3 tiered pine blocks
		var l1: MeshInstance3D = create_box_mesh(Vector3(1.6, 0.8, 1.6), leaf_col)
		l1.position.y = 1.4
		root.add_child(l1)

		var l2: MeshInstance3D = create_box_mesh(Vector3(1.2, 0.7, 1.2), leaf_col)
		l2.position.y = 2.0
		root.add_child(l2)

		var l3: MeshInstance3D = create_box_mesh(Vector3(0.7, 0.6, 0.7), leaf_col)
		l3.position.y = 2.5
		root.add_child(l3)
	else:
		# Broadleaf canopy
		var crown: MeshInstance3D = create_box_mesh(Vector3(1.7, 1.4, 1.7), leaf_col)
		crown.position.y = 1.8
		root.add_child(crown)

	return root

static func create_bush_mesh() -> Node3D:
	var frontier: Node3D = FrontierAssets.instantiate_asset("prop_berries")
	if frontier:
		return frontier
	var root: Node3D = Node3D.new()
	root.name = "BushMesh"
	var foliage: MeshInstance3D = create_box_mesh(Vector3(1.0, 0.8, 1.0), Color("166534"))
	foliage.position.y = 0.4
	root.add_child(foliage)

	# Berries
	var b1: MeshInstance3D = create_box_mesh(Vector3(0.16, 0.16, 0.16), Color("ef4444"))
	b1.position = Vector3(0.3, 0.5, 0.45)
	root.add_child(b1)
	var b2: MeshInstance3D = create_box_mesh(Vector3(0.16, 0.16, 0.16), Color("ef4444"))
	b2.position = Vector3(-0.35, 0.6, 0.2)
	root.add_child(b2)
	return root

static func create_chest_mesh() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "ChestMesh"
	var chest_body: MeshInstance3D = create_box_mesh(Vector3(0.7, 0.45, 0.5), Color("b45309"))
	chest_body.position.y = 0.225
	root.add_child(chest_body)
	var lid: MeshInstance3D = create_box_mesh(Vector3(0.74, 0.2, 0.54), Color("d97706"))
	lid.name = "ChestLid"
	lid.position.y = 0.48
	root.add_child(lid)
	var lock: MeshInstance3D = create_box_mesh(Vector3(0.12, 0.15, 0.08), Color("fbbf24"), 0.2, 0.8)
	lock.position = Vector3(0, 0.35, 0.26)
	root.add_child(lock)
	return root

static func create_icon_badge(icon_type: String) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "IconBadge_" + icon_type

	# Diamond/Hex background plaque
	var plaque: MeshInstance3D = create_box_mesh(Vector3(0.9, 0.9, 0.08), Color(0.1, 0.15, 0.2, 0.9), 0.5)
	plaque.rotation.z = PI * 0.25 # Diamond orientation
	root.add_child(plaque)

	# Rim border
	var rim: MeshInstance3D = create_box_mesh(Vector3(0.96, 0.96, 0.04), Color(0.2, 0.85, 0.4), 0.2, 0.7)
	rim.rotation.z = PI * 0.25
	rim.position.z = -0.02
	root.add_child(rim)

	if icon_type == "axe":
		# Wooden handle
		var handle: MeshInstance3D = create_box_mesh(Vector3(0.08, 0.65, 0.08), Color("854d0e"))
		handle.position.z = 0.08
		handle.rotation.z = -PI * 0.2
		root.add_child(handle)

		# Axe blade
		var blade: MeshInstance3D = create_box_mesh(Vector3(0.3, 0.22, 0.1), Color("cbd5e1"), 0.3, 0.8)
		blade.position = Vector3(0.12, 0.18, 0.08)
		blade.rotation.z = -PI * 0.2
		root.add_child(blade)
	else:
		# Pickaxe
		var handle: MeshInstance3D = create_box_mesh(Vector3(0.08, 0.65, 0.08), Color("854d0e"))
		handle.position.z = 0.08
		handle.rotation.z = -PI * 0.2
		root.add_child(handle)

		var pick: MeshInstance3D = create_box_mesh(Vector3(0.42, 0.12, 0.1), Color("94a3b8"), 0.3, 0.8)
		pick.position = Vector3(0.1, 0.2, 0.08)
		pick.rotation.z = -PI * 0.2
		root.add_child(pick)

	return root

