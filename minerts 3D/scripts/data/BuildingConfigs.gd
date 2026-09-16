class_name BuildingConfigs
extends RefCounted

enum BuildingType {
	CAMPFIRE,
	HUT,
	STORAGE,
	WALL,
	GATE,
	TOWER,
	WORKSHOP,
	MINE,
	BARRACKS,
	FARM,
	WELL,
	PORT
}

const CONFIGS: Dictionary = {
	BuildingType.CAMPFIRE: {
		"name": "Campfire",
		"icon": "🔥",
		"cost": {"wood": 80, "stone": 30},
		"size": Vector2i(2, 2),
		"footprint": Vector2i(2, 2),
		"build_time": 0.0,
		"max_health": 1200,
		"vision_range": 16.0,
		"description": "Heart of the settlement. Resource drop-off hub and worker recruitment center."
	},
	BuildingType.HUT: {
		"name": "Hut",
		"icon": "🛖",
		"cost": {"wood": 20, "stone": 0},
		"size": Vector2i(2, 2),
		"footprint": Vector2i(2, 2),
		"build_time": 6.0,
		"max_health": 250,
		"vision_range": 6.0,
		"description": "Increases maximum settlement population capacity (+4 Pop)."
	},
	BuildingType.STORAGE: {
		"name": "Storage",
		"icon": "📦",
		"cost": {"wood": 35, "stone": 10},
		"size": Vector2i(2, 2),
		"footprint": Vector2i(2, 2),
		"build_time": 7.0,
		"max_health": 400,
		"vision_range": 8.0,
		"description": "Склад на 600 единиц. Рабочие доставляют сюда груз; наполнение отсеков видно на модели."
	},
	BuildingType.WALL: {
		"name": "Wall",
		"icon": "🧱",
		"cost": {"wood": 10, "stone": 0},
		"size": Vector2i(1, 1),
		"footprint": Vector2i(1, 1),
		"build_time": 3.0,
		"max_health": 300,
		"vision_range": 4.0,
		"description": "Fortified timber palisade blocking enemy pathways."
	},
	BuildingType.GATE: {
		"name": "Gate",
		"icon": "🚪",
		"cost": {"wood": 25, "stone": 0},
		"size": Vector2i(2, 1),
		"footprint": Vector2i(2, 1),
		"build_time": 5.0,
		"max_health": 450,
		"vision_range": 6.0,
		"description": "Reinforced wooden gate. Opens a passage for all units; close and lock it to stop raiders."
	},
	BuildingType.TOWER: {
		"name": "Tower",
		"icon": "🏹",
		"cost": {"wood": 40, "stone": 20},
		"size": Vector2i(2, 2),
		"footprint": Vector2i(2, 2),
		"build_time": 9.0,
		"max_health": 500,
		"vision_range": 14.0,
		"attack_range": 9.0,
		"attack_damage": 18,
		"attack_cooldown": 1.1,
		"description": "Automated ballistics tower. Shoots arrows at approaching hostiles."
	},
	BuildingType.WORKSHOP: {
		"name": "Workshop",
		"icon": "⚔️",
		"cost": {"wood": 50, "stone": 15},
		"size": Vector2i(3, 3),
		"footprint": Vector2i(3, 3),
		"build_time": 12.0,
		"max_health": 600,
		"vision_range": 8.0,
		"description": "Создаёт оружие и инструменты по очереди. Меч нужен рыцарю, лук — лучнику, топор — рабочему."
	},
	BuildingType.MINE: {
		"name": "Stone Mine",
		"icon": "⛏️",
		"cost": {"wood": 30, "stone": 0},
		"size": Vector2i(2, 2),
		"footprint": Vector2i(2, 2),
		"build_time": 8.0,
		"max_health": 400,
		"vision_range": 6.0,
		"description": "Шахтёру нужна кирка. Камень и железо ждут перевозчика у входа (до 60 единиц).",
		"upgrade_cost": {"wood": 40, "stone": 30},
		"upgrade_name": "Deep Ore Mine"
	},
	BuildingType.BARRACKS: {
		"name": "Barracks",
		"icon": "⚔️",
		"cost": {"wood": 50, "stone": 35},
		"size": Vector2i(3, 3),
		"footprint": Vector2i(3, 3),
		"build_time": 10.0,
		"max_health": 650,
		"vision_range": 10.0,
		"description": "Military garrison. Trains armored Knight Warriors and agile Marksman Archers."
	},
	BuildingType.FARM: {
		"name": "Farm", "icon": "🌾", "cost": {"wood": 35, "stone": 10},
		"footprint": Vector2i(3, 3), "build_time": 12.0, "max_health": 250, "vision_range": 5.0,
		"description": "Нужны вилы, 2 воды и колодец в 14 клетках. Урожай: 12 еды / 20 с; рабочие доставляют его на склад."
	},
	BuildingType.WELL: {
		"name": "Well", "icon": "💧", "cost": {"wood": 15, "stone": 25},
		"footprint": Vector2i(2, 2), "build_time": 10.0, "max_health": 350, "vision_range": 5.0,
		"description": "Produces 2 water every 5 seconds; irrigates farms within 14 tiles."
	}
	,BuildingType.PORT: {"name":"Порт","icon":"⚓","cost":{"wood":70,"stone":25},"footprint":Vector2i(3,2),"build_time":16.0,"max_health":700,"vision_range":10.0,"description":"Строится на ровном берегу рядом с водой. Производит лодки и транспортные галеры."}
}

static func get_config(type: BuildingType) -> Dictionary:
	return CONFIGS.get(type, CONFIGS[BuildingType.HUT]).duplicate(true)
