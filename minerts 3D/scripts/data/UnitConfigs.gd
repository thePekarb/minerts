class_name UnitConfigs
extends RefCounted

enum UnitType {
	WORKER = 0,
	SCOUT = 1,
	GUARD = 2,
	WARRIOR = 2,
	ARCHER = 3,
	ENEMY_MELEE = 4,
	RAIDER = 4,
	ENEMY_FAST = 5,
	ZOMBIE = 6,
	SKELETON = 7,
	SPIDER = 8,
	CREEPER = 9,
	DEER = 10,
	BOAR = 11,
	RABBIT = 12,
	WOLF = 13,
	BEAR = 14,
	GOBLIN_WORKER = 15,
	GOBLIN_WARRIOR = 16,
	GOBLIN_ARCHER = 17,
	GOBLIN_SPEARMAN = 18,
	SPIDER_RIDER = 19,
	TROLL = 20,
	BOAT = 21,
	GALLEY = 22,
	ANCIENT_GOLEM = 23,
	STORM_WARDEN = 24
}

enum UnitState {
	IDLE,
	MOVING,
	GATHERING,
	BUILDING,
	ATTACKING,
	FLEEING,
	DEFENDING,
	DEAD,
	RETURNING_TO_STORAGE,
	MINING_INSIDE
}

enum UnitOrder {
	MOVE,
	ATTACK,
	GATHER,
	BUILD,
	PATROL,
	DEFEND,
	INTERACT,
	RETREAT
}

