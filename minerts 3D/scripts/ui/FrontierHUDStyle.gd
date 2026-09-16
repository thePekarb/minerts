class_name FrontierHUDStyle
extends RefCounted

var hud: HUD
var portrait: TextureRect
var commands: HBoxContainer
var info: VBoxContainer
var category: OptionButton
var scroll: ScrollContainer
var raid_title: Label
var pause_button: Button
var settings: PanelContainer
var build_tiles: Dictionary = {}
var command_mode: String = ""
var production_panel: ProductionPanel
var production_button: Button
var tower_garrison_btn: Button
var demolish_tool_btn: Button
var demolish_btn: Button
const NAMES: Array[String] = ["Рабочий","Разведчик","Рыцарь","Лучник","Рейдер","Ночная бестия","Зомби","Скелет","Паук","Крипер","Олень","Кабан","Кролик","Волк","Медведь","Рабочий гоблинов","Воин гоблинов","Лучник гоблинов","Копейщик","Всадник на пауке","Тролль","Лодка","Галера","Древний голем","Страж бури"]

func panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color=Color("102533f5");s.border_color=Color("446b80")
	s.set_border_width_all(2);s.set_corner_radius_all(18)
	s.set_content_margin_all(14);s.shadow_color=Color(0,0,0,.3);s.shadow_size=5
	return s
