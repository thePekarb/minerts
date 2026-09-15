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
	anchored(hud.build_dock,-302,112,-18,710,1)
	var box: VBoxContainer = hud.build_dock.get_node("VBox")
	box.get_node("Title").hide();box.get_node("HSeparator").hide()
	var heading := button("Постройки                  ⌃",func():scroll.visible=not scroll.visible;category.visible=scroll.visible)
	box.add_child(heading);box.move_child(heading,0)
	category=OptionButton.new()
	for text in ["Все постройки","Жильё","Оборона","Производство","Ресурсы"]:category.add_item(text)
	category.item_selected.connect(filter_buildings);box.add_child(category);box.move_child(category,1)
	scroll=ScrollContainer.new();scroll.custom_minimum_size=Vector2(0,456);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll);box.move_child(scroll,2);hud.build_grid.reparent(scroll)
	hud.build_grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;hud.build_grid.add_theme_constant_override("h_separation",8);hud.build_grid.add_theme_constant_override("v_separation",8)
	var i: int = 0
	for tile in hud.build_grid.get_children():
		if tile.is_queued_for_deletion():continue
		tile.text="";tile.custom_minimum_size=Vector2(120,116)
		var rect := Rect2(337 if i%2==0 else 570,170+(i/2)*221,219,207)
		var image := picture(atlas("build-reference.png",rect),Vector2.ZERO);tile.add_child(image);image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tile.set_meta("catalog_index",i);build_tiles[i]=tile;i+=1
	hud.axe_tool_btn.text="Лесозаготовка";hud.axe_tool_btn.custom_minimum_size=Vector2(0,44)
	# Reuse the existing live inspector controls and gameplay connections.
	var old: VBoxContainer = hud.inspector.get_node("VBox")
	var row := HBoxContainer.new();row.add_theme_constant_override("separation",16);hud.inspector.add_child(row)
	portrait=picture(atlas("worker-reference.png",Rect2(100,213,290,309)),Vector2(100,110));row.add_child(portrait)
	info=VBoxContainer.new();info.custom_minimum_size=Vector2(220,0);row.add_child(info)
	hud.inspector_title.reparent(info);hud.inspector_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;hud.inspector_title.add_theme_font_size_override("font_size",23)
	hud.inspector_subtitle.reparent(info);hud.inspector_subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;hud.inspector_subtitle.add_theme_font_size_override("font_size",16)
	hud.inspector_health_bar.reparent(info);hud.inspector_health_bar.custom_minimum_size=Vector2(220,16)
	var fill := panel_style();fill.bg_color=Color("62c879");fill.set_border_width_all(0);fill.set_corner_radius_all(5)
	hud.inspector_health_bar.add_theme_stylebox_override("fill",fill)
	hud.queue_label.reparent(info);hud.queue_label.custom_minimum_size=Vector2(230,0);hud.queue_label.add_theme_font_size_override("font_size",14)
	commands=HBoxContainer.new();commands.add_theme_constant_override("separation",8);row.add_child(commands)
	for item in [["Собрать","gather",Rect2(1000,230,240,283)],["Копать","dig",Rect2(1270,230,240,283)],["Нести","carry",Rect2(1535,230,240,283)],["Отменить","stop",Rect2(1800,230,278,283)]]:
		var action: String = item[1]
		var b := button("",func():command(action),Vector2(104,108));b.tooltip_text=item[0]
		var image := picture(atlas("worker-reference.png",item[2]),Vector2.ZERO);b.add_child(image);image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		commands.add_child(b)
	hud.inspector_action_box.reparent(row);hud.inspector_action_box.custom_minimum_size=Vector2(320,0)
	old.hide();hud.inspector.add_theme_stylebox_override("panel",panel_style());anchored(hud.inspector,-420,-156,420,-20,.5,1)
	# Circular live minimap, camera controls and cutaway remain real controls.
	anchored(hud.minimap,20,-258,258,-20,0,1);hud.minimap.custom_minimum_size=Vector2(238,238)
	var map_shader := Shader.new();map_shader.code="shader_type canvas_item; varying vec2 pixel; void vertex(){pixel=VERTEX;} void fragment(){if(distance(pixel,vec2(119.0))>117.0) discard; COLOR=texture(TEXTURE,UV)*COLOR;}"
	var map_material := ShaderMaterial.new();map_material.shader=map_shader;hud.minimap.material=map_material
	var map_button := button("Карта",func():hud.minimap.overview=not hud.minimap.overview;hud.minimap.queue_redraw(),Vector2(76,46));hud.add_child(map_button);anchored(map_button,188,-300,264,-254,0,1)
	pause_button=button("Ⅱ",toggle_pause,Vector2(64,64));hud.add_child(pause_button);pause_button.add_theme_font_size_override("font_size",30);pause_button.process_mode=Node.PROCESS_MODE_ALWAYS;anchored(pause_button,-82,18,-18,82,1)
	var settings_button := button("⚙",func():settings.visible=not settings.visible,Vector2(64,64));hud.add_child(settings_button);settings_button.add_theme_font_size_override("font_size",30);settings_button.process_mode=Node.PROCESS_MODE_ALWAYS;anchored(settings_button,-158,18,-94,82,1)
	var xbutton := button("Срез земли\nX",func():hud.get_parent().underground_system.toggle_view(),Vector2(104,74));hud.add_child(xbutton);anchored(xbutton,-130,-108,-20,-28,1,1)
	_setup_settings()
	hud.train_worker_btn.text="Рабочий · 20 еды";hud.train_warrior_btn.text="Рыцарь";hud.train_archer_btn.text="Лучник"
	hud.mine_upgrade_btn.text="Углубить шахту";hud.mine_eject_btn.text="Вывести рабочих"
