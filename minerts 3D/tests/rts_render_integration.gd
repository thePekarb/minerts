extends Node
var failures: int = 0
var checks: int = 0
func check(ok: bool, message: String) -> void:
	checks+=1
	if ok:print("PASS: ",message)
	else:failures+=1;push_error(message)
func _ready() -> void:
	SoundManager.is_muted=true
	var game: Main = load("res://scenes/Main.tscn").instantiate();add_child(game)
	game.time_of_day_system.time_of_day=.4;game.time_of_day_system._update_lighting()
	game.camera.target_zoom=45;game.camera.target_focus=Vector3(96,0,96)
	for i in range(90):await get_tree().process_frame
	check(game.unit_visuals.batched_count>0,"main scene uses baked crowds at overview zoom")
	var unit: Unit = game.all_units.filter(func(u):return u.faction=="player")[0]
	var goal: Vector3 = game.grid_manager.find_free_position(unit.position+Vector3(-4,0,0))
	var start: Vector3 = unit.position
	game.selection_system.cancel_assignments(unit)
	unit.current_order=UnitConfigs.UnitOrder.MOVE;unit.target=null
	unit.set_path(game.grid_manager.find_unit_path(unit,goal));unit.state=UnitConfigs.UnitState.MOVING
	for i in range(240):await get_tree().physics_frame
	check(unit.position.distance_to(start)>1,"batched units continue physical movement in the actual world")
	unit.set_selected(true);game.unit_visuals.update_visuals()
	check(unit.model_root.visible and unit.anim_player.active,"selection restores the live model in the main scene")
	check(game.all_units.filter(func(u):return u.faction!="player" and not u.visible).all(func(u):return u.visual_suspended),"unseen hostiles remain excluded from crowd presentation")
	var prop: Node3D
	for object in game.resource_spawner.resources.values():
		if is_instance_valid(object) and object.is_visible_in_tree() and object.position.distance_to(game.camera.current_focus)<24:
			prop=object;break
	check(is_instance_valid(prop) and game.prop_batches.instance_count>0,"real resources use spatial mesh batches")
	if is_instance_valid(prop):
		var meshes: Array[Node] = prop.find_children("*","MeshInstance3D",true,false)
		prop.set_meta("visual_focus",true);game.prop_batches.update_batches()
		check(meshes.all(func(m):return m.visible),"hover restores original resource meshes for highlighting")
		prop.set_meta("visual_focus",false);game.prop_batches.update_batches()
		check(meshes.all(func(m):return not m.visible),"ending hover returns resource rendering to its batch")
		prop.hide();game.prop_batches.update_batches()
		var count_hidden: int = 0
		for group in game.prop_batches.groups.values():count_hidden+=group.node.multimesh.instance_count
		prop.show();game.prop_batches.update_batches()
		var count_shown: int = 0
		for group in game.prop_batches.groups.values():count_shown+=group.node.multimesh.instance_count
		check(count_shown==count_hidden+meshes.size(),"visibility removes hidden resource instances and restores them without duplicates")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://art/rts-overview.png")
	print("RTS RENDER INTEGRATION CHECKS: %d | FAILURES: %d" % [checks,failures]);get_tree().quit(failures)
