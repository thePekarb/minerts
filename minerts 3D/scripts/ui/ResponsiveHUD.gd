class_name ResponsiveHUD
extends Node

var game: Main
var hud: HUD
var compact: bool = false
var build_open: bool = false
var toolbar: HFlowContainer
var confirm: Button
var rotate: Button
var inspector_scroll: ScrollContainer
var inspector_grid: GridContainer
var build_scroll: ScrollContainer
var top_flow: HFlowContainer
var safe: Rect2
var timer: float = 0
var command_lock_btn: Button

func setup(main: Main) -> void:
	game = main
	hud = game.hud
	DeviceLayout.configure_window(get_window())
	get_viewport().size_changed.connect(layout)
	
	if UILayoutManager:
		UILayoutManager.layout_changed.connect(func(): layout.call_deferred())

	var old_row: Node = hud.skin.portrait.get_parent()
	inspector_scroll = ScrollContainer.new()
	inspector_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hud.inspector.add_child(inspector_scroll)
	inspector_grid = GridContainer.new()
	inspector_grid.columns = 4
	inspector_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_scroll.add_child(inspector_grid)
	for child in old_row.get_children():
		child.reparent(inspector_grid)
	old_row.queue_free()

	build_scroll = ScrollContainer.new()
	build_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var build_box: Control = hud.build_dock.get_node("VBox")
	hud.build_dock.add_child(build_scroll)
	build_box.reparent(build_scroll)
	build_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var top: Control = hud.get_node("TopBar")
	var old_top: Control = top.get_node("HBox")
	top_flow = HFlowContainer.new()
	top_flow.alignment = FlowContainer.ALIGNMENT_CENTER
	top.add_child(top_flow)
	for child in old_top.get_children():
		child.reparent(top_flow)
	old_top.queue_free()

	toolbar = HFlowContainer.new()
	toolbar.add_theme_constant_override("h_separation", 6)
	toolbar.add_theme_constant_override("v_separation", 6)
	hud.add_child(toolbar)

	add_action("Постройки", func(): build_open = not build_open; layout())
	add_action("Карта", func(): hud.minimap.visible = not hud.minimap.visible)
	add_action("Подземелье", func(): game.underground_system.toggle_view())
	add_action("Отмена", func(): game.touch_controls.cancel())
	confirm = add_action("✓ Строить", func(): game.construction_system.try_place(game.all_units))
	rotate = add_action("↻ Поворот", func(): game.construction_system.rotate_90())
	
	# Dedicated touch Command Lock button
	_setup_command_lock_button()

	hud.build_requested.connect(func(_type): if compact: build_open = false; layout())
	EventBus.selection_changed.connect(func(_units, _building): layout.call_deferred())
	layout.call_deferred()

func add_action(text: String, callback: Callable) -> Button:
	var button := hud.skin.button(text, callback, Vector2(82, 48))
	button.add_theme_font_size_override("font_size", 14)
	toolbar.add_child(button)
	return button

func _setup_command_lock_button() -> void:
	command_lock_btn = Button.new()
	command_lock_btn.name = "CommandLockBtn"
	command_lock_btn.custom_minimum_size = Vector2(170, 50)
	hud.add_child(command_lock_btn)
	command_lock_btn.pressed.connect(func():
		var active = game.touch_controls.toggle_command_lock()
		_update_command_lock_style(active)
	)
	game.touch_controls.command_lock_changed.connect(_update_command_lock_style)
	_update_command_lock_style(false)

func _update_command_lock_style(active: bool) -> void:
	if not is_instance_valid(command_lock_btn):
		return
	var st := StyleBoxFlat.new()
	st.set_corner_radius_all(14)
	st.set_border_width_all(2)
	st.set_content_margin_all(8)
	st.shadow_size = 6
	if active:
		command_lock_btn.text = "🔒 ПРИКАЗ: ВКЛ"
		st.bg_color = Color("0284c7")
		st.border_color = Color("38bdf8")
		st.shadow_color = Color(0.01, 0.52, 0.78, 0.6)
		command_lock_btn.add_theme_color_override("font_color", Color.WHITE)
	else:
		command_lock_btn.text = "🎯 Приказ: ВЫКЛ"
		st.bg_color = Color("0f1e2bef")
		st.border_color = Color("475569")
		st.shadow_color = Color(0, 0, 0, 0.4)
		command_lock_btn.add_theme_color_override("font_color", Color("94a3b8"))
	command_lock_btn.add_theme_stylebox_override("normal", st)
	command_lock_btn.add_theme_stylebox_override("hover", st)
	command_lock_btn.add_theme_stylebox_override("pressed", st)
	command_lock_btn.add_theme_stylebox_override("focus", st)
	command_lock_btn.add_theme_font_size_override("font_size", 14)