func atlas(file: String, rect: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new();texture.atlas=load("res://assets/ui/"+file);texture.region=rect
	return texture
func picture(texture: Texture2D, minimum: Vector2) -> TextureRect:
	var image := TextureRect.new();image.texture=texture;image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.custom_minimum_size=minimum;image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return image
func label(text: String, font_size: int = 20) -> Label:
	var l := Label.new();l.text=text;l.add_theme_font_size_override("font_size",font_size);return l
func button(text: String, callback: Callable, minimum := Vector2(60,48)) -> Button:
	var b := Button.new();b.text=text;b.custom_minimum_size=minimum;b.pressed.connect(callback);return b
func anchored(control: Control, left: float, top: float, right: float, bottom: float, x: float=0, y: float=0) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.anchor_left=x;control.anchor_right=x;control.anchor_top=y;control.anchor_bottom=y
	control.offset_left=left;control.offset_top=top;control.offset_right=right;control.offset_bottom=bottom
func setup(owner: HUD) -> void:
	hud=owner
	hud.theme.default_font_size=18
	hud.raid_status_label.add_theme_color_override("font_color",Color("ff7669"))
	for state in ["normal","hover","pressed","focus","disabled"]:
		var s := panel_style();s.set_corner_radius_all(10);s.set_content_margin_all(9)
		if state in ["hover","focus"]:s.border_color=Color("64dfff");s.bg_color=Color("183d50")
		if state=="pressed":s.bg_color=Color("21516a")
		hud.theme.set_stylebox(state,"Button",s)
	var top: PanelContainer = hud.get_node("TopBar");top.add_theme_stylebox_override("panel",panel_style())
	anchored(top,-365,14,365,68,.5)
	top.get_node("HBox").add_theme_constant_override("separation",18)
	for item in [[hud.wood_label,Rect2(531,21,32,34)],[hud.stone_label,Rect2(638,21,32,34)],[hud.food_label,Rect2(733,21,32,34)],[hud.pop_label,Rect2(840,22,40,30)],[hud.day_label,Rect2(963,21,34,34)]]:
		var old_label: Label = item[0]
		var parent: Node = old_label.get_parent();var index: int = old_label.get_index()
		var pair := HBoxContainer.new();pair.add_theme_constant_override("separation",6);parent.add_child(pair);parent.move_child(pair,index)
		pair.add_child(picture(atlas("scene-reference.png",item[1]),Vector2(28,30)));old_label.reparent(pair)
	hud.time_label.add_theme_font_size_override("font_size",18)
	var raid: PanelContainer = hud.raid_status_label.get_parent()
	raid.add_theme_stylebox_override("panel",panel_style());anchored(raid,18,18,300,106)
	hud.raid_status_label.add_theme_font_size_override("font_size",20)
	var raid_box := VBoxContainer.new();raid.add_child(raid_box)
	var raid_row := HBoxContainer.new();raid_box.add_child(raid_row)
	raid_row.add_child(picture(atlas("scene-reference.png",Rect2(40,29,41,53)),Vector2(38,45)))
	raid_title=label("Ночная волна",23);raid_row.add_child(raid_title);hud.raid_status_label.reparent(raid_box)
	hud.build_dock.add_theme_stylebox_override("panel",panel_style())
	anchored(hud.build_dock,-270,96,-16,620,1)
	hud.build_dock.mouse_filter = Control.MOUSE_FILTER_STOP
	var box: VBoxContainer = hud.build_dock.get_node("VBox")
	box.get_node("Title").hide();box.get_node("HSeparator").hide()
	var heading := button("Постройки                  ⌃",func():scroll.visible=not scroll.visible;category.visible=scroll.visible)
	box.add_child(heading);box.move_child(heading,0)
	category=OptionButton.new()
	for text in ["Все постройки","Жильё","Оборона","Производство","Ресурсы"]:category.add_item(text)
	category.item_selected.connect(filter_buildings);box.add_child(category);box.move_child(category,1)
	scroll=ScrollContainer.new();scroll.custom_minimum_size=Vector2(0,340);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter=Control.MOUSE_FILTER_STOP
	scroll.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			if mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
				scroll.accept_event()
	)
	box.add_child(scroll);box.move_child(scroll,2);hud.build_grid.reparent(scroll)
	hud.build_grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;hud.build_grid.add_theme_constant_override("h_separation",8);hud.build_grid.add_theme_constant_override("v_separation",8)
	var i: int = 0
	for tile in hud.build_grid.get_children():
		if tile.is_queued_for_deletion():continue
		tile.text="";tile.custom_minimum_size=Vector2(112,108)
		tile.mouse_filter=Control.MOUSE_FILTER_STOP
		var row_bounds: Array[Vector2i] = [Vector2i(170,376),Vector2i(390,599),Vector2i(612,822),Vector2i(834,1039),Vector2i(1053,1242),Vector2i(1255,1459)]
		var bounds: Vector2i = row_bounds[i/2]
		var rect := Rect2(337 if i%2==0 else 570,bounds.x,219,bounds.y-bounds.x)
		var image := picture(atlas("build-reference.png",rect),Vector2.ZERO);tile.add_child(image);image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		image.stretch_mode=TextureRect.STRETCH_SCALE
		tile.set_meta("catalog_index",i);build_tiles[i]=tile;i+=1
		tile.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton:
				var mb := ev as InputEventMouseButton
				if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
					scroll.scroll_vertical -= 50
					tile.accept_event()
				elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					scroll.scroll_vertical += 50
					tile.accept_event()
		)
	hud.axe_tool_btn.text="Лесозаготовка";hud.axe_tool_btn.custom_minimum_size=Vector2(0,42)
	demolish_tool_btn = button("🗑️  Снос постройки", func():
		var game = hud.get_parent()
		if game and game.has_method("toggle_demolish_mode"):
			game.toggle_demolish_mode()
	, Vector2(0, 42))
	demolish_tool_btn.tooltip_text = "Режим сноса: наведите на постройку и нажмите ЛКМ для сноса. ПКМ / ESC — отмена."
	var red_style := panel_style()
	red_style.bg_color = Color("2e1215")
	red_style.border_color = Color("f87171")
	red_style.set_corner_radius_all(10)
	demolish_tool_btn.add_theme_stylebox_override("normal", red_style)
	demolish_tool_btn.add_theme_color_override("font_color", Color("fca5a5"))
	box.add_child(demolish_tool_btn)

	# Reuse the existing live inspector controls and gameplay connections.
	var old: VBoxContainer = hud.inspector.get_node("VBox")
	var row := HBoxContainer.new();row.add_theme_constant_override("separation",12);hud.inspector.add_child(row)
	portrait=picture(atlas("worker-reference.png",Rect2(100,213,290,309)),Vector2(80,90));row.add_child(portrait)
	info=VBoxContainer.new();info.custom_minimum_size=Vector2(190,0);row.add_child(info)
	hud.inspector_title.reparent(info);hud.inspector_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;hud.inspector_title.add_theme_font_size_override("font_size",20)
	hud.inspector_subtitle.reparent(info);hud.inspector_subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;hud.inspector_subtitle.add_theme_font_size_override("font_size",15)
	hud.inspector_health_bar.reparent(info);hud.inspector_health_bar.custom_minimum_size=Vector2(190,14)
	var fill := panel_style();fill.bg_color=Color("62c879");fill.set_border_width_all(0);fill.set_corner_radius_all(5)
	hud.inspector_health_bar.add_theme_stylebox_override("fill",fill)
	hud.queue_label.reparent(info);hud.queue_label.custom_minimum_size=Vector2(190,0);hud.queue_label.add_theme_font_size_override("font_size",13)
	commands=HBoxContainer.new();commands.add_theme_constant_override("separation",6);row.add_child(commands)
	for item in [["Собрать","gather",Rect2(1000,230,240,283)],["Копать","dig",Rect2(1270,230,240,283)],["Нести","carry",Rect2(1535,230,240,283)],["Отменить","stop",Rect2(1800,230,278,283)]]:
		var action: String = item[1]
		var b := button("",func():command(action),Vector2(64,82));b.tooltip_text=item[0];b.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		var image := picture(atlas("worker-reference.png",item[2]),Vector2.ZERO);b.add_child(image);image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		image.stretch_mode=TextureRect.STRETCH_SCALE
		commands.add_child(b)
	var b_patrol := button("Патруль",func():command("patrol"),Vector2(64,82));b_patrol.tooltip_text="Патрулировать между двумя точками (ПКМ по земле)";b_patrol.size_flags_vertical=Control.SIZE_SHRINK_CENTER;b_patrol.add_theme_font_size_override("font_size",12);commands.add_child(b_patrol)
	var b_hold := button("Держать\nпозицию",func():command("hold"),Vector2(64,82));b_hold.tooltip_text="Держать позицию и обороняться";b_hold.size_flags_vertical=Control.SIZE_SHRINK_CENTER;b_hold.add_theme_font_size_override("font_size",12);commands.add_child(b_hold)
	hud.inspector_action_box.reparent(row);hud.inspector_action_box.custom_minimum_size=Vector2(260,0)
	old.hide();hud.inspector.add_theme_stylebox_override("panel",panel_style())
	anchored(hud.inspector,-360,-140,360,-16,.5,1)
	# Circular live minimap, camera controls and cutaway remain real controls.
	anchored(hud.minimap,16,-216,216,-16,0,1);hud.minimap.custom_minimum_size=Vector2(200,200)
	var map_shader := Shader.new();map_shader.code="shader_type canvas_item; uniform float map_size=200.0; varying vec2 pixel; void vertex(){pixel=VERTEX;} void fragment(){if(distance(pixel,vec2(map_size*.5))>map_size*.49) discard; COLOR=texture(TEXTURE,UV)*COLOR;}"
	var map_material := ShaderMaterial.new();map_material.shader=map_shader;hud.minimap.material=map_material
	var map_button := button("Карта",func():hud.minimap.overview=not hud.minimap.overview;hud.minimap.queue_redraw(),Vector2(88,36));hud.add_child(map_button);anchored(map_button,16,-258,112,-222,0,1)
	pause_button=button("Ⅱ",toggle_pause,Vector2(52,52));hud.add_child(pause_button);pause_button.add_theme_font_size_override("font_size",24);pause_button.process_mode=Node.PROCESS_MODE_ALWAYS;anchored(pause_button,-68,16,-16,68,1)
	var settings_button := button("⚙",func():settings.visible=not settings.visible,Vector2(52,52));hud.add_child(settings_button);settings_button.add_theme_font_size_override("font_size",24);settings_button.process_mode=Node.PROCESS_MODE_ALWAYS;anchored(settings_button,-126,16,-74,68,1)
	var fps_panel := PanelContainer.new();fps_panel.add_theme_stylebox_override("panel",panel_style());anchored(fps_panel,-216,16,-132,68,1,0);fps_panel.process_mode=Node.PROCESS_MODE_ALWAYS
	hud.fps_label=label("60 FPS",15);hud.fps_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hud.fps_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	fps_panel.add_child(hud.fps_label);hud.add_child(fps_panel)
	var xbutton := button("Срез [X]",func():hud.get_parent().underground_system.toggle_view(),Vector2(96,36));hud.add_child(xbutton);anchored(xbutton,120,-258,216,-222,0,1)
	_setup_settings()
	production_panel=ProductionPanel.new();production_panel.setup(hud)
	production_button=button("👥 Очередь найма",func():production_panel.open(hud.inspected_building),Vector2(240,42));hud.inspector_action_box.add_child(production_button);production_button.hide()
	demolish_btn = button("🗑️  Снести постройку", func():
		var game = hud.get_parent()
		if game and game.has_method("demolish_selected_building"):
			game.demolish_selected_building()
	, Vector2(240, 42))
	demolish_btn.tooltip_text = "Снести выбранную постройку и вернуть ресурсы [DEL]"
	var dem_style := panel_style()
	dem_style.bg_color = Color("381419")
	dem_style.border_color = Color("f87171")
	dem_style.set_corner_radius_all(10)
	demolish_btn.add_theme_stylebox_override("normal", dem_style)
	demolish_btn.add_theme_color_override("font_color", Color("fca5a5"))
	hud.inspector_action_box.add_child(demolish_btn)
	demolish_btn.hide()
	tower_garrison_btn=button("Слезть с башни",_on_tower_btn_pressed,Vector2(200,42));hud.inspector_action_box.add_child(tower_garrison_btn);tower_garrison_btn.hide()
	hud.train_worker_btn.text="Рабочий · 20 еды";hud.train_warrior_btn.text="Рыцарь";hud.train_archer_btn.text="Лучник"
	hud.mine_upgrade_btn.text="Углубить шахту";hud.mine_eject_btn.text="Вывести рабочих"
	for btn in [hud.train_worker_btn, hud.train_warrior_btn, hud.train_archer_btn, hud.mine_upgrade_btn, hud.mine_eject_btn, hud.gate_btn]:
		btn.add_theme_font_size_override("font_size", 14)
	if hud.exit_cave_btn:
		hud.exit_cave_btn.add_theme_font_size_override("font_size", 14)
