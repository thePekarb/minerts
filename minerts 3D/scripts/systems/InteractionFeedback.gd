class_name InteractionFeedback
extends Node

var game: Main
var hovered: Node3D
var highlighted: Array[MeshInstance3D] = []
var label: Label
var overlay: StandardMaterial3D
var timer: float = 0.0

func setup(main: Main) -> void:
	game = main
	label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color("fff1c9"))
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	game.hud.add_child(label)
	overlay = StandardMaterial3D.new()
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay.albedo_color = Color(1, 0.85, 0.45, 0.25)

func _process(delta: float) -> void:
	timer += delta
	if timer < 0.05: return
	timer = 0
	var mouse: Vector2 = game.get_viewport().get_mouse_position()
	label.position = mouse + Vector2(18, 20)
	if game.get_viewport().gui_get_hovered_control() != null or game.construction_system.is_placing():
		set_hover(null)
		return
	var hit: Dictionary = game.camera.raycast_objects(mouse)
	var target: Node3D = hit.get("collider") as Node3D
	if target and not (target is Unit or target is Building or target.has_meta("resource_type") or target.has_meta("poi_type")):
		target = null
	if target and not is_interactable(target): target = null
	set_hover(target)
	if target == null and not game.selection_system.selected_units.is_empty():
		var point: Vector3 = game.camera.raycast_ground(mouse)
		if game.underground_system.cutaway:
			var cell: Vector2i = Vector2i(floori(point.x), floori(point.z))
			var is_exit_tile: bool = false
			for cave in game.underground_system.caves:
				if cell == cave.entry:
					is_exit_tile = true
					break
			label.visible = true
			if is_exit_tile:
				label.text = "▲ Лестница на поверхность · ПКМ: подняться"
				Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
			else:
				label.text = "ПКМ: пройти по тоннелю" if game.underground_system.is_open(cell) else "Порода · ПКМ рабочим: копать"
				Input.set_default_cursor_shape(Input.CURSOR_CROSS)
		else:
			Input.set_default_cursor_shape(Input.CURSOR_MOVE)

func is_interactable(target: Node3D) -> bool:
	if not target.is_visible_in_tree(): return false
	if target is Unit and target.underground_unit:
		return game.underground_system.cutaway
	if game.underground_system.cutaway:
		if target.has_meta("poi_type") and target.get_meta("poi_type") == "cave_exit":
			return true
		return false
	return game.fog_system.get_tile_visibility(floori(target.position.x), floori(target.position.z)) == 2

func describe(target: Node3D) -> String:
	if target is Unit:
		if UnitConfigs.is_vessel(target.unit_type) and target.faction!="player":return "%s · Вражеский корабль · ПКМ: атаковать" % target.config.name
		if UnitConfigs.is_vessel(target.unit_type):return "%s · Пассажиры %d/%d · ПКМ отрядом: сесть · U: высадить" % [target.config.name,target.passengers.size(),target.config.capacity]
		if target.faction=="goblin":return "%s · Гоблины · ПКМ: атаковать" % target.config.name
		if target.faction in ["enemy","predator"]: return "%s · ПКМ: атаковать · HP %d" % [target.config.name, target.health]
		if target.faction == "neutral": return "%s · ПКМ: охота · туша: %d еды" % [target.config.name, target.config.get("food_loot", 0)]
		return "%s · ЛКМ: выбрать · HP %d" % [target.config.name, target.health]
	if target is Building:
		return "%s · %s" % [target.config.name, "ПКМ рабочим: строить" if not target.is_constructed else "ЛКМ: управление"]
	if target.has_meta("resource_type"):
		return "%s: %d · ПКМ рабочим: добывать" % [target.get_meta("display_name",target.get_meta("resource_type")), target.get_meta("resource_amount", 0)]
	if target.has_meta("poi_type"):
		if target.get_meta("poi_type") == "cave_exit":
			return target.get_meta("display_name", "▲ Выход на поверхность · ПКМ: подняться")
		elif target.get_meta("poi_type") == "cave_entrance":
			return target.get_meta("display_name", "▼ Вход в пещеру · ПКМ: спуститься")
	return target.get_meta("display_name", "Сундук · ПКМ: открыть")

func set_hover(target: Node3D) -> void:
	if target != hovered:
		if is_instance_valid(hovered):hovered.set_meta("visual_focus",false)
		if is_instance_valid(target):target.set_meta("visual_focus",true)
		if is_instance_valid(hovered) and hovered is Unit:hovered.visual_focus=false
		for mesh in highlighted:
			if is_instance_valid(mesh): mesh.material_overlay = null
		highlighted.clear()
		hovered = target
		if target is Unit:target.visual_focus=true
		if is_instance_valid(target): _highlight(target)
	label.visible = is_instance_valid(target)
	if not is_instance_valid(target):
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		return
	label.text = describe(target)
	Input.set_default_cursor_shape(Input.CURSOR_CROSS if target is Unit and target.faction != "player" else Input.CURSOR_POINTING_HAND)

func _highlight(node: Node) -> void:
	if node is MeshInstance3D:
		node.material_overlay = overlay
		highlighted.append(node)
	for child in node.get_children(): _highlight(child)

func show_order(pos: Vector3) -> void:
	var marker: MeshInstance3D = MeshInstance3D.new()
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 0.35
	ring.outer_radius = 0.45
	ring.rings = 24
	ring.ring_segments = 4
	marker.mesh = ring
	marker.material_override = overlay
	game.add_child(marker)
	marker.global_position = pos + Vector3.UP * 0.06
	var tween: Tween = marker.create_tween()
	tween.tween_property(marker, "scale", Vector3.ONE * 1.6, 0.45)
	tween.tween_callback(marker.queue_free)

func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
