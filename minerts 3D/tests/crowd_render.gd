extends Node3D
var all_units: Array[Unit] = []
var camera: RTSCamera
var visuals: UnitVisualSystem
var checks: int = 0
var failures: int = 0
var profile: Array[Dictionary] = []

func check(ok: bool,title: String) -> void:
	checks+=1
	if ok:print("PASS: ",title)
	else:failures+=1;push_error(title)

func _ready() -> void:
	SoundManager.is_muted=true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var environment := WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("293c48")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE
	environment.environment.ambient_light_energy=.6
	add_child(environment)
	var light := DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-35,0);light.light_energy=1.3;add_child(light)
	camera=RTSCamera.new();camera.target_focus=Vector3(10,0,10);camera.target_zoom=22;add_child(camera);camera.set_process(false)
	visuals=UnitVisualSystem.new();add_child(visuals);visuals.setup(self)
	visuals.mode=1
	for row in range(2):
		for i in range(6):
			var type: int = [0,2,7,15,19,24][i]
			var unit := Unit.new();unit.unit_type=type;unit.position=Vector3(3+i*2.8,0,7+row*6);add_child(unit);all_units.append(unit)
			unit.set_physics_process(false);unit.is_selected=row==0
			unit.state=UnitConfigs.UnitState.MOVING;unit.navigation.actual_speed=3.8;unit._update_animation_and_tools(.016)
	for i in range(60):await get_tree().process_frame
	check(visuals.batched_count==6 and visuals.skeleton_count==6,"near selected skeletons and far baked models coexist")
	check(all_units[0].anim_player.active and not all_units[6].anim_player.active,"batched actors suspend their individual animation players")
	check(visuals.batches.values().all(func(b):return b.mesh.mesh.get_surface_count()==1),"baked character materials merge into one surface per batch")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://art/crowd-comparison.png")
	all_units[6].set_selected(true)
	visuals.update_visuals()
	check(all_units[6].model_root.visible and all_units[6].anim_player.active,"selecting a batched unit restores its full skeleton")
	all_units[7].visual_focus=true;visuals.update_visuals()
	check(all_units[7].model_root.visible,"hover focus restores the mesh used for interaction highlighting")
	all_units[7].visual_focus=false
	all_units[7].visible=false;visuals.update_visuals()
	check(visuals.batched_count==4,"hidden units are removed from the instance buffer")
	all_units[7].visible=true;all_units[7].embarked_in=all_units[0];visuals.update_visuals()
	check(visuals.batched_count==4,"embarked passengers never leak into the crowd renderer")
	for unit in all_units:unit.queue_free()
	all_units.clear();await get_tree().process_frame
	await get_tree().process_frame
	check(visuals.batches.is_empty(),"despawning the last actor releases empty rendering batches")
	# Real imported rigs, meshes, materials and physics bodies. Navigation is disabled
	# to isolate the renderer; these numbers are not complete campaign frame times.
	for count in [50,200,1000]:
		var cols: int = ceili(sqrt(count))
		for i in range(count):
			var unit := Unit.new();unit.unit_type=UnitConfigs.UnitType.GOBLIN_WARRIOR
			unit.position=Vector3(3+(i%cols)*1.5,0,3+(i/cols)*1.5);add_child(unit);all_units.append(unit)
			unit.set_physics_process(false);unit.state=UnitConfigs.UnitState.MOVING;unit.navigation.actual_speed=3.8;unit._update_animation_and_tools(.016)
		camera.current_focus=Vector3(3+cols*.75,0,3+cols*.75);camera.current_zoom=maxf(32,cols*2.5);camera._update_transform()
		for render_mode in [2,1]:
			visuals.mode=render_mode
			for i in range(45):await get_tree().process_frame
			var times: Array[float] = []
			var draw_calls: float = 0
			var physics_ms: float = 0
			for i in range(90):
				var start: int = Time.get_ticks_usec()
				await get_tree().process_frame
				times.append((Time.get_ticks_usec()-start)/1000.0)
				draw_calls+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
				physics_ms+=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000
			times.sort()
			var result: Dictionary = {"units":count,"mode":"skeleton" if render_mode==2 else "baked","p50_ms":times[45],"p95_ms":times[85],"p99_ms":times[89],"draw_calls":draw_calls/90,"physics_ms":physics_ms/90,"batches":visuals.batches.size(),"batched":visuals.batched_count}
			profile.append(result);print("CROWD PROFILE ",JSON.stringify(result))
		for unit in all_units:unit.queue_free()
		all_units.clear();await get_tree().process_frame
	var report := FileAccess.open("res://art/test-results/crowd_profile.json",FileAccess.WRITE)
	report.store_string(JSON.stringify(profile,"\t"));report.close()
	print("CROWD RENDER CHECKS: %d | FAILURES: %d" % [checks,failures]);get_tree().quit(failures)