func _on_tower_btn_pressed() -> void:
	var b: Building = hud.inspected_building
	if not is_instance_valid(b) or b.building_type != BuildingConfigs.BuildingType.TOWER:
		return
	var game = hud.get_parent()
	if NetworkManager.route_building("tower",b):return
	if is_instance_valid(b.garrisoned_archer):
		var archer: Unit = b.ungarrison_archer()
		if archer and game is Main and game.selection_system:
			game.selection_system.select_single_unit(archer)
		SoundManager.play_click()
	else:
		if game is Main and game.selection_system:
			for u in game.selection_system.selected_units:
				if is_instance_valid(u) and u.is_alive and u.faction == "player":
					if u.unit_type in [UnitConfigs.UnitType.ARCHER, UnitConfigs.UnitType.GOBLIN_ARCHER] or u.config.get("ranged", false):
						game.selection_system.cancel_assignments(u)
						u.target = b
						u.current_order = UnitConfigs.UnitOrder.INTERACT
						var path: Array[Vector3] = game.grid_manager.find_path(u.global_position, b.global_position)
						u.set_path(path)
						u.state = UnitConfigs.UnitState.MOVING
						SoundManager.play_click()
						break
func filter_buildings(index: int) -> void:
	var groups: Array = [[],[0,1],[3,4,5,6],[6,7,8,11],[2,8,9,10,11]]
	for i in build_tiles:build_tiles[i].visible=index==0 or i in groups[index]