const CONFIGS: Dictionary = {
	UnitType.WORKER: {
		"name": "Worker",
		"icon": "⛏️",
		"health": 60,
		"max_health": 60,
		"speed": 3.8,
		"damage": 4,
		"attack_range": 1.4,
		"attack_cooldown": 1.2,
		"inventory_capacity": 14,
		"vision_range": 6.0,
		"cost": {"food": 20},
		"description": "Hardworking villager. Gathers resources, constructs buildings, and operates quarries."
	},
	UnitType.SCOUT: {
		"name": "Scout",
		"icon": "🧭",
		"health": 75,
		"max_health": 75,
		"speed": 6.5,
		"damage": 7,
		"attack_range": 1.5,
		"attack_cooldown": 0.9,
		"inventory_capacity": 5,
		"vision_range": 12.0,
		"cost": {"food": 25, "wood": 10},
		"description": "Swift explorer. High movement speed, great vision for uncovering the map."
	},
	UnitType.GUARD: {
		"name": "Knight Warrior",
		"icon": "⚔️",
		"health": 180,
		"max_health": 180,
		"speed": 3.3,
		"armor": 3.0,
		"damage": 18,
		"attack_range": 1.6,
		"attack_cooldown": 1.0,
		"inventory_capacity": 0,
		"vision_range": 8.0,
		"cost": {"food": 30, "wood": 10, "stone": 10},
		"description": "Armored knight with sword and shield. High health, delivers devastating melee slashes."
	},
	UnitType.ARCHER: {
		"name": "Archer",
		"icon": "🏹",
		"health": 70,
		"max_health": 70,
		"speed": 4.4,
		"damage": 14,
		"attack_range": 7.5,
		"ranged": true,
		"attack_cooldown": 1.3,
		"inventory_capacity": 0,
		"vision_range": 9.0,
		"cost": {"food": 25, "wood": 20},
		"description": "Ranged marksman. Attacks enemy invaders from safe distance."
	},
	UnitType.ENEMY_MELEE: {
		"name": "Shadow Raider",
		"icon": "👹",
		"health": 90,
		"max_health": 90,
		"speed": 3.4,
		"damage": 12,
		"attack_range": 1.5,
		"attack_cooldown": 1.2,
		"inventory_capacity": 0,
		"vision_range": 7.0,
		"cost": {},
		"description": "Hostile night raider emerging from highlands cave."
	},
	UnitType.ENEMY_FAST: {
		"name": "Night Fiend",
		"icon": "🦇",
		"health": 55,
		"max_health": 55,
		"speed": 5.8,
		"damage": 9,
		"attack_range": 1.4,
		"attack_cooldown": 0.8,
		"inventory_capacity": 0,
		"vision_range": 7.0,
		"cost": {},
		"description": "Fast nocturnal beast that flanks defenders."
	},
	UnitType.ZOMBIE: {
		"name": "Zombie", "icon": "Z", "health": 100, "speed": 2.6,
		"damage": 11, "attack_range": 1.45, "attack_cooldown": 1.35,
		"vision_range": 9.0, "cost": {}, "description": "Slow, durable frontline undead."
	},
	UnitType.SKELETON: {
		"name": "Skeleton Archer", "icon": "S", "health": 55, "speed": 3.0,
		"damage": 10, "attack_range": 7.0, "attack_cooldown": 1.7, "ranged": true,
		"vision_range": 10.0, "cost": {}, "description": "Fragile ranged support. Close the distance with knights."
	},
	UnitType.SPIDER: {
		"name": "Night Spider", "icon": "S", "health": 45, "speed": 5.4,
		"damage": 7, "attack_range": 1.35, "attack_cooldown": 0.65,
		"vision_range": 8.0, "cost": {}, "description": "Fast flanker. Armor greatly reduces its bite damage."
	},
	UnitType.CREEPER: {
		"name": "Creeper", "icon": "!", "health": 45, "speed": 3.0,
		"damage": 0, "attack_range": 2.0, "attack_cooldown": 1.0,
		"fuse_seconds": 1.6, "blast_radius": 3.2, "blast_damage": 65.0,
		"vision_range": 8.0, "cost": {}, "description": "Stops and flashes before exploding. Retreat or shoot it during the fuse."
	},
	UnitType.DEER: {"name": "Deer", "icon": "🦌", "health": 35, "speed": 5.0, "damage": 0, "food_loot": 18, "cost": {}},
	UnitType.BOAR: {"name": "Boar", "icon": "🐗", "health": 65, "speed": 3.8, "damage": 8, "attack_range": 1.3, "attack_cooldown": 1.0, "food_loot": 25, "cost": {}},
	UnitType.RABBIT: {"name": "Rabbit", "icon": "🐇", "health": 12, "speed": 5.8, "damage": 0, "food_loot": 6, "cost": {}}

	,UnitType.WOLF: {"name":"Лесной волк","icon":"🐺","health":65,"speed":5.3,"damage":10,"attack_range":1.35,"attack_cooldown":1.0,"food_loot":22,"cost":{}},
	UnitType.BEAR: {"name":"Бурый медведь","icon":"🐻","health":240,"armor":2,"speed":3.2,"damage":26,"attack_range":1.9,"attack_cooldown":1.7,"food_loot":65,"cost":{}},
	UnitType.GOBLIN_WORKER: {"name":"Гоблин-сборщик","icon":"⛏","health":55,"speed":4.0,"damage":4,"attack_range":1.3,"attack_cooldown":1.2,"inventory_capacity":14,"vision_range":7,"cost":{"food":18},"train_time":8},
	UnitType.GOBLIN_WARRIOR: {"name":"Гоблин-рубака","icon":"⚔","health":125,"armor":2,"speed":3.9,"damage":14,"attack_range":1.5,"attack_cooldown":0.95,"vision_range":8,"cost":{"food":24,"wood":12},"train_time":13},
	UnitType.GOBLIN_ARCHER: {"name":"Гоблин-лучник","icon":"🏹","health":60,"speed":4.2,"damage":12,"attack_range":7,"attack_cooldown":1.3,"ranged":true,"vision_range":9,"cost":{"food":22,"wood":20},"train_time":12},
	UnitType.GOBLIN_SPEARMAN: {"name":"Гоблин-копейщик","icon":"🔱","health":95,"speed":3.8,"damage":17,"attack_range":2.6,"attack_cooldown":1.25,"vision_range":8,"cost":{"food":24,"wood":16},"train_time":14},
	UnitType.SPIDER_RIDER: {"name":"Паучий наездник","icon":"🕷","health":145,"speed":5.2,"damage":15,"attack_range":7.5,"attack_cooldown":1.4,"ranged":true,"vision_range":11,"cost":{"food":40,"wood":25,"ore":5},"train_time":22},
	UnitType.TROLL: {"name":"Тролль","icon":"🛡","health":420,"armor":5,"speed":2.3,"damage":32,"attack_range":2.0,"attack_cooldown":1.9,"vision_range":7,"cost":{"food":65,"stone":25},"train_time":30},
	UnitType.BOAT: {"name":"Лодка","icon":"⛵","health":200,"speed":6.5,"damage":0,"vision_range":10,"vessel":true,"capacity":4,"cost":{"wood":45,"food":10},"train_time":18},
	UnitType.GALLEY: {"name":"Транспортная галера","icon":"🚢","health":550,"armor":2,"speed":5.2,"damage":0,"vision_range":13,"vessel":true,"capacity":10,"cost":{"wood":110,"stone":25,"food":25},"train_time":32},
	UnitType.ANCIENT_GOLEM: {"name":"Каменный исполин","icon":"◆","health":1100,"armor":8,"speed":2.2,"damage":42,"attack_range":2.2,"attack_cooldown":2.0,"vision_range":16,"cost":{},"description":"Страж руин. Заряжает круговой удар по земле; выйдите из отмеченного круга."},
	UnitType.STORM_WARDEN: {"name":"Грозовой хранитель","icon":"ϟ","health":620,"armor":4,"speed":3.5,"damage":28,"attack_range":9,"attack_cooldown":1.5,"ranged":true,"vision_range":18,"cost":{},"description":"Дальний страж сокровищ. Призывает отмеченный разряд в точке противника."}

}

static func get_config(type: UnitType) -> Dictionary:
	return CONFIGS.get(type, CONFIGS[UnitType.WORKER]).duplicate(true)

static func is_worker(type: UnitType) -> bool:
	return type in [UnitType.WORKER,UnitType.GOBLIN_WORKER]
static func is_vessel(type: UnitType) -> bool:
	return type in [UnitType.BOAT,UnitType.GALLEY]
static func training_time(type: UnitType) -> float:
	return float(get_config(type).get("train_time",8.0 if is_worker(type) else 14.0))