func layout() -> void:
	if not is_instance_valid(hud):
		return
	safe = DeviceLayout.safe_rect(get_viewport())
	compact = safe.size.x < 1180 or safe.size.y < 640 or DeviceLayout.is_mobile()
	var portrait: bool = safe.size.x < 600
	var inset: float = 8
	var top_height: float = 82 if portrait else 54
	var top_width: float = minf(730, safe.size.x - 116)

	# 1. Top Bar
	var top_node := hud.get_node("TopBar")
	var top_off := UILayoutManager.get_element_offset("top_bar") if UILayoutManager else Vector2.ZERO
	var top_sc := UILayoutManager.get_element_scale("top_bar") if UILayoutManager else 1.0
	var top_pos := safe.position + Vector2(0 if compact else (safe.size.x - top_width) * 0.5, 0) + top_off
	DeviceLayout.place(top_node, Rect2(top_pos, Vector2(top_width, top_height) * top_sc))
	top_flow.add_theme_constant_override("h_separation", 8 if compact else 18)
	for label in [hud.wood_label, hud.stone_label, hud.food_label, hud.ore_label, hud.pop_label, hud.time_label, hud.day_label, hud.water_label]:
		label.add_theme_font_size_override("font_size", 14 if compact else 18)
	hud.day_label.get_parent().visible = not portrait
	hud.time_label.visible = not portrait
	hud.water_label.visible = true

	# 2. Raid / Night wave
	var raid: Control = hud.raid_status_label.get_parent().get_parent()
	var raid_off := UILayoutManager.get_element_offset("raid") if UILayoutManager else Vector2.ZERO
	var raid_sc := UILayoutManager.get_element_scale("raid") if UILayoutManager else 1.0
	var raid_base_pos := safe.position + Vector2(0, top_height + 8 if compact else 0)
	var raid_size := Vector2(200 if compact else 282, 70 if compact else 88) * raid_sc
	DeviceLayout.place(raid, Rect2(raid_base_pos + raid_off, raid_size))
	hud.skin.raid_title.add_theme_font_size_override("font_size", 16 if compact else 23)
	hud.raid_status_label.add_theme_font_size_override("font_size", 16 if compact else 20)

	DeviceLayout.place(hud.skin.pause_button, Rect2(Vector2(safe.end.x - 52, safe.position.y), Vector2(52, 52)))
	for child in hud.get_children():
		if child is Button and child != hud.skin.pause_button and child != command_lock_btn:
			if child.text == "⚙":
				DeviceLayout.place(child, Rect2(Vector2(safe.end.x - 110, safe.position.y), Vector2(52, 52)))
			elif child.text in ["Карта", "Срез [X]"]:
				child.visible = not compact
	if hud.fps_label:
		hud.fps_label.get_parent().visible = not compact

	# 3. Compact Toolbar (ensure no overlap with raid)
	toolbar.visible = compact
	var tb_y := maxf(raid.position.y + raid.size.y + 10, safe.position.y + top_height + 88)
	DeviceLayout.place(toolbar, Rect2(Vector2(safe.position.x, tb_y), Vector2(safe.size.x, 104 if portrait else 48)))

	# 4. Inspector
	var bottom_height: float = minf(safe.size.y * 0.36, 240) if portrait else (148 if compact else 170)
	var inspector_width: float = safe.size.x if compact else minf(980, safe.size.x - 460)
	var insp_off := UILayoutManager.get_element_offset("inspector") if UILayoutManager else Vector2.ZERO
	var insp_sc := UILayoutManager.get_element_scale("inspector") if UILayoutManager else 1.0
	var insp_pos := Vector2(safe.position.x if compact else safe.position.x + (safe.size.x - inspector_width) * 0.5, safe.end.y - bottom_height) + insp_off
	DeviceLayout.place(hud.inspector, Rect2(insp_pos, Vector2(inspector_width, bottom_height) * insp_sc))
	inspector_grid.columns = 1 if portrait else (3 if compact else 4)
	hud.skin.portrait.visible = not compact
	hud.skin.info.custom_minimum_size = Vector2(0 if portrait else 170, 0)
	hud.inspector_health_bar.custom_minimum_size = Vector2(0 if portrait else 150, 14)
	hud.queue_label.custom_minimum_size = Vector2(0 if portrait else 170, 0)
	hud.queue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.inspector_action_box.custom_minimum_size = Vector2(0 if portrait else 200, 0)
	for button in hud.skin.commands.get_children():
		button.custom_minimum_size = Vector2(48, 54) if compact else Vector2(64, 82)
	hud.inspector_title.add_theme_font_size_override("font_size", 18 if compact else 20)
	for child in hud.inspector_action_box.get_children():
		if child is Button:
			child.custom_minimum_size = Vector2(180 if compact else 240, 48 if compact else 42)

	# 5. Minimap
	var map_size: float = 104 if compact else 200
	var map_off := UILayoutManager.get_element_offset("minimap") if UILayoutManager else Vector2.ZERO
	var map_sc := UILayoutManager.get_element_scale("minimap") if UILayoutManager else 1.0
	hud.minimap.custom_minimum_size = Vector2.ONE * (map_size * map_sc)
	var map_pos := Vector2(safe.end.x - map_size if compact else safe.position.x, safe.position.y + top_height + 60 if compact else safe.end.y - map_size) + map_off
	DeviceLayout.place(hud.minimap, Rect2(map_pos, Vector2.ONE * (map_size * map_sc)))
	if hud.minimap.material is ShaderMaterial:
		hud.minimap.material.set_shader_parameter("map_size", map_size * map_sc)
	hud.minimap.queue_redraw()

	# 6. Build Dock
	hud.build_dock.visible = build_open if compact else true
	var dock_width: float = minf(300, safe.size.x)
	var dock_off := UILayoutManager.get_element_offset("build_dock") if UILayoutManager else Vector2.ZERO
	var dock_sc := UILayoutManager.get_element_scale("build_dock") if UILayoutManager else 1.0
	var dock_pos := Vector2(safe.end.x - dock_width, safe.position.y + top_height + 8) + dock_off
	DeviceLayout.place(hud.build_dock, Rect2(dock_pos, Vector2(dock_width, safe.size.y - top_height - 16) * dock_sc))
	hud.skin.scroll.custom_minimum_size = Vector2(0, 200 if compact else 340)

	# 7. Command Lock Button
	if is_instance_valid(command_lock_btn):
		command_lock_btn.visible = game.touch_controls.touch_enabled or DeviceLayout.is_mobile() or not game.selection_system.selected_units.is_empty()
		var cl_off := UILayoutManager.get_element_offset("command_lock") if UILayoutManager else Vector2.ZERO
		var cl_sc := UILayoutManager.get_element_scale("command_lock") if UILayoutManager else 1.0
		var cl_x: float = safe.end.x - (dock_width + 190.0 if (hud.build_dock.visible and not compact) else 190.0)
		var cl_y: float = safe.end.y - bottom_height - 62.0
		var cl_pos := Vector2(cl_x, cl_y) + cl_off
		DeviceLayout.place(command_lock_btn, Rect2(cl_pos, Vector2(170, 50) * cl_sc))

	DeviceLayout.place(hud.banner, Rect2(safe.position + Vector2(8, top_height + 4), Vector2(safe.size.x - 16, 52)))
	hud.banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.banner_label.add_theme_font_size_override("font_size", 14 if compact else 18)
	DeviceLayout.place(hud.skin.settings, Rect2(safe.get_center() - Vector2(minf(480, safe.size.x), minf(340, safe.size.y)) * 0.5, Vector2(minf(480, safe.size.x), minf(340, safe.size.y))))
	hud.skin.production_panel.layout_for(safe)

func _process(delta: float) -> void:
	timer += delta
	if timer < 0.15:
		return
	timer = 0
	confirm.visible = game.construction_system.is_placing()
	rotate.visible = confirm.visible
	if game.touch_controls.touch_enabled and not toolbar.visible:
		toolbar.show()
	if is_instance_valid(command_lock_btn):
		var should_be_visible: bool = game.touch_controls.touch_enabled or DeviceLayout.is_mobile() or not game.selection_system.selected_units.is_empty()
		if command_lock_btn.visible != should_be_visible:
			command_lock_btn.visible = should_be_visible
