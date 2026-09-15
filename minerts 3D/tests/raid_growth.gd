extends Node
var checks: int = 0
var failures: int = 0
func check(ok: bool,title: String) -> void:
	checks+=1
	if ok:print("PASS: ",title)
	else:failures+=1;push_error(title)
func _ready() -> void:
	SoundManager.is_muted=true
	var game: Main = load("res://scenes/Main.tscn").instantiate();add_child(game)
	game.set_process(false);game.goblin_ai.set_process(false);game.goblin_ai.expedition.set_process(false);game.guardian_system.set_process(false);game.time_of_day_system.set_process(false);game.wildlife_system.set_process(false);game.underground_system.set_process(false)
	var raid: RaidSystem = game.raid_system;raid.set_process(false)
	var count: int = 0
	var hp: float = 0.0
	for wave in range(1,6):
		raid.spawn_night_wave()
		check(raid.remaining_enemies()>count,"wave %d has more monsters than the previous wave" % wave)
		count=raid.remaining_enemies()
		check(raid.enemy_units[0].max_health>hp,"wave %d increases individual monster strength" % wave)
		hp=raid.enemy_units[0].max_health
		for enemy in raid.enemy_units.duplicate():enemy.take_damage(999999)
		raid.reinforcements.clear()
	raid.current_wave=20;raid.spawn_night_wave()
	check(raid.enemy_units.size()==64 and raid.reinforcements.size()==60,"large waves use bounded active units and queued reinforcements")
	var before: int = raid.remaining_enemies()
	raid.enemy_units[0].take_damage(999999);raid._spawn_reinforcements(4)
	check(raid.enemy_units.size()==64 and raid.remaining_enemies()==before-1,"a slain raider frees a slot for a reinforcement without duplicating the wave")
	game.hud.update_raid_display(raid,game.time_of_day_system)
	check(game.hud.raid_status_label.text.contains(str(raid.remaining_enemies())),"HUD counts pending reinforcements as part of the wave")
	print("RAID GROWTH CHECKS: %d | FAILURES: %d" % [checks,failures]);get_tree().quit(failures)
