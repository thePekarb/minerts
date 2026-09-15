extends Node
var checks: int = 0
var failures: int = 0
func check(ok: bool,text: String) -> void:
	checks+=1
	if ok:print("PASS: ",text)
	else:failures+=1;push_error(text)
func _ready() -> void:
	SoundManager.is_muted=true
	var game: Main = load("res://scenes/Main.tscn").instantiate();add_child(game)
	var hud: HUD = game.hud
	await get_tree().process_frame
	check(hud.skin.build_tiles.size()==12,"all twelve building cards remain available")
	hud.skin.filter_buildings(4)
	check(hud.skin.build_tiles.values().filter(func(b):return b.visible).size()==5,"resource category filters the live building catalog")
	hud.skin.filter_buildings(0)
	hud.skin.build_tiles[1].pressed.emit()
	check(game.construction_system.is_placing(),"illustrated hut card starts actual construction placement")
	game.construction_system.cancel_placement()
	var worker: Unit = game.all_units[0]
	game.selection_system.select_single_unit(worker,false)
	hud.skin.update_inspector()
	check(hud.inspector.visible and hud.skin.portrait.visible and hud.inspector_title.text=="Рабочий","worker selection opens the live portrait inspector")
	hud.skin.command("gather")
	check(hud.skin.command_mode=="gather","gather action arms a real contextual order")
	worker.inventory={"type":"wood","amount":5}
	hud.skin.command("carry")
	check(worker.current_order==UnitConfigs.UnitOrder.GATHER and worker.target is Building and not worker.path.is_empty(),"carry command returns existing cargo to storage")
	hud.skin.command("stop")
	check(worker.path.is_empty() and worker.target==null and worker.inventory.amount==5,"cancel stops the order without losing the carried resource")
	hud.skin.command("dig")
	check(game.underground_system.cutaway,"dig command opens the underground view")
	game.underground_system.toggle_view()
	hud.skin.set_quality(1)
	check(is_equal_approx(game.get_viewport().scaling_3d_scale,.6),"performance setting scales only the 3D viewport")
	hud.skin.set_quality(0)
	hud.skin.toggle_pause()
	check(get_tree().paused and hud.skin.pause_button.process_mode==Node.PROCESS_MODE_ALWAYS,"pause keeps its resume control interactive")
	hud.skin.toggle_pause()
	check(not get_tree().paused,"resume restores simulation")
	game.selection_system.select_building(game.all_buildings[0]);hud.skin.update_inspector()
	check(hud.train_worker_btn.visible and hud.inspector_action_box.visible,"new inspector preserves production controls")
	print("HUD CONTROLS CHECKS: %d | FAILURES: %d" % [checks,failures]);get_tree().quit(failures)
