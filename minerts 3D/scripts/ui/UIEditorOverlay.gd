class_name UIEditorOverlay
extends Control

signal closed()

var active_element: String = ""
var dragging: bool = false
var drag_start_mouse: Vector2 = Vector2.ZERO
var drag_start_offset: Vector2 = Vector2.ZERO

var handles: Dictionary = {} # element_id -> PanelContainer
var top_bar: PanelContainer
var bottom_bar: PanelContainer

var preset_dropdown: OptionButton
var preset_name_edit: LineEdit
var scale_slider: HSlider
var scale_val_lbl: Label
var selected_elem_lbl: Label

# Element definitions: ID -> Display info & default simulated rects
var elements_def: Dictionary = {
	"top_bar": {
		"title": "📦 Панель ресурсов",
		"base_pos": Vector2(300, 82),
		"base_size": Vector2(590, 54)
	},
	"inspector": {
		"title": "👤 Инспектор юнита",
		"base_pos": Vector2(250, 640),
		"base_size": Vector2(690, 170)
	},
	"minimap": {
		"title": "🗺️ Миникарта",
		"base_pos": Vector2(20, 620),
		"base_size": Vector2(190, 190)
	},
	"build_dock": {
		"title": "🔨 Каталог построек",
		"base_pos": Vector2(920, 80),
		"base_size": Vector2(260, 600)
	},
	"raid": {
		"title": "⚔️ Ночная волна",
		"base_pos": Vector2(15, 75),
		"base_size": Vector2(240, 80)
	},
	"command_lock": {
		"title": "🎯 Кнопка приказа",
		"base_pos": Vector2(980, 720),
		"base_size": Vector2(180, 64)
	}
}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Backdrop
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.07, 0.12, 0.85)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(bg)

	_setup_top_bar()
	_setup_handles()
	_setup_bottom_bar()

	select_element("inspector")
	_refresh_preset_dropdown()

func _setup_top_bar() -> void:
	top_bar = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0a1c2bf0")
	style.border_color = Color("0284c7")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(10)
	top_bar.add_theme_stylebox_override("panel", style)
	
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 16
	top_bar.offset_right = -16
	top_bar.offset_top = 10
	top_bar.offset_bottom = 68
	add_child(top_bar)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	top_bar.add_child(hbox)

	var title_lbl := Label.new()
	title_lbl.text = "🎨 Редактор интерфейса (iPad / Android)"
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color("38bdf8"))
	hbox.add_child(title_lbl)

	hbox.add_child(VSeparator.new())

	var p_lbl := Label.new()
	p_lbl.text = "Пресет:"
	p_lbl.add_theme_font_size_override("font_size", 14)
	hbox.add_child(p_lbl)

	preset_dropdown = OptionButton.new()
	preset_dropdown.custom_minimum_size = Vector2(160, 36)
	preset_dropdown.item_selected.connect(_on_preset_selected)
	hbox.add_child(preset_dropdown)

	preset_name_edit = LineEdit.new()
	preset_name_edit.placeholder_text = "Название пресета..."
	preset_name_edit.custom_minimum_size = Vector2(180, 36)
	hbox.add_child(preset_name_edit)

	var save_btn := Button.new()
	save_btn.text = "💾 Сохранить"
	save_btn.custom_minimum_size = Vector2(110, 36)
	save_btn.pressed.connect(_on_save_preset)
	hbox.add_child(save_btn)

	var reset_btn := Button.new()
	reset_btn.text = "↺ Сброс"
	reset_btn.custom_minimum_size = Vector2(80, 36)
	reset_btn.pressed.connect(_on_reset_layout)
	hbox.add_child(reset_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var close_btn := Button.new()
	close_btn.text = "✓ Готово"
	close_btn.custom_minimum_size = Vector2(110, 38)
	close_btn.pressed.connect(_on_close)
	var btn_st := StyleBoxFlat.new()
	btn_st.bg_color = Color("0284c7")
	btn_st.set_corner_radius_all(8)
	btn_st.set_content_margin_all(8)
	close_btn.add_theme_stylebox_override("normal", btn_st)
	hbox.add_child(close_btn)

func _setup_handles() -> void:
	for elem_id in elements_def.keys():
		var data: Dictionary = elements_def[elem_id]
		var p := PanelContainer.new()
		p.name = "Handle_" + elem_id
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(p)
		handles[elem_id] = p
		
		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 4)
		p.add_child(vbox)

		var t_lbl := Label.new()
		t_lbl.name = "TitleLabel"
		t_lbl.text = data["title"]
		t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t_lbl.add_theme_font_size_override("font_size", 14)
		vbox.add_child(t_lbl)

		var sub_lbl := Label.new()
		sub_lbl.name = "SubLabel"
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_lbl.add_theme_font_size_override("font_size", 11)
		sub_lbl.add_theme_color_override("font_color", Color("94a3b8"))
		vbox.add_child(sub_lbl)

		p.gui_input.connect(func(ev: InputEvent): _on_handle_gui_input(elem_id, ev))

	_update_all_handle_rects()

