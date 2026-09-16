class_name TouchRTSController
extends Node
# World gestures are consumed before emulated mouse events; native GUI keeps mouse emulation.
var game: Main
var fingers: Dictionary={}
var origins: Dictionary={}
var held: float=0.0
var moved: bool=false
var multi: bool=false
var selecting: bool=false
var drawing: bool=false
var touch_enabled: bool=false
var last_world_touch: int=-1000
var last_tap: int=-1000
var last_tapped: Unit
var last_position: Vector2
func setup(main: Main) -> void:
	game=main;touch_enabled=DeviceLayout.is_mobile()
func over_ui(point: Vector2) -> bool:
	for child in game.hud.get_children():
		if child is Control and child.is_visible_in_tree() and child.mouse_filter!=Control.MOUSE_FILTER_IGNORE and child.get_global_rect().has_point(point):return true
	return false
func _input(event: InputEvent) -> void:
	if event is InputEventMouse and event.device==InputEvent.DEVICE_ID_EMULATION and Time.get_ticks_msec()-last_world_touch<250:
		get_viewport().set_input_as_handled();return
	if event is InputEventScreenTouch:
		if event.pressed:
			if over_ui(event.position):return
			touch_enabled=true;fingers[event.index]=event.position;origins[event.index]=event.position
			last_position=event.position
			if fingers.size()==1:
				held=0;moved=false;multi=false;selecting=false
				drawing=game.lumber_zone_system.is_placing_zone or game.terraforming_system.is_active
				if drawing:game._handle_left_mouse_down(event.position)
			else:
				multi=true;selecting=false;game.hud.selection_box.stop_box()
		elif fingers.has(event.index):
			if fingers.size()==1 and not multi:
				if drawing:game._handle_left_mouse_up(event.position)
				elif selecting:
					game.selection_system.select_units_in_box(origins[event.index],event.position,game.all_units);game.hud.selection_box.stop_box()
				elif not moved:_tap(event.position)
			fingers.erase(event.index);origins.erase(event.index)
		else:return
		last_world_touch=Time.get_ticks_msec();get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and fingers.has(event.index):
		var previous: Vector2=fingers[event.index]
		fingers[event.index]=event.position;last_position=event.position
		if fingers.size()>=2:
			var other: int=fingers.keys()[0] if fingers.keys()[0]!=event.index else fingers.keys()[1]
			var old_vector: Vector2=previous-fingers[other];var new_vector: Vector2=event.position-fingers[other]
			if old_vector.length()>20 and new_vector.length()>20:
				game.camera.target_zoom=clampf(game.camera.target_zoom*old_vector.length()/new_vector.length(),game.camera.min_zoom,game.camera.max_zoom)
				game.camera.target_yaw-=old_vector.angle_to(new_vector)
			pan((event.position-previous)*.5)
		elif drawing:game._handle_mouse_motion(event.position)
		elif game.construction_system.is_placing():game.construction_system.update_ghost(event.position)
		elif selecting:game.hud.selection_box.update_box(event.position)
		elif event.position.distance_to(origins[event.index])>10 or moved:
			moved=true;pan(event.position-previous)
		last_world_touch=Time.get_ticks_msec();get_viewport().set_input_as_handled()
func _process(delta: float) -> void:
	if fingers.size()!=1 or moved or multi or drawing or game.construction_system.is_placing():return
	held+=delta
	if held>=.45 and not selecting:
		selecting=true;game.hud.selection_box.start_box(origins.values()[0])
func pan(relative: Vector2) -> void:
	var cam: RTSCamera=game.camera
	var right:=Vector3(cos(cam.target_yaw),0,-sin(cam.target_yaw))
	var forward:=Vector3(sin(cam.target_yaw),0,cos(cam.target_yaw))
	cam.target_focus-=(right*relative.x+forward*relative.y)*cam.current_zoom/maxf(160,get_viewport().get_visible_rect().size.y)
	cam.target_focus.x=clampf(cam.target_focus.x,0,511);cam.target_focus.z=clampf(cam.target_focus.z,0,511)
func _tap(point: Vector2) -> void:
	if game.construction_system.is_placing():game.construction_system.update_ghost(point);return
	if game.is_demolish_mode:game._handle_left_mouse_down(point);return
	var hit: Dictionary=game.camera.raycast_objects(point)
	var target=hit.get("collider")
	if target is Unit and target.faction=="player":
		if target==last_tapped and Time.get_ticks_msec()-last_tap<350:
			game.selection_system.clear_selection()
			for unit in game.all_units:
				if unit.faction=="player" and unit.unit_type==target.unit_type and unit.is_alive and unit.is_visible_in_tree() and get_viewport().get_visible_rect().has_point(game.camera.unproject_position(unit.position)):game.selection_system.select_single_unit(unit,true)
		else:game._handle_single_click(point)
		last_tapped=target;last_tap=Time.get_ticks_msec()
	elif not game.selection_system.selected_units.is_empty():game._handle_right_mouse_down(point)
	else:game._handle_single_click(point)
func cancel() -> void:
	game.construction_system.cancel_placement();game.lumber_zone_system.cancel_zone_placement();game.terraforming_system.deactivate()
	game.set_demolish_mode(false);game.hud.skin.command("stop");game.selection_system.clear_selection()
