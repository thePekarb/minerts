extends Node
func _ready() -> void:
	SoundManager.is_muted=true
	var game: Main = load("res://scenes/Main.tscn").instantiate();add_child(game)
	game.goblin_ai.set_process(false);game.goblin_ai.expedition.set_process(false);game.time_of_day_system.set_process(false);game.guardian_system.set_process(false)
	game.time_of_day_system.time_of_day=.4;game.time_of_day_system._update_lighting()
	var lair: Dictionary = game.guardian_system.lairs[0]
	var boss: Unit = lair.unit.get_ref()
	var scout: Unit = game.spawn_unit(UnitConfigs.UnitType.SCOUT,"player",game.grid_manager.find_free_position(boss.position+Vector3(4,0,3)))
	scout.config.vision_range=20;scout.set_physics_process(false)
	game.guardian_system._charge(lair,scout)
	game.camera.target_focus=boss.position;game.camera.current_focus=boss.position;game.camera.target_zoom=17;game.camera.current_zoom=17;game.camera._update_transform()
	for i in range(30):await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://art/guardian-gameplay.png")
	get_tree().quit()