func _setup_bottom_bar() -> void:
	bottom_bar = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0a1c2bf0")
	style.border_color = Color("0284c7")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(8)
	bottom_bar.add_theme_stylebox_override("panel", style)

	bottom_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.offset_left = 60
	bottom_bar.offset_right = -60
	bottom_bar.offset_top = -68
	bottom_bar.offset_bottom = -12
	add_child(bottom_bar)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)
	bottom_bar.add_child(hbox)

	selected_elem_lbl = Label.new()
	selected_elem_lbl.text = "Выбранный блок: -"
	selected_elem_lbl.add_theme_font_size_override("font_size", 14)
	selected_elem_lbl.add_theme_color_override("font_color", Color("f8fafc"))
	hbox.add_child(selected_elem_lbl)

	hbox.add_child(VSeparator.new())

	var sc_lbl := Label.new()
	sc_lbl.text = "Размер:"
	sc_lbl.add_theme_font_size_override("font_size", 14)
	hbox.add_child(sc_lbl)

	var minus_btn := Button.new()
	minus_btn.text = "➖"
	minus_btn.custom_minimum_size = Vector2(36, 36)
	minus_btn.pressed.connect(func(): _adjust_active_scale(-0.05))
	hbox.add_child(minus_btn)

	scale_slider = HSlider.new()
	scale_slider.min_value = 0.60
	scale_slider.max_value = 1.50
	scale_slider.step = 0.05
	scale_slider.value = 1.0
	scale_slider.custom_minimum_size = Vector2(160, 24)
	scale_slider.value_changed.connect(_on_slider_scale_changed)
	hbox.add_child(scale_slider)

	var plus_btn := Button.new()
	plus_btn.text = "➕"
	plus_btn.custom_minimum_size = Vector2(36, 36)
	plus_btn.pressed.connect(func(): _adjust_active_scale(0.05))
	hbox.add_child(plus_btn)

	scale_val_lbl = Label.new()
	scale_val_lbl.text = "100%"
	scale_val_lbl.custom_minimum_size = Vector2(50, 0)
	scale_val_lbl.add_theme_font_size_override("font_size", 14)
	scale_val_lbl.add_theme_color_override("font_color", Color("38bdf8"))
	hbox.add_child(scale_val_lbl)

	hbox.add_child(VSeparator.new())

	var reset_elem_btn := Button.new()
	reset_elem_btn.text = "По центру"
	reset_elem_btn.custom_minimum_size = Vector2(90, 36)
	reset_elem_btn.pressed.connect(_reset_active_element)
	hbox.add_child(reset_elem_btn)

func select_element(elem_id: String) -> void:
	active_element = elem_id
	for id in handles.keys():
		var p: PanelContainer = handles[id]
		var is_sel: bool = (id == active_element)
		var st := StyleBoxFlat.new()
		st.bg_color = Color("1e3a8a99") if is_sel else Color("0f172a80")
		st.border_color = Color("38bdf8") if is_sel else Color("475569")
		st.set_border_width_all(3 if is_sel else 1)
		st.set_corner_radius_all(10)
		st.set_content_margin_all(8)
		p.add_theme_stylebox_override("panel", st)

	if elements_def.has(active_element):
		var data: Dictionary = elements_def[active_element]
		selected_elem_lbl.text = "Блок: " + data["title"]
		var sc := UILayoutManager.get_element_scale(active_element)
		scale_slider.value = sc
		scale_val_lbl.text = "%d%%" % int(sc * 100)

