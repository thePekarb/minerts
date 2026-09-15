class_name Tile
extends RefCounted

enum Biome {
	PLAINS,
	FOREST,
	ROCK,
	SAND,
	WATER,
	SNOW,
	MARSH
}

var x: int
var z: int
var height: int
var biome: Biome
var walkable: bool = true

var resource_id: String = ""
var building_id: String = ""
var is_gate: bool = false
var is_gate_open: bool = false
var is_gate_locked: bool = false

var explored: bool = false
var visible: bool = false
var is_explored: bool = false
var is_visible: bool = false

func _init(_x: int, _z: int, _height: int, _biome: Biome, _walkable: bool) -> void:
	x = _x
	z = _z
	height = _height
	biome = _biome
	walkable = _walkable

func is_occupied() -> bool:
	return not walkable or resource_id != "" or (building_id != "" and not is_gate)

func is_walkable_for(faction: String = "player") -> bool:
	if not walkable or resource_id != "":
		return false
	if building_id != "":
		if is_gate:
			return is_gate_open and not is_gate_locked
		return false
	return true
