class_name FrontierAssets
extends RefCounted

static var scenes: Dictionary = {}

static func instantiate_asset(asset_name: String) -> Node3D:
	var path: String = "res://assets/frontier/%s.glb" % asset_name
	if not scenes.has(asset_name):
		if not ResourceLoader.exists(path):
			return null
		scenes[asset_name] = load(path)
	return scenes[asset_name].instantiate() as Node3D

static func unit_asset_name(type: UnitConfigs.UnitType, faction: String) -> String:
	var names: Dictionary = {
		UnitConfigs.UnitType.WORKER: "worker", UnitConfigs.UnitType.SCOUT: "scout",
		UnitConfigs.UnitType.WARRIOR: "knight", UnitConfigs.UnitType.ARCHER: "archer",
		UnitConfigs.UnitType.RAIDER: "zombie", UnitConfigs.UnitType.ENEMY_FAST: "spider",
		UnitConfigs.UnitType.ZOMBIE: "zombie", UnitConfigs.UnitType.SKELETON: "skeleton",
		UnitConfigs.UnitType.SPIDER: "spider", UnitConfigs.UnitType.CREEPER: "creeper",
		UnitConfigs.UnitType.ANCIENT_GOLEM:"ancient_golem",UnitConfigs.UnitType.STORM_WARDEN:"storm_warden",
		UnitConfigs.UnitType.WOLF:"wolf", UnitConfigs.UnitType.BEAR:"bear",
		UnitConfigs.UnitType.GOBLIN_WORKER:"goblin_worker",UnitConfigs.UnitType.GOBLIN_WARRIOR:"goblin_warrior",UnitConfigs.UnitType.GOBLIN_ARCHER:"goblin_archer",
		UnitConfigs.UnitType.GOBLIN_SPEARMAN:"goblin_spearman",UnitConfigs.UnitType.SPIDER_RIDER:"spider_rider",UnitConfigs.UnitType.TROLL:"troll",UnitConfigs.UnitType.BOAT:"boat",UnitConfigs.UnitType.GALLEY:"galley",
		UnitConfigs.UnitType.DEER: "deer", UnitConfigs.UnitType.BOAR: "boar", UnitConfigs.UnitType.RABBIT: "rabbit"
	}
	var asset: String = names.get(type, "worker")
	if faction == "enemy" and type == UnitConfigs.UnitType.ARCHER:
		asset = "skeleton"
	return asset

static func create_unit(type: UnitConfigs.UnitType, faction: String) -> Dictionary:
	var model: Node3D = instantiate_asset(unit_asset_name(type,faction))
	if model == null:
		return {}
	model.set_meta("frontier_animations", true)
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player:
		for animation_name in player.get_animation_list():
			player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
	return {"root": model, "anim_player": player,
		"axe_ctrl": model.find_child("Axe_CTRL", true, false),
		"hammer_ctrl": model.find_child("Hammer_CTRL", true, false)}

static func create_building(type: BuildingConfigs.BuildingType) -> Node3D:
	var names: Array[String] = ["campfire", "hut", "storage", "wall", "gate", "tower", "workshop", "mine", "barracks", "farm", "well", "port"]
	return instantiate_asset(names[int(type)]) if int(type) < names.size() else null

static func create_faction_building(type: BuildingConfigs.BuildingType, faction: String) -> Node3D:
	var names: Array[String] = ["campfire","hut","storage","wall","gate","tower","workshop","mine","barracks","farm","well","port"]
	if FactionRules.race(faction)=="goblin":
		var variant: Node3D = instantiate_asset("goblin_"+names[int(type)])
		if variant: return variant
	return create_building(type)
