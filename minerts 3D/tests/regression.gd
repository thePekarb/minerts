extends Node

var failures: int = 0

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)
	else:
		print("PASS: ", description)

func _ready() -> void:
	# Dummy audio does not mix playback on headless runs; validate PCM directly.
	SoundManager.is_muted = true
	var game: Main = load("res://scenes/Main.tscn").instantiate()
	add_child(game)
	game.set_process(false)
	game.time_of_day_system.set_process(false)
	check(EconomyManager.current_population == 5, "initial population matches three workers and two defenders")
	check(SoundManager.sound_cache.has("pop") and SoundManager.sound_cache.has("hit"), "combat sounds generated")
	SoundManager.play_pop()
	SoundManager.play_hit()
	check(SoundManager.sound_cache.pop.data.size() > 0 and SoundManager.sound_cache.hit.data.size() > 0, "combat audio contains PCM samples")
	var warrior: Unit = game.spawn_unit(UnitConfigs.UnitType.WARRIOR, "player", Vector3(60.5, 0, 60.5))
	var enemy: Unit = game.spawn_unit(UnitConfigs.UnitType.RAIDER, "enemy", Vector3(61, 0, 60.5))
	warrior.target = enemy
	warrior.current_order = UnitConfigs.UnitOrder.ATTACK
	warrior.attack_timer = warrior.attack_cooldown
	enemy.health = 1
	game.selection_system.select_single_unit(warrior)
	var wood: int = EconomyManager.resources.wood
	var stone: int = EconomyManager.resources.stone
	game.combat_system.process_combat(0.1, game.all_units, game.all_buildings)
	check(not enemy.is_alive and enemy.is_queued_for_deletion(), "combat death cleans up node")
	check(EconomyManager.resources.wood == wood + 5 and EconomyManager.resources.stone == stone + 3, "loot awarded once")
	enemy.take_damage(999)
	check(EconomyManager.resources.wood == wood + 5, "repeated damage does not duplicate loot")
	warrior.take_damage(999)
	check(game.selection_system.selected_units.is_empty(), "dead selection cleared")
	check(EconomyManager.current_population == 5, "death releases population")
	var hidden: Unit = game.spawn_unit(UnitConfigs.UnitType.RAIDER, "enemy", Vector3(5, 0, 5))
	game.fog_system.update_fog(game.all_units, game.all_buildings, 0.3)
	hidden._process(0.016)
	check(not hidden.visible, "unit process preserves fog hiding")
	check(game.hud.minimap.fog_texture != null, "minimap fog texture exists")
	var hut: Building = Building.new()
	game.buildings_container.add_child(hut)
	hut.init_building(BuildingConfigs.BuildingType.HUT, 59, 59, true)
	game.all_buildings.append(hut)
	EventBus.building_constructed.emit(hut)
	check(EconomyManager.max_population == 14, "completed hut adds capacity")
	hut.take_damage(9999)
	check(EconomyManager.max_population == 10, "destroyed hut removes capacity")
	game.time_of_day_system.time_of_day = 0.7499
	game.time_of_day_system._update_lighting()
	var before: float = game.sun_light.light_energy
	game.time_of_day_system.time_of_day = 0.7501
	game.time_of_day_system._update_lighting()
	check(absf(before - game.sun_light.light_energy) < 0.01, "sunset lighting is continuous")
	await get_tree().process_frame
	game.combat_system.process_combat(0.1, game.all_units, game.all_buildings)
	print("REGRESSION FAILURES: ", failures)
	if not SoundManager.is_muted:
		SoundManager.toggle_mute()
	await get_tree().create_timer(0.1).timeout
	game.queue_free()
	await get_tree().process_frame
	get_tree().quit(failures)
