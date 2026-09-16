class_name GameSettingsAutoload
extends Node

# Player info
var player_name: String = "Tanakron"
var player_faction: String = "player" # "player" = Королевство (Kingdom), "goblin" = Клан гоблинов (Goblin Clan)
var player_color: Color = Color("38bdf8") # Blue

# Match parameters
var map_name: String = "Озёрная долина"
var map_size: String = "medium" # "small", "medium", "large"
var biome: String = "forest" # "forest", "mountains", "desert", "islands"
var difficulty: String = "normal" # "easy", "normal", "hard"
var resources_richness: float = 1.0 # 0.5 (бедное), 1.0 (нормальное), 1.5 (богатое)
var enemy_count: float = 1.0 # 0.5 (мало), 1.0 (нормально), 1.5 (много)
var night_wave_enabled: bool = true
var fog_enabled: bool = true
var day_night_enabled: bool = true
var starting_resources: String = "standard" # "light", "standard", "hardcore"
var seed_val: int = 482719306

# Multiplayer / Lobby state
var is_multiplayer: bool = false
var room_name: String = "Наше королевство"
var room_mode: String = "coop" # "coop" or "pvp"
var room_code: String = "7F3K9"
var max_players: int = 4

# Lobby slots: array of 4 slot dictionaries
# Each slot: {"type": "player"|"bot"|"open", "name": String, "faction": "player"|"goblin", "team": "blue"|"red"|"yellow"|"green", "ready": bool, "peer_id": int, "ping": int, "is_host": bool}
var lobby_slots: Array[Dictionary] = []

func _ready() -> void:
	reset_defaults()

func reset_defaults() -> void:
	player_faction = "player"
	is_multiplayer = false
	seed_val = 482719306
	night_wave_enabled = true
	fog_enabled = true
	day_night_enabled = true
	resources_richness = 1.0
	enemy_count = 1.0
	difficulty = "normal"
	map_size = "medium"
	map_name = "Озёрная долина"

	lobby_slots = [
		{
			"type": "player",
			"name": player_name,
			"faction": "player",
			"team": "Синяя команда",
			"ready": true,
			"peer_id": 1,
			"ping": 20,
			"is_host": true
		},
		{
			"type": "bot",
			"name": "Бот 1 (Гоблины)",
			"faction": "goblin",
			"team": "Красная команда",
			"ready": true,
			"peer_id": 0,
			"ping": 0,
			"is_host": false
		},
		{
			"type": "bot",
			"name": "Бот 2 (Королевство)",
			"faction": "player",
			"team": "Желтая команда",
			"ready": true,
			"peer_id": 0,
			"ping": 0,
			"is_host": false
		},
		{
			"type": "bot",
			"name": "Бот 3 (Королевство)",
			"faction": "player",
			"team": "Зеленая команда",
			"ready": true,
			"peer_id": 0,
			"ping": 0,
			"is_host": false
		},
		{
			"type": "bot",
			"name": "Бот 4 (Гоблины)",
			"faction": "goblin",
			"team": "Фиолетовая команда",
			"ready": true,
			"peer_id": 0,
			"ping": 0,
			"is_host": false
		},
		{
			"type": "open",
			"name": "Свободный слот",
			"faction": "player",
			"team": "Оранжевая команда",
			"ready": false,
			"peer_id": 0,
			"ping": 0,
			"is_host": false
		}
	]

func randomize_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	seed_val = rng.randi_range(100000000, 999999999)
	return seed_val

func get_active_slots() -> Array:
	return lobby_slots.filter(func(s): return s.get("type", "") in ["player", "bot"])

func get_participant_count() -> int:
	var count: int = get_active_slots().size()
	return maxi(1, count)

func get_local_player_slot_index() -> int:
	if not is_multiplayer:
		return 0
	# Find local player slot by peer_id or host status
	for i in range(get_active_slots().size()):
		var slot: Dictionary = get_active_slots()[i]
		if slot.get("type", "") == "player":
			if NetworkManager.is_host() and slot.get("is_host", false):
				return i
			if slot.get("peer_id", 0) == NetworkManager.local_peer_id and NetworkManager.local_peer_id > 1:
				return i
	return 0

func add_bot_to_slot(slot_idx: int, faction: String = "goblin", team: String = "") -> void:
	if slot_idx < 0 or slot_idx >= lobby_slots.size():
		return
	var faction_name: String = "Гоблины" if faction == "goblin" else "Королевство"
	var default_team: String = team if not team.is_empty() else ("Красная команда" if slot_idx == 1 else ("Желтая команда" if slot_idx == 2 else ("Зеленая команда" if slot_idx == 3 else "Фиолетовая команда")))
	lobby_slots[slot_idx] = {
		"type": "bot",
		"name": "Бот (%s #%d)" % [faction_name, slot_idx],
		"faction": faction,
		"team": default_team,
		"ready": true,
		"peer_id": 0,
		"ping": 0,
		"is_host": false
	}

func clear_slot(slot_idx: int) -> void:
	if slot_idx <= 0 or slot_idx >= lobby_slots.size():
		return # Host cannot clear slot 0
	lobby_slots[slot_idx] = {
		"type": "open",
		"name": "Свободный слот",
		"faction": "player",
		"team": "Свободно",
		"ready": false,
		"peer_id": 0,
		"ping": 0,
		"is_host": false
	}