func toggle_pause() -> void:
	if NetworkManager.in_match:settings.visible=not settings.visible;return
	hud.get_tree().paused=not hud.get_tree().paused;pause_button.text="▶" if hud.get_tree().paused else "Ⅱ"
func _setup_settings() -> void:
	settings=PanelContainer.new();hud.add_child(settings);settings.add_theme_stylebox_override("panel",panel_style());anchored(settings,-240,-150,240,150,.5,.5);settings.process_mode=Node.PROCESS_MODE_ALWAYS
	settings.mouse_filter=Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new();settings.add_child(box);box.add_child(label("Настройки графики",24))
	var quality := OptionButton.new()
	for text in ["Сбалансировано · 75% 3D","Производительность · 60% 3D","Качество · 100% 3D"]:quality.add_item(text)
	box.add_child(quality);quality.item_selected.connect(set_quality);set_quality(0)
	box.add_child(label("Интерфейс всегда в полном разрешении",16))
	var audio := CheckButton.new();audio.text="Звук";audio.button_pressed=not SoundManager.is_muted;audio.toggled.connect(func(enabled):SoundManager.is_muted=not enabled);box.add_child(audio)
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	var menu_btn := button("В главное меню", func():
		if NetworkManager.is_active():
			NetworkManager.leave_game()
		hud.get_tree().paused = false
		hud.get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	, Vector2(160, 40))
	btn_row.add_child(menu_btn)
	btn_row.add_child(button("Закрыть", func(): settings.hide(), Vector2(100, 40)))
	box.add_child(btn_row)
	settings.hide()
