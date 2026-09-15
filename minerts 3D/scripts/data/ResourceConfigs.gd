class_name ResourceConfigs
extends RefCounted

enum ResourceType {
	WOOD,
	STONE,
	FOOD,
	ORE,
	LOOT
}

const STARTING_RESOURCES: Dictionary = {
	"wood": 120,
	"stone": 40,
	"food": 80,
	"ore": 0,
	"pop": 4,
	"max_pop": 10
}