func filter_buildings(index: int) -> void:
	var groups: Array = [[],[0,1],[3,4,5,6],[6,7,8,11],[2,8,9,10,11]]
	for i in build_tiles:build_tiles[i].visible=index==0 or i in groups[index]
func toggle_pause() -> void:
	hud.get_tree().paused=not hud.get_tree().paused;pause_button.text="▶" if hud.get_tree().paused else "Ⅱ"
func _setup_settings() -> void:
	settings=PanelContainer.new();hud.add_child(settings);settings.add_theme_stylebox_override("panel",panel_style());anchored(settings,-240,-150,240,150,.5,.5);settings.process_mode=Node.PROCESS_MODE_ALWAYS
	var box := VBoxContainer.new();settings.add_child(box);box.add_child(label("Настройки графики",24))
	var quality := OptionButton.new()
	for text in ["Сбалансировано · 75% 3D","Производительность · 60% 3D","Качество · 100% 3D"]:quality.add_item(text)
	box.add_child(quality);quality.item_selected.connect(set_quality);set_quality(0)
	box.add_child(label("Интерфейс всегда в полном разрешении",16))
	var audio := CheckButton.new();audio.text="Звук";audio.button_pressed=not SoundManager.is_muted;audio.toggled.connect(func(enabled):SoundManager.is_muted=not enabled);box.add_child(audio)
	box.add_child(button("Закрыть",func():settings.hide()));settings.hide()
func set_quality(index: int) -> void:
	hud.get_viewport().scaling_3d_scale=[.75,.60,1.0][index]
	hud.get_viewport().msaa_3d=Viewport.MSAA_DISABLED if index<2 else Viewport.MSAA_2X
func command(action: String) -> void:
	var game: Main = hud.get_parent()
	if action=="stop":
		for u in game.selection_system.selected_units:
			game.selection_system.cancel_assignments(u);u.target=null;u.current_order=UnitConfigs.UnitOrder.MOVE;u.stop()
		command_mode="";return
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
	if not hud.inspector.visible:return
	var unit: Unit = hud.inspected_unit
	commands.visible=not is_instance_valid(hud.inspected_building)
	hud.inspector_action_box.visible=is_instance_valid(hud.inspected_building) or (is_instance_valid(unit) and (UnitConfigs.is_vessel(unit.unit_type) or unit.underground_unit))
	portrait.visible=is_instance_valid(unit) and UnitConfigs.is_worker(unit.unit_type)
	if is_instance_valid(unit):
		hud.inspector_title.text=NAMES[unit.unit_type]
		var status: String = {UnitConfigs.UnitState.IDLE:"Ожидает приказа",UnitConfigs.UnitState.MOVING:"Идёт к заданию",UnitConfigs.UnitState.GATHERING:"Добывает ресурсы",UnitConfigs.UnitState.BUILDING:"Строит",UnitConfigs.UnitState.ATTACKING:"Атакует",UnitConfigs.UnitState.RETURNING_TO_STORAGE:"Несёт ресурсы",UnitConfigs.UnitState.MINING_INSIDE:"В шахте"}.get(unit.state,"Выполняет приказ")
		hud.inspector_subtitle.text="%d / %d HP\n%s" % [unit.health,unit.max_health,status]
		for i in range(3):commands.get_child(i).visible=UnitConfigs.is_worker(unit.unit_type)
	elif is_instance_valid(hud.inspected_building):
		var b: Building = hud.inspected_building
		hud.inspector_title.text=["Костёр","Хижина","Склад","Стена","Ворота","Башня","Мастерская","Каменная шахта","Казармы","Ферма","Колодец","Порт"][b.building_type]
		hud.inspector_subtitle.text="%d / %d HP\n%s" % [b.health,b.max_health,"Построено" if b.is_constructed else "Строительство %d%%" % b.construction_progress]
	else:
		hud.inspector_title.text="Выбран отряд";hud.inspector_subtitle.text="ПКМ: общий приказ"