func set_quality(index: int) -> void:
	hud.get_viewport().scaling_3d_scale=[.75,.60,1.0][index]
	hud.get_viewport().msaa_3d=Viewport.MSAA_DISABLED if index<2 else Viewport.MSAA_2X
func command(action: String) -> void:
	var game: Main = hud.get_parent()
	if action in ["stop","hold","carry"] and NetworkManager.route_units(action,game.selection_system.selected_units):command_mode="";return
	if action=="stop":
		for u in game.selection_system.selected_units:
			game.selection_system.cancel_assignments(u);u.target=null;u.current_order=UnitConfigs.UnitOrder.MOVE;u.stop()
		command_mode="";return
	if action=="hold":
		for u in game.selection_system.selected_units:
			if not is_instance_valid(u) or not u.is_alive:continue
			game.selection_system.cancel_assignments(u)
			u.target=null;u.stop();u.current_order=UnitConfigs.UnitOrder.HOLD_POSITION
			u.hold_position_anchor=u.global_position;u.state=UnitConfigs.UnitState.DEFENDING
		command_mode=""
		hud.show_banner("Юниты удерживают позицию")
		return
	if action=="patrol":
		command_mode="patrol"
		hud.show_banner("ПКМ по земле: указать маршрут патрулирования")
		return
	if action=="carry":
		for u in game.selection_system.selected_units:
			if u.inventory.amount>0:
				game.selection_system.cancel_assignments(u);u.current_order=UnitConfigs.UnitOrder.GATHER;game.gathering_system._send_to_storage(u)
		return
	command_mode=action
	if action=="dig" and not game.underground_system.cutaway:game.underground_system.toggle_view()
	hud.show_banner("ПКМ по ресурсу: добывать" if action=="gather" else "X: открыть подземелье · ПКМ рабочим: копать")