func _adjust_active_scale(delta: float) -> void:
	if active_element.is_empty():
		return
	var new_sc = clampf(scale_slider.value + delta, 0.60, 1.50)
	scale_slider.value = new_sc

func _on_slider_scale_changed(val: float) -> void:
	if active_element.is_empty():
		return
	UILayoutManager.set_element_scale(active_element, val)
	scale_val_lbl.text = "%d%%" % int(val * 100)
	_update_handle_rect(active_element)

func _reset_active_element() -> void:
	if active_element.is_empty():
		return
	UILayoutManager.set_element_offset(active_element, Vector2.ZERO)
	UILayoutManager.set_element_scale(active_element, 1.0)
	scale_slider.value = 1.0
	_update_handle_rect(active_element)

func _on_handle_gui_input(elem_id: String, ev: InputEvent) -> void:
	if ev is InputEventMouseButton or ev is InputEventScreenTouch:
		if ev.pressed:
			select_element(elem_id)
			dragging = true
			drag_start_mouse = get_viewport().get_mouse_position()
			drag_start_offset = UILayoutManager.get_element_offset(elem_id)
		else:
			dragging = false
	elif (ev is InputEventMouseMotion or ev is InputEventScreenDrag) and dragging and active_element == elem_id:
		var current_mouse: Vector2 = get_viewport().get_mouse_position()
		var delta: Vector2 = current_mouse - drag_start_mouse
		var new_offset: Vector2 = drag_start_offset + delta
		UILayoutManager.set_element_offset(elem_id, new_offset)
		_update_handle_rect(elem_id)

func _update_handle_rect(elem_id: String) -> void:
	if not handles.has(elem_id) or not elements_def.has(elem_id):
		return
	var p: PanelContainer = handles[elem_id]
	var data: Dictionary = elements_def[elem_id]
	var base_pos: Vector2 = data["base_pos"]
	var base_size: Vector2 = data["base_size"]
	var off: Vector2 = UILayoutManager.get_element_offset(elem_id)
	var sc: float = UILayoutManager.get_element_scale(elem_id)

	var cur_size := base_size * sc
	p.position = base_pos + off
	p.size = cur_size

	var sub_lbl: Label = p.get_node_or_null("VBoxContainer/SubLabel")
	if sub_lbl:
		sub_lbl.text = "Размер: %d%% · X: %d Y: %d" % [int(sc * 100), int(off.x), int(off.y)]

func _update_all_handle_rects() -> void:
	for elem_id in elements_def.keys():
		_update_handle_rect(elem_id)

func _refresh_preset_dropdown() -> void:
	preset_dropdown.clear()
	var names := UILayoutManager.get_preset_names()
	var active_idx := 0
	for i in range(names.size()):
		preset_dropdown.add_item(names[i])
		if names[i] == UILayoutManager.active_preset_name:
			active_idx = i
	preset_dropdown.select(active_idx)
	preset_name_edit.text = UILayoutManager.active_preset_name

func _on_preset_selected(idx: int) -> void:
	var name: String = preset_dropdown.get_item_text(idx)
	UILayoutManager.apply_preset(name)
	preset_name_edit.text = name
	_update_all_handle_rects()
	select_element(active_element)

func _on_save_preset() -> void:
	var name: String = preset_name_edit.text.strip_edges()
	if name.is_empty():
		name = "Пресет %d" % (preset_dropdown.item_count + 1)
	UILayoutManager.save_preset(name)
	_refresh_preset_dropdown()

func _on_reset_layout() -> void:
	UILayoutManager.reset_to_default()
	_update_all_handle_rects()
	select_element(active_element)
	_refresh_preset_dropdown()

func _on_close() -> void:
	closed.emit()
	queue_free()
