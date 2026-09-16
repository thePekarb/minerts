extends Node

var game: Main
var frames: int = 0
var failures: int = 0
var checks: int = 0
var spawned: bool = false
var moved_while_hidden: bool = false
var became_visible: bool = false
var reached_base: bool = false
var starts: Dictionary = {}
var reached_origins: Dictionary = {}

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
	else:
		print("PASS: ", description)

func _ready() -> void:
	SoundManager.is_muted = true
	game = load("res://scenes/Main.tscn").instantiate()
	add_child(game)
	game.time_of_day_system.time_of_day = 19.4 / 24.0
	EventBus.raid_spawned.connect(func(_wave, count):
		spawned = count > 0
		for enemy in game.raid_system.enemy_units:
			starts[enemy.get_instance_id()] = enemy.position
	)

func _physics_process(_delta: float) -> void:
	frames += 1
	for enemy in game.raid_system.enemy_units:
		var id: int = enemy.get_instance_id()
		if not starts.has(id):
			starts[id] = enemy.position
		if not enemy.visible and enemy.position.distance_to(starts[id]) > 5.0:
			moved_while_hidden = true
		if enemy.visible:
			became_visible = true
		if Vector2(enemy.position.x - 96.5, enemy.position.z - 96.5).length() < 12.0:
			reached_base = true
			if enemy.has_meta("test_origin"):
				reached_origins[enemy.get_meta("test_origin")] = true
	if frames == 180:
		check(game.raid_system.current_wave == 1 and spawned, "clock crossing 19:30 spawns the first wave automatically")
		check(game.hud.raid_status_label.text.contains("Врагов:"), "active wave stays visible in HUD despite fog")
		check(game.hud.minimap.raid_origins.size() == 1, "active altar is marked through fog")
	if frames == 3600:
		check(moved_while_hidden, "monsters move while hidden by fog")
		check(became_visible and reached_base, "night monsters enter visibility and reach the settlement")
		check(game.all_units.any(func(u): return u.faction == "player" and u.health < u.max_health), "night monsters attack nearby defenders before buildings")
		check(game.raid_system.enemy_units.is_empty(), "starting defenders repel the first wave")
		check(game.hud.raid_status_label.text.contains("отбита"), "HUD reports the completed attack")
		# Check missed-window regression without relying on a precise clock sample.
		game.time_of_day_system.set_process(false)
		game.raid_system._on_day_passed(2)
		game.raid_system._on_time_changed(23.5 / 24.0)
		check(game.raid_system.current_wave == 2 and game.raid_system.enemy_units.size() == 10, "late evening jump still creates the night's wave")
		game.raid_system._on_time_changed(23.8 / 24.0)
		check(game.raid_system.current_wave == 2, "repeated evening updates never duplicate the wave")
		for enemy in game.raid_system.enemy_units.duplicate():
			enemy.take_damage(99999)
		for u in game.all_units:
			u.attack_damage = 0.0
			u.set_physics_process(false)
		var camp: Building = game.all_buildings[0]
		camp.health = 100000
		camp.max_health = 100000
		for index in range(RaidSystem.ALTAR_POSITIONS.size()):
			var point: Vector2i = RaidSystem.ALTAR_POSITIONS[index]
			game.raid_system._spawn_and_dispatch_enemy(UnitConfigs.UnitType.ZOMBIE, Vector3(point.x + 0.5, 5, point.y + 0.5), camp.position, index)
			game.raid_system.enemy_units.back().set_meta("test_origin", index)
	if frames >= 7200:
		if reached_origins.size()!=4:
			for enemy in game.raid_system.enemy_units:
				print("RAID DEBUG ",enemy.get_meta("test_origin",-1)," pos ",enemy.position," target ",enemy.target," state ",enemy.state," path ",enemy.path.slice(enemy.waypoint_index,enemy.waypoint_index+4)," recovery ",enemy.navigation.recovery_count)
				for other in enemy.navigation.nearby:print("NEIGHBOR ",other.unit_type," ",other.position," faction ",other.faction)
				for i in range(enemy.get_slide_collision_count()):print("COLLISION ",enemy.get_slide_collision(i).get_collider())
		check(reached_origins.size() == 4, "real physics movement reaches base from all four altars")
		print("NIGHT RAID CHECKS: %d | FAILURES: %d" % [checks, failures])
		get_tree().quit(failures)