func update_inspector() -> void:
	var game = hud.get_parent()
	if game is Main and game.selection_system:
		game.camera.command_keys_active=game.selection_system.selected_units.any(func(u):return is_instance_valid(u) and UnitConfigs.is_worker(u.unit_type))
	if production_button:
		var can_prod: bool = is_instance_valid(hud.inspected_building) and hud.inspected_building.faction=="player" and hud.inspected_building.is_constructed and hud.inspected_building.building_type in [BuildingConfigs.BuildingType.CAMPFIRE,BuildingConfigs.BuildingType.HUT,BuildingConfigs.BuildingType.WORKSHOP,BuildingConfigs.BuildingType.BARRACKS,BuildingConfigs.BuildingType.PORT]
		production_button.visible = can_prod
		if can_prod:
			if hud.inspected_building.building_type == BuildingConfigs.BuildingType.WORKSHOP:
				production_button.text = "⚒️ Очередь создания"
			else:
				production_button.text = "👥 Очередь найма"
	if is_instance_valid(demolish_btn):
		var can_demolish: bool = is_instance_valid(hud.inspected_building) and hud.inspected_building.faction == "player" and hud.inspected_building.is_alive
		demolish_btn.visible = can_demolish
		if can_demolish:
			demolish_btn.text = "🗑️ Снести постройку" if hud.inspected_building.is_constructed else "🗑️ Отменить стройку"
	if not hud.inspector.visible:return
	var unit: Unit = hud.inspected_unit
	commands.visible=not is_instance_valid(hud.inspected_building)
	hud.inspector_action_box.visible=is_instance_valid(hud.inspected_building) or (is_instance_valid(unit) and (UnitConfigs.is_vessel(unit.unit_type) or unit.underground_unit))
	portrait.visible=is_instance_valid(unit) and UnitConfigs.is_worker(unit.unit_type)
	if is_instance_valid(unit) and unit.is_alive:
		if is_instance_valid(tower_garrison_btn):tower_garrison_btn.visible=false
		hud.inspector_title.text=NAMES[unit.unit_type] if unit.unit_type < NAMES.size() else "Юнит"
		var status: String = {
			UnitConfigs.UnitState.IDLE:"Ожидает приказа",
			UnitConfigs.UnitState.MOVING:"Идёт к заданию",
			UnitConfigs.UnitState.GATHERING:"Добывает ресурсы",
			UnitConfigs.UnitState.BUILDING:"Строит",
			UnitConfigs.UnitState.ATTACKING:"Атакует",
			UnitConfigs.UnitState.RETURNING_TO_STORAGE:"Несёт ресурсы",
			UnitConfigs.UnitState.MINING_INSIDE:"В шахте",
			UnitConfigs.UnitState.DEFENDING:"Оборона"
		}.get(unit.state,"Выполняет приказ")
		if is_instance_valid(unit.garrisoned_tower):
			status="На башне (+дальность, +обзор)"
		elif unit.current_order==UnitConfigs.UnitOrder.PATROL:
			status="Патрулирует"
		elif unit.current_order==UnitConfigs.UnitOrder.HOLD_POSITION:
			status="Держит позицию"
		hud.inspector_subtitle.text="%d / %d HP\n%s" % [int(unit.health),int(unit.max_health),status]
		hud.inspector_health_bar.visible = true
		hud.inspector_health_bar.max_value = unit.max_health
		hud.inspector_health_bar.value = unit.health
		if UnitConfigs.is_vessel(unit.unit_type):
			hud.queue_label.visible = true
			hud.queue_label.text="Пассажиры: %d / %d · ПКМ: высадка · [U] выгрузить" % [unit.passengers.size(),unit.config.capacity]
		elif is_instance_valid(unit.garrisoned_tower):
			hud.queue_label.visible = true
			hud.queue_label.text="Нажмите ПКМ по земле, чтобы слезть"
		else:
			hud.queue_label.visible = false
		var is_wrk: bool = UnitConfigs.is_worker(unit.unit_type)
		if commands.get_child_count() >= 6:
			commands.get_child(0).visible=is_wrk
			commands.get_child(1).visible=is_wrk
			commands.get_child(2).visible=is_wrk
			commands.get_child(3).visible=true
			commands.get_child(4).visible=not is_instance_valid(unit.garrisoned_tower)
			commands.get_child(5).visible=not is_instance_valid(unit.garrisoned_tower)
	elif is_instance_valid(hud.inspected_building) and hud.inspected_building.is_alive:
		var b: Building = hud.inspected_building
		var b_names: Array = ["Костёр","Хижина","Склад","Стена","Ворота","Башня","Мастерская","Каменная шахта","Казармы","Ферма","Колодец","Порт"]
		hud.inspector_title.text=b_names[b.building_type] if b.building_type < b_names.size() else "Постройка"
		hud.inspector_subtitle.text="%d / %d HP\n%s" % [int(b.health),int(b.max_health),"Построено" if b.is_constructed else "Строительство %d%%" % int(b.construction_progress)]
		hud.inspector_health_bar.visible = true
		hud.inspector_health_bar.max_value = b.max_health
		hud.inspector_health_bar.value = b.health
		if b.building_type == BuildingConfigs.BuildingType.TOWER and b.is_constructed and b.faction == "player":
			if is_instance_valid(tower_garrison_btn):
				if is_instance_valid(b.garrisoned_archer):
					tower_garrison_btn.text = "Спустить лучника"
					tower_garrison_btn.visible = true
					hud.queue_label.visible = true
					hud.queue_label.text = "Лучник на башне (дальность 11, обзор 14)"
				else:
					var has_archer: bool = game is Main and game.selection_system and game.selection_system.selected_units.any(func(u): return is_instance_valid(u) and (u.unit_type in [UnitConfigs.UnitType.ARCHER, UnitConfigs.UnitType.GOBLIN_ARCHER] or u.config.get("ranged", false)))
					tower_garrison_btn.text = "Занять башню"
					tower_garrison_btn.visible = has_archer
					if not has_archer:
						hud.queue_label.visible = false
		elif is_instance_valid(tower_garrison_btn):
			tower_garrison_btn.visible = false
		if b.faction=="player" and game is Main and game.production_system:
			if b.storage_capacity()>0:
				hud.queue_label.visible=true
				hud.queue_label.text="Запас %d / %d\n%s" % [b.storage_used(),b.storage_capacity(),EquipmentConfigs.cost_text(b.stored_resources)]
			elif b.building_type==BuildingConfigs.BuildingType.WORKSHOP:
				hud.queue_label.visible=true
				hud.queue_label.text="Заказов: %d / 6 · %s" % [b.crafting_queue.size(),b.production_status]
			elif b.building_type in [BuildingConfigs.BuildingType.FARM,BuildingConfigs.BuildingType.MINE]:
				hud.queue_label.visible=true
				hud.queue_label.text="К перевозке: %s\n%s" % [EquipmentConfigs.cost_text(b.output_buffer),b.production_status]
			elif b.building_type in [BuildingConfigs.BuildingType.HUT,BuildingConfigs.BuildingType.BARRACKS,BuildingConfigs.BuildingType.PORT]:
				hud.queue_label.visible=true;hud.queue_label.text=game.production_system.queue_text(b)
			elif b.building_type!=BuildingConfigs.BuildingType.TOWER:hud.queue_label.visible=false
		elif b.building_type != BuildingConfigs.BuildingType.TOWER:
			hud.queue_label.visible = false
	elif game is Main and game.selection_system and game.selection_system.selected_units.size() > 1:
		if is_instance_valid(tower_garrison_btn):tower_garrison_btn.visible=false
		hud.inspector_title.text="Выбран отряд (%d)" % game.selection_system.selected_units.size()
		hud.inspector_subtitle.text="ПКМ: общий приказ\nГруппа готова"
		hud.inspector_health_bar.visible = false
		hud.queue_label.visible = false
		commands.visible = true
		var has_worker: bool = game.selection_system.selected_units.any(func(u): return is_instance_valid(u) and UnitConfigs.is_worker(u.unit_type))
		if commands.get_child_count() >= 6:
			commands.get_child(0).visible = has_worker
			commands.get_child(1).visible = has_worker
			commands.get_child(2).visible = has_worker
			commands.get_child(3).visible = true
			commands.get_child(4).visible = true
			commands.get_child(5).visible = true
