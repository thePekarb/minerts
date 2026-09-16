class_name MainMenu
extends Control

var current_state: String = "main" # "main", "create_room", "lobby", "match_settings"

# Root UI elements
var bg_rect: TextureRect
var screen_container: Control
var settings_modal: PanelContainer
var join_modal: PanelContainer

# Textures
var tex_main: Texture2D
var tex_create: Texture2D
var tex_lobby: Texture2D
var tex_settings: Texture2D

# Subscreen containers
var screen_main: Control
var screen_create: Control
var screen_lobby: Control
var screen_match_settings: Control

# Screen-specific interactive references
var chat_vbox: VBoxContainer
var chat_scroll: ScrollContainer
var chat_input: LineEdit
var slots_vbox: VBoxContainer
var chips_hbox: HBoxContainer
var seed_edit: LineEdit
var faction_btn_human: Button
var faction_btn_goblin: Button
var ready_btn: Button
var is_ready: bool = true
var lobby_right_col: Control
var btn_toggle_sidebar: Button

func _ready() -> void:

	_load_textures()
	_setup_background()
	_setup_screens()
	_setup_settings_modal()
	_setup_join_modal()
	
	NetworkManager.chat_message_received.connect(_on_chat_received)
	NetworkManager.lobby_updated.connect(_on_lobby_updated)
	
	set_state("main")

func _load_textures() -> void:
	var bg := _load_tex("menu_bg.jpg")
	tex_main = bg
	tex_create = bg
	tex_lobby = bg
	tex_settings = bg

func _load_tex(file_name: String) -> Texture2D:
	var res_path := "res://assets/ui/menu/" + file_name
	if ResourceLoader.exists(res_path):
		var t = load(res_path)
		if t is Texture2D:
			return t
	var abs_path := ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_path):
		var img := Image.new()
		if img.load(abs_path) == OK:
			return ImageTexture.create_from_image(img)
	return null

func _setup_background() -> void:
	bg_rect = TextureRect.new()
	bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg_rect)

	screen_container = Control.new()
	screen_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen_container)

func set_state(new_state: String) -> void:
	current_state = new_state
	screen_main.visible = (new_state == "main")
	screen_create.visible = (new_state == "create_room")
	screen_lobby.visible = (new_state == "lobby")
	screen_match_settings.visible = (new_state == "match_settings")

	match new_state:
		"main":
			bg_rect.texture = tex_main
		"create_room":
			bg_rect.texture = tex_create
		"lobby":
			bg_rect.texture = tex_lobby
			_refresh_lobby_ui()
		"match_settings":
			bg_rect.texture = tex_settings
			_update_chips_summary()

# --- STYLING HELPERS ---

func panel_style(bg: Color = Color("102533f5"), border: Color = Color("446b80"), radius: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(12)
	s.shadow_color = Color(0, 0, 0, 0.4)
	s.shadow_size = 6
	return s

func button_style(bg: Color = Color("163749"), border: Color = Color("4a7a94"), radius: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(8)
	return s

func button(text: String, callback: Callable, min_size: Vector2 = Vector2(160, 48), is_accent: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.pressed.connect(func():
		SoundManager.play_click()
		callback.call()
	)
	var norm := button_style(Color("183d50") if is_accent else Color("122736e0"), Color("38bdf8") if is_accent else Color("3c6277"))
	var hov := button_style(Color("22516b"), Color("64dfff"))
	var prs := button_style(Color("286282"), Color("64dfff"))
	b.add_theme_stylebox_override("normal", norm)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", prs)
	b.add_theme_stylebox_override("focus", hov)
	b.add_theme_font_size_override("font_size", 16)
	return b

func label(text: String, font_size: int = 18, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l

func anchored(control: Control, left: float, top: float, right: float, bottom: float, ax: float = 0, ay: float = 0) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.anchor_left = ax
	control.anchor_right = ax
	control.anchor_top = ay
	control.anchor_bottom = ay
	control.offset_left = left
	control.offset_top = top
	control.offset_right = right
	control.offset_bottom = bottom

func _add_profile_badge(parent: Control) -> void:
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", panel_style(Color("102230ee"), Color("3d6880"), 12))
	anchored(badge, -230, 24, -30, 78, 1, 0)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	badge.add_child(hbox)
	
	var avatar := TextureRect.new()
	avatar.custom_minimum_size = Vector2(40, 40)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Placeholder avatar icon
	var av_panel := Panel.new()
	av_panel.custom_minimum_size = Vector2(38, 38)
	var av_style := StyleBoxFlat.new()
	av_style.bg_color = Color("234b63")
	av_style.set_corner_radius_all(19)
	av_panel.add_theme_stylebox_override("panel", av_style)
	var av_lbl := label("🤠", 20)
	av_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	av_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	av_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	av_panel.add_child(av_lbl)
	hbox.add_child(av_panel)

	var info_box := VBoxContainer.new()
	info_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(info_box)
	
	var name_lbl := label(GameSettings.player_name, 16)
	info_box.add_child(name_lbl)
	
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 5)
	info_box.add_child(status_row)
	var dot := label("●", 12, Color("22c55e"))
	status_row.add_child(dot)
	var status_text := label("В сети", 12, Color("94a3b8"))
	status_row.add_child(status_text)
	
	parent.add_child(badge)

# --- SCREEN 1: MAIN MENU ---

func _setup_screens() -> void:
	_setup_main_screen()
	_setup_create_room_screen()
	_setup_lobby_screen()
	_setup_match_settings_screen()

func _setup_main_screen() -> void:
	screen_main = Control.new()
	screen_main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_container.add_child(screen_main)

	_add_profile_badge(screen_main)

	# Left Header Title with Logo
	var title_panel := VBoxContainer.new()
	anchored(title_panel, 60, 48, 420, 150)
	var shield_lbl := label("🛡️  КОРОЛЕВСТВА", 38, Color("f8fafc"))
	shield_lbl.add_theme_constant_override("outline_size", 4)
	shield_lbl.add_theme_color_override("font_outline_color", Color("0f172a"))
	title_panel.add_child(shield_lbl)
	var sub_lbl := label("СТРОЙ · РАЗВИВАЙ · ВЫЖИВАЙ", 15, Color("93c5fd"))
	title_panel.add_child(sub_lbl)
	screen_main.add_child(title_panel)

	# Left Menu Buttons
	var menu_box := VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 14)
	anchored(menu_box, 60, 220, 380, 560)
	screen_main.add_child(menu_box)

	var btn_continue := button("▶   Продолжить", _on_continue_pressed, Vector2(300, 56), true)
	btn_continue.add_theme_font_size_override("font_size", 18)
	menu_box.add_child(btn_continue)

	var btn_new := button("＋  Новая игра", func(): set_state("match_settings"), Vector2(300, 52))
	menu_box.add_child(btn_new)

	var btn_mp := button("👥  Сетевая игра", func(): set_state("create_room"), Vector2(300, 52))
	menu_box.add_child(btn_mp)

	var btn_settings := button("⚙   Настройки", func(): settings_modal.show(), Vector2(300, 52))
	menu_box.add_child(btn_settings)

	var btn_exit := button("⏻   Выход", func(): get_tree().quit(), Vector2(300, 52))
	menu_box.add_child(btn_exit)

	# Bottom left icons
	var bot_left := HBoxContainer.new()
	bot_left.add_theme_constant_override("separation", 12)
	anchored(bot_left, 60, -70, 250, -24, 0, 1)
	screen_main.add_child(bot_left)
	bot_left.add_child(button("💬", func(): OS.shell_open("https://discord.gg"), Vector2(46, 42)))
	bot_left.add_child(button("🎮", func(): pass, Vector2(46, 42)))
	bot_left.add_child(button("❓", func(): pass, Vector2(46, 42)))

	# Bottom right version
	var ver := label("v0.1.0 | Сборка 1234", 14, Color("94a3b8"))
	anchored(ver, -220, -50, -30, -20, 1, 1)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	screen_main.add_child(ver)

func _on_continue_pressed() -> void:
	GameSettings.is_multiplayer = false
	NetworkManager.start_match()

# --- SCREEN 2: CREATE ROOM ---

func _setup_create_room_screen() -> void:
	screen_create = Control.new()
	screen_create.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_container.add_child(screen_create)

	_add_profile_badge(screen_create)

	# Header Title
	var head := HBoxContainer.new()
	anchored(head, 60, 36, 600, 90)
	var title := label("👥  Сетевая игра · СОЗДАНИЕ КОМНАТЫ", 28, Color("f8fafc"))
	head.add_child(title)
	screen_create.add_child(head)

	var back_btn := button("‹ Назад в главное меню", func(): set_state("main"), Vector2(210, 36))
	anchored(back_btn, 60, 88, 270, 124)
	screen_create.add_child(back_btn)

	# Left Card: Room Settings
	var left_card := PanelContainer.new()
	left_card.add_theme_stylebox_override("panel", panel_style())
	anchored(left_card, 60, 140, 540, 680)
	screen_create.add_child(left_card)

	var l_vbox := VBoxContainer.new()
	l_vbox.add_theme_constant_override("separation", 14)
	left_card.add_child(l_vbox)

	var l_title := label("⚙  Настройки комнаты", 22, Color("38bdf8"))
	l_vbox.add_child(l_title)

	# Room Name
	l_vbox.add_child(label("Название комнаты", 15, Color("cbd5e1")))
	var name_edit := LineEdit.new()
	name_edit.text = GameSettings.room_name
	name_edit.custom_minimum_size = Vector2(0, 40)
	name_edit.text_changed.connect(func(t): GameSettings.room_name = t)
	l_vbox.add_child(name_edit)

	# Mode: Coop / PvP
	l_vbox.add_child(label("Режим игры", 15, Color("cbd5e1")))
	var mode_hbox := HBoxContainer.new()
	mode_hbox.add_theme_constant_override("separation", 10)
	l_vbox.add_child(mode_hbox)
	var coop_btn := button("👥 Кооператив", func(): GameSettings.room_mode = "coop", Vector2(170, 42), true)
	var pvp_btn := button("⚔ PvP", func(): GameSettings.room_mode = "pvp", Vector2(170, 42), false)
	mode_hbox.add_child(coop_btn)
	mode_hbox.add_child(pvp_btn)

	# Max players stepper
	var p_row := HBoxContainer.new()
	p_row.add_child(label("Макс. игроков", 15, Color("cbd5e1")))
	p_row.add_spacer(false)
	var stepper := HBoxContainer.new()
	var minus_btn := button("‹", func(): pass, Vector2(36, 36))
	var count_lbl := label("  4  ", 18)
	var plus_btn := button("›", func(): pass, Vector2(36, 36))
	stepper.add_child(minus_btn)
	stepper.add_child(count_lbl)
	stepper.add_child(plus_btn)
	p_row.add_child(stepper)
	l_vbox.add_child(p_row)

	# Region Dropdown
	l_vbox.add_child(label("Регион / Сеть", 15, Color("cbd5e1")))
	var region_opt := OptionButton.new()
	region_opt.custom_minimum_size = Vector2(0, 40)
	region_opt.add_item("Локальная сеть (LAN)")
	region_opt.add_item("Европа (RU)")
	l_vbox.add_child(region_opt)

	# Join by IP button
	var join_btn := button("🌐  Подключиться к игре по IP", func(): join_modal.show(), Vector2(0, 42))
	l_vbox.add_child(join_btn)

	# Right Card: Map Selection & Starting Conditions
	var right_card := PanelContainer.new()
	right_card.add_theme_stylebox_override("panel", panel_style())
	anchored(right_card, 570, 140, -60, 680, 0, 0)
	right_card.anchor_right = 1.0
	screen_create.add_child(right_card)

	var r_vbox := VBoxContainer.new()
	r_vbox.add_theme_constant_override("separation", 14)
	right_card.add_child(r_vbox)

	var r_title := label("🗺️  Выбор карты", 22, Color("38bdf8"))
	r_vbox.add_child(r_title)

	# Map Carousel Cards
	var map_row := HBoxContainer.new()
	map_row.add_theme_constant_override("separation", 10)
	r_vbox.add_child(map_row)

	for m_name in ["Зелёные долины", "Скалистые горы", "Песчаные земли", "Острова"]:
		var m_btn := button(m_name, func(): GameSettings.map_name = m_name, Vector2(140, 70), m_name == "Зелёные долины")
		map_row.add_child(m_btn)

	# Starting conditions
	r_vbox.add_child(label("🚩  Стартовые условия", 18, Color("cbd5e1")))
	var cond_row := HBoxContainer.new()
	cond_row.add_theme_constant_override("separation", 10)
	r_vbox.add_child(cond_row)
	cond_row.add_child(button("🌱 Лёгкий старт\nБольше ресурсов", func(): GameSettings.starting_resources = "light", Vector2(180, 65), true))
	cond_row.add_child(button("⚒ Стандарт\nКлассический баланс", func(): GameSettings.starting_resources = "standard", Vector2(180, 65)))
	cond_row.add_child(button("⛰ Выживание\nОграниченные запасы", func(): GameSettings.starting_resources = "hardcore", Vector2(180, 65)))

	# Bottom Action Buttons
	var bot_bar := HBoxContainer.new()
	bot_bar.add_theme_constant_override("separation", 16)
	anchored(bot_bar, 60, -90, -60, -30, 0, 1)
	bot_bar.anchor_right = 1.0
	screen_create.add_child(bot_bar)

	var btn_create_room := button("▶   Создать комнату", _on_create_room_pressed, Vector2(240, 54), true)
	btn_create_room.add_theme_font_size_override("font_size", 18)
	bot_bar.add_child(btn_create_room)

	var btn_cancel := button("✕  Отмена", func(): set_state("main"), Vector2(160, 54))
	bot_bar.add_child(btn_cancel)

func _on_create_room_pressed() -> void:
	var err := NetworkManager.host_game(7777, 4)
	if err == OK:
		set_state("lobby")
	else:
		# Fallback to local lobby
		GameSettings.is_multiplayer = true
		set_state("lobby")

# --- SCREEN 3: LOBBY / WAITING ROOM ---

func _setup_lobby_screen() -> void:
	screen_lobby = Control.new()
	screen_lobby.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_container.add_child(screen_lobby)

	_add_profile_badge(screen_lobby)

	# Header Title & Sidebar Toggle Button
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	anchored(head, 50, 32, -260, 80, 0, 0)
	head.anchor_right = 1.0
	screen_lobby.add_child(head)

	var title := label("👥  Сетевая игра · Комната ожидания", 26, Color("f8fafc"))
	head.add_child(title)

	head.add_spacer(false)

	btn_toggle_sidebar = button("💬  Чат комнаты (Скрыть)", _on_toggle_sidebar, Vector2(210, 36), true)
	head.add_child(btn_toggle_sidebar)

	# Main Content Area: Two columns with clean gap ("воздух между ними")
	var main_content := HBoxContainer.new()
	main_content.add_theme_constant_override("separation", 24)
	anchored(main_content, 50, 95, -50, -85, 0, 0)
	main_content.anchor_right = 1.0
	main_content.anchor_bottom = 1.0
	screen_lobby.add_child(main_content)

	# --- LEFT COLUMN: Room info, Slots, Map preview ---
	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 10)
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_content.add_child(left_col)

	# Room Header Bar (Room Name + Code)
	var room_bar := PanelContainer.new()
	room_bar.add_theme_stylebox_override("panel", panel_style(Color("132a3be0"), Color("38bdf8"), 10))
	left_col.add_child(room_bar)
	var r_hbox := HBoxContainer.new()
	room_bar.add_child(r_hbox)
	r_hbox.add_child(label("Комната: %s  ⚙" % GameSettings.room_name, 17, Color("f8fafc")))
	r_hbox.add_spacer(false)
	r_hbox.add_child(label("Код комнаты: %s" % GameSettings.room_code, 15, Color("94a3b8")))
	var copy_btn := button("📋", func(): DisplayServer.clipboard_set(GameSettings.room_code), Vector2(36, 30))
	copy_btn.tooltip_text = "Скопировать код комнаты"
	r_hbox.add_child(copy_btn)

	# Slots Container
	var slots_panel := PanelContainer.new()
	slots_panel.add_theme_stylebox_override("panel", panel_style())
	left_col.add_child(slots_panel)
	slots_vbox = VBoxContainer.new()
	slots_vbox.add_theme_constant_override("separation", 8)
	slots_panel.add_child(slots_vbox)

	# Map info card under slots
	var map_card := PanelContainer.new()
	map_card.add_theme_stylebox_override("panel", panel_style(Color("102533dd"), Color("2c4d61"), 10))
	left_col.add_child(map_card)
	var mc_row := HBoxContainer.new()
	mc_row.add_theme_constant_override("separation", 14)
	map_card.add_child(mc_row)
	
	var map_icon := label("🏞️", 32)
	mc_row.add_child(map_icon)
	var mc_info := VBoxContainer.new()
	mc_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mc_row.add_child(mc_info)
	mc_info.add_child(label("Карта: %s (Классическая · Выживание)" % GameSettings.map_name, 16, Color("38bdf8")))
	mc_info.add_child(label("Плодородные земли, реки и горы. Идеальное место для основания поселения.", 13, Color("94a3b8")))

	# --- RIGHT COLUMN: Room Chat ---
	lobby_right_col = VBoxContainer.new()
	lobby_right_col.add_theme_constant_override("separation", 10)
	lobby_right_col.custom_minimum_size = Vector2(360, 0)
	lobby_right_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_content.add_child(lobby_right_col)

	# Chat Panel
	var chat_panel := PanelContainer.new()
	chat_panel.add_theme_stylebox_override("panel", panel_style())
	chat_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lobby_right_col.add_child(chat_panel)

	var c_box := VBoxContainer.new()
	c_box.add_theme_constant_override("separation", 8)
	chat_panel.add_child(c_box)

	var c_head := HBoxContainer.new()
	c_box.add_child(c_head)
	c_head.add_child(label("💬  Чат комнаты", 18, Color("38bdf8")))
	c_head.add_spacer(false)
	var c_close_btn := button("✕ Скрыть", _on_toggle_sidebar, Vector2(80, 26))
	c_close_btn.add_theme_font_size_override("font_size", 12)
	c_head.add_child(c_close_btn)

	chat_scroll = ScrollContainer.new()
	chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_scroll.custom_minimum_size = Vector2(0, 200)
	chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	c_box.add_child(chat_scroll)

	chat_vbox = VBoxContainer.new()
	chat_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_vbox.add_theme_constant_override("separation", 4)
	chat_scroll.add_child(chat_vbox)

	# Initial mock chat messages
	_add_chat_msg("Tanakron", "Всем привет!", "19:24")
	_add_chat_msg("ArcherFox", "Готов к новой карте!", "19:25")
	_add_chat_msg("StoneBear", "Давайте строить большое королевство!", "19:25")

	# Chat Input
	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 8)
	c_box.add_child(input_row)

	chat_input = LineEdit.new()
	chat_input.placeholder_text = "Написать сообщение..."
	chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_input.custom_minimum_size = Vector2(0, 36)
	chat_input.text_submitted.connect(_on_send_chat)
	input_row.add_child(chat_input)

	var send_btn := button("➤", func(): _on_send_chat(chat_input.text), Vector2(40, 36), true)
	input_row.add_child(send_btn)

	# Bottom Action Bar
	var bot_bar := HBoxContainer.new()
	bot_bar.add_theme_constant_override("separation", 14)
	anchored(bot_bar, 50, -75, -50, -25, 0, 1)
	bot_bar.anchor_right = 1.0
	screen_lobby.add_child(bot_bar)

	ready_btn = button("✓  Готов", _on_toggle_ready, Vector2(140, 46), true)
	bot_bar.add_child(ready_btn)

	var match_cfg_btn := button("⚙  Настройки матча", func(): set_state("match_settings"), Vector2(180, 46))
	bot_bar.add_child(match_cfg_btn)

	var leave_btn := button("←  Назад", func():
		NetworkManager.leave_game()
		set_state("create_room")
	, Vector2(130, 46))
	bot_bar.add_child(leave_btn)

	bot_bar.add_spacer(false)

	var start_box := VBoxContainer.new()
	start_box.alignment = BoxContainer.ALIGNMENT_CENTER
	bot_bar.add_child(start_box)

	var start_btn := button("▶   Начать игру  👑", _on_start_game_pressed, Vector2(240, 46), true)
	start_btn.add_theme_font_size_override("font_size", 17)
	var green_style := button_style(Color("15803d"), Color("4ade80"), 12)
	start_btn.add_theme_stylebox_override("normal", green_style)
	start_btn.add_theme_stylebox_override("hover", button_style(Color("16a34a"), Color("86efac"), 12))
	start_box.add_child(start_btn)

	var hint_lbl := label("Только хост может начать игру", 11, Color("94a3b8"))
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_box.add_child(hint_lbl)

func _on_toggle_sidebar() -> void:
	if not lobby_right_col:
		return
	lobby_right_col.visible = not lobby_right_col.visible
	if btn_toggle_sidebar:
		if lobby_right_col.visible:
			btn_toggle_sidebar.text = "💬  Чат комнаты (Скрыть)"
		else:
			btn_toggle_sidebar.text = "💬  Чат комнаты (Показать)"

func _refresh_lobby_ui() -> void:
	if not slots_vbox:
		return
	for child in slots_vbox.get_children():
		child.queue_free()

	for i in range(GameSettings.lobby_slots.size()):
		var slot: Dictionary = GameSettings.lobby_slots[i]
		var idx: int = i
		var slot_card := PanelContainer.new()
		slot_card.add_theme_stylebox_override("panel", panel_style(Color("0f1f2cee"), Color("2a485a"), 8))
		slots_vbox.add_child(slot_card)

		var s_row := HBoxContainer.new()
		s_row.add_theme_constant_override("separation", 8)
		slot_card.add_child(s_row)

		if slot["type"] == "open":
			var add_btn := button("＋   Свободный слот · Добавить бота", func(): _on_open_slot_clicked(idx), Vector2(0, 38))
			add_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			s_row.add_child(add_btn)
		else:
			# Avatar / Type icon
			var icon_str: String = "👑" if slot.get("is_host", false) else ("🤖" if slot["type"] == "bot" else "👤")
			var type_lbl := label(icon_str, 18)
			s_row.add_child(type_lbl)

			# Name
			var name_lbl := label(slot["name"], 15, Color("f8fafc"))
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_lbl.custom_minimum_size = Vector2(100, 0)
			s_row.add_child(name_lbl)

			# Status (Готов / Не готов)
			var is_r: bool = slot.get("ready", true)
			var status_lbl := label("● Готов" if is_r else "○ Не готов", 13, Color("22c55e") if is_r else Color("f59e0b"))
			status_lbl.custom_minimum_size = Vector2(75, 0)
			s_row.add_child(status_lbl)

			# Faction Selector Button
			var f_name: String = "🏹 Гоблины" if slot.get("faction", "player") == "goblin" else "👑 Королевство"
			var f_btn := button(f_name, func(): _toggle_slot_faction(idx), Vector2(115, 32))
			f_btn.add_theme_font_size_override("font_size", 13)
			f_btn.tooltip_text = "Нажмите для переключения фракции"
			s_row.add_child(f_btn)

			# Team flag button
			var team_str: String = slot.get("team", "Синяя команда")
			var team_btn := button(team_str, func(): _cycle_slot_team(idx), Vector2(120, 32))
			team_btn.add_theme_font_size_override("font_size", 13)
			s_row.add_child(team_btn)

			# Ping
			var ping_val: int = slot.get("ping", 25)
			var ping_lbl := label("📶 %d мс" % ping_val, 12, Color("94a3b8"))
			s_row.add_child(ping_lbl)

			# Remove / Clear slot button (if not host)
			if idx > 0:
				var del_btn := button("✕", func():
					GameSettings.clear_slot(idx)
					NetworkManager.sync_lobby_to_all()
					_refresh_lobby_ui()
				, Vector2(32, 32))
				s_row.add_child(del_btn)

func _toggle_slot_faction(idx: int) -> void:
	if idx < 0 or idx >= GameSettings.lobby_slots.size():
		return
	var cur: String = GameSettings.lobby_slots[idx].get("faction", "player")
	var new_f: String = "goblin" if cur == "player" else "player"
	GameSettings.lobby_slots[idx]["faction"] = new_f
	if idx == 0:
		GameSettings.player_faction = new_f
	NetworkManager.sync_lobby_to_all()
	_refresh_lobby_ui()

func _cycle_slot_team(idx: int) -> void:
	if idx < 0 or idx >= GameSettings.lobby_slots.size():
		return
	var teams: Array = ["Синяя команда", "Красная команда", "Желтая команда", "Зеленая команда", "Фиолетовая команда"]
	var cur: String = GameSettings.lobby_slots[idx].get("team", "Синяя команда")
	var next_idx: int = (teams.find(cur) + 1) % teams.size()
	GameSettings.lobby_slots[idx]["team"] = teams[next_idx]
	NetworkManager.sync_lobby_to_all()
	_refresh_lobby_ui()

func _on_open_slot_clicked(idx: int) -> void:
	# Add Bot with alternating faction
	var b_faction: String = "goblin" if idx % 2 == 1 else "player"
	GameSettings.add_bot_to_slot(idx, b_faction)
	NetworkManager.sync_lobby_to_all()
	_refresh_lobby_ui()

func _on_toggle_ready() -> void:
	is_ready = not is_ready
	GameSettings.lobby_slots[0]["ready"] = is_ready
	ready_btn.text = "✓  Готов" if is_ready else "○  Не готов"
	NetworkManager.sync_lobby_to_all()
	_refresh_lobby_ui()

func _on_send_chat(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	chat_input.text = ""
	NetworkManager.send_chat(text)

func _on_chat_received(sender: String, msg: String, time_str: String) -> void:
	_add_chat_msg(sender, msg, time_str)

func _add_chat_msg(sender: String, msg: String, time_str: String) -> void:
	if not chat_vbox:
		return
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.mouse_filter = Control.MOUSE_FILTER_PASS
	var sender_color: String = "#38bdf8" if sender == GameSettings.player_name else ("#fbbf24" if sender == "Система" else "#a78bfa")
	rtl.text = "[color=#64748b][%s][/color] [color=%s][b]%s:[/b][/color] [color=#f8fafc]%s[/color]" % [time_str, sender_color, sender, msg]
	chat_vbox.add_child(rtl)
	await get_tree().process_frame
	if chat_scroll:
		chat_scroll.scroll_vertical = int(chat_scroll.get_v_scroll_bar().max_value)

func _current_time_str() -> String:
	var dt := Time.get_time_dict_from_system()
	return "%02d:%02d" % [dt.hour, dt.minute]

func _on_lobby_updated() -> void:
	_refresh_lobby_ui()

func _on_start_game_pressed() -> void:
	NetworkManager.start_match()

# --- SCREEN 4: MATCH SETTINGS & LAUNCH (NEW GAME / MAP CONFIG) ---

func _setup_match_settings_screen() -> void:
	screen_match_settings = Control.new()
	screen_match_settings.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_container.add_child(screen_match_settings)

	_add_profile_badge(screen_match_settings)

	# Header Title
	var head := HBoxContainer.new()
	anchored(head, 60, 36, 700, 90)
	var title := label("⚙  НАСТРОЙКИ КАРТЫ И ЗАПУСК", 28, Color("f8fafc"))
	head.add_child(title)
	screen_match_settings.add_child(head)

	# Left Column: Map preview card and Faction Selector
	var left_card := PanelContainer.new()
	left_card.add_theme_stylebox_override("panel", panel_style())
	anchored(left_card, 60, 110, 560, 680)
	screen_match_settings.add_child(left_card)

	var l_vbox := VBoxContainer.new()
	l_vbox.add_theme_constant_override("separation", 14)
	left_card.add_child(l_vbox)

	l_vbox.add_child(label("🗺️  %s" % GameSettings.map_name, 22, Color("38bdf8")))

	# Map description card
	var desc_box := PanelContainer.new()
	desc_box.add_theme_stylebox_override("panel", panel_style(Color("102533cc"), Color("29475c"), 10))
	l_vbox.add_child(desc_box)
	var desc_lbl := label("Плодородные земли, окружённые горами и чистыми озёрами. Идеальное место для процветающего поселения, но будьте готовы — в темноте пробуждаются древние опасности.\n\nРекомендуется для 1–4 игроков.", 14, Color("cbd5e1"))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_box.add_child(desc_lbl)

	# PROMINENT FACTION SELECTOR
	l_vbox.add_child(label("🚩  ВЫБОР ВАШЕЙ ФРАКЦИИ", 18, Color("facc15")))
	var fact_row := HBoxContainer.new()
	fact_row.add_theme_constant_override("separation", 12)
	l_vbox.add_child(fact_row)

	faction_btn_human = button("👑 Королевство (Люди)\nРабочие, рыцари, лучники", func(): _select_faction("player"), Vector2(210, 68), GameSettings.player_faction == "player")
	fact_row.add_child(faction_btn_human)

	faction_btn_goblin = button("🏹 Клан гоблинов\nСборщики, рубаки, тролли", func(): _select_faction("goblin"), Vector2(210, 68), GameSettings.player_faction == "goblin")
	fact_row.add_child(faction_btn_goblin)

	# Right Column: Detailed sliders and switches
	var right_card := PanelContainer.new()
	right_card.add_theme_stylebox_override("panel", panel_style())
	anchored(right_card, 590, 110, -60, 680, 0, 0)
	right_card.anchor_right = 1.0
	screen_match_settings.add_child(right_card)

	var r_scroll := ScrollContainer.new()
	r_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_card.add_child(r_scroll)

	var r_vbox := VBoxContainer.new()
	r_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r_vbox.add_theme_constant_override("separation", 12)
	r_scroll.add_child(r_vbox)

	# Map Size
	r_vbox.add_child(label("Размер карты", 15, Color("cbd5e1")))
	var size_row := HBoxContainer.new()
	size_row.add_theme_constant_override("separation", 8)
	r_vbox.add_child(size_row)
	for s_val in ["Маленькая", "Средняя", "Большая"]:
		size_row.add_child(button(s_val, func(): GameSettings.map_size = s_val; _update_chips_summary(), Vector2(110, 38), s_val == "Средняя"))

	# Difficulty
	r_vbox.add_child(label("Сложность", 15, Color("cbd5e1")))
	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 8)
	r_vbox.add_child(diff_row)
	for d_val in ["Легкая", "Нормальная", "Сложная"]:
		diff_row.add_child(button(d_val, func(): GameSettings.difficulty = d_val; _update_chips_summary(), Vector2(110, 38), d_val == "Нормальная"))

	# Sliders
	r_vbox.add_child(label("Богатство ресурсов", 15, Color("cbd5e1")))
	var res_slider := HSlider.new()
	res_slider.min_value = 0.5
	res_slider.max_value = 1.5
	res_slider.step = 0.25
	res_slider.value = GameSettings.resources_richness
	res_slider.value_changed.connect(func(v): GameSettings.resources_richness = v; _update_chips_summary())
	r_vbox.add_child(res_slider)

	r_vbox.add_child(label("Количество врагов", 15, Color("cbd5e1")))
	var enemy_slider := HSlider.new()
	enemy_slider.min_value = 0.5
	enemy_slider.max_value = 2.0
	enemy_slider.step = 0.25
	enemy_slider.value = GameSettings.enemy_count
	enemy_slider.value_changed.connect(func(v): GameSettings.enemy_count = v; _update_chips_summary())
	r_vbox.add_child(enemy_slider)

	# Switches
	var wave_chk := CheckButton.new()
	wave_chk.text = "🌙  Ночная волна"
	wave_chk.button_pressed = GameSettings.night_wave_enabled
	wave_chk.toggled.connect(func(v): GameSettings.night_wave_enabled = v; _update_chips_summary())
	r_vbox.add_child(wave_chk)

	var fog_chk := CheckButton.new()
	fog_chk.text = "👁️  Туман войны"
	fog_chk.button_pressed = GameSettings.fog_enabled
	fog_chk.toggled.connect(func(v): GameSettings.fog_enabled = v; _update_chips_summary())
	r_vbox.add_child(fog_chk)

	var day_chk := CheckButton.new()
	day_chk.text = "☀️  Цикл день / ночь"
	day_chk.button_pressed = GameSettings.day_night_enabled
	day_chk.toggled.connect(func(v): GameSettings.day_night_enabled = v; _update_chips_summary())
	r_vbox.add_child(day_chk)

	# Seed Input
	r_vbox.add_child(label("Seed (ключ генерации карты)", 15, Color("cbd5e1")))
	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 8)
	r_vbox.add_child(seed_row)

	seed_edit = LineEdit.new()
	seed_edit.text = str(GameSettings.seed_val)
	seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_edit.text_changed.connect(func(t):
		if t.is_valid_int():
			GameSettings.seed_val = t.to_int()
			_update_chips_summary()
	)
	seed_row.add_child(seed_edit)

	var rand_seed_btn := button("🔀", func():
		GameSettings.randomize_seed()
		seed_edit.text = str(GameSettings.seed_val)
		_update_chips_summary()
	, Vector2(46, 38))
	seed_row.add_child(rand_seed_btn)

	# Bottom Summary Chips Bar
	chips_hbox = HBoxContainer.new()
	chips_hbox.add_theme_constant_override("separation", 8)
	anchored(chips_hbox, 60, -118, -60, -84, 0, 1)
	chips_hbox.anchor_right = 1.0
	screen_match_settings.add_child(chips_hbox)

	# Bottom Action Buttons
	var bot_bar := HBoxContainer.new()
	bot_bar.add_theme_constant_override("separation", 16)
	anchored(bot_bar, 60, -74, -60, -20, 0, 1)
	bot_bar.anchor_right = 1.0
	screen_match_settings.add_child(bot_bar)

	var back_btn := button("‹  Назад", func():
		if NetworkManager.is_active():
			set_state("lobby")
		else:
			set_state("main")
	, Vector2(160, 48))
	bot_bar.add_child(back_btn)

	bot_bar.add_spacer(false)

	var start_btn := button("▶   Запуск матча", _on_launch_match_pressed, Vector2(250, 48), true)
	start_btn.add_theme_font_size_override("font_size", 18)
	bot_bar.add_child(start_btn)

func _select_faction(f_val: String) -> void:
	GameSettings.player_faction = f_val
	GameSettings.lobby_slots[0]["faction"] = f_val
	faction_btn_human.add_theme_stylebox_override("normal", button_style(Color("183d50") if f_val == "player" else Color("122736e0"), Color("38bdf8") if f_val == "player" else Color("3c6277")))
	faction_btn_goblin.add_theme_stylebox_override("normal", button_style(Color("183d50") if f_val == "goblin" else Color("122736e0"), Color("38bdf8") if f_val == "goblin" else Color("3c6277")))
	_update_chips_summary()

func _update_chips_summary() -> void:
	if not chips_hbox:
		return
	for c in chips_hbox.get_children():
		c.queue_free()

	var chips: Array = [
		"🗺️ %s" % GameSettings.map_name,
		"📐 %s" % GameSettings.map_size,
		"⚡ %s" % GameSettings.difficulty,
		"🌙 Волна: %s" % ("Вкл" if GameSettings.night_wave_enabled else "Выкл"),
		"👁️ Туман: %s" % ("Вкл" if GameSettings.fog_enabled else "Выкл"),
		"🚩 Фракция: %s" % ("Королевство" if GameSettings.player_faction == "player" else "Гоблины"),
		"🎲 Seed: %s" % str(GameSettings.seed_val)
	]

	for txt in chips:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", panel_style(Color("132a3be0"), Color("38bdf8"), 8))
		var l := label(txt, 12, Color("e2e8f0"))
		chip.add_child(l)
		chips_hbox.add_child(chip)

func _on_launch_match_pressed() -> void:
	NetworkManager.start_match()

# --- MODALS ---

func _setup_settings_modal() -> void:
	settings_modal = PanelContainer.new()
	settings_modal.add_theme_stylebox_override("panel", panel_style(Color("0f1e2bef"), Color("38bdf8"), 16))
	anchored(settings_modal, -220, -160, 220, 160, 0.5, 0.5)
	add_child(settings_modal)
	settings_modal.hide()

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	settings_modal.add_child(box)

	box.add_child(label("⚙  Настройки графики и звука", 20, Color("38bdf8")))

	var scale_lbl := label("Качество 3D графики:", 14)
	box.add_child(scale_lbl)
	var scale_opt := OptionButton.new()
	scale_opt.add_item("Производительность · 60% 3D")
	scale_opt.add_item("Сбалансировано · 75% 3D")
	scale_opt.add_item("Качество · 100% 3D")
	scale_opt.select(1)
	scale_opt.item_selected.connect(func(idx):
		get_viewport().scaling_3d_scale = [0.60, 0.75, 1.0][idx]
	)
	box.add_child(scale_opt)

	var audio_chk := CheckButton.new()
	audio_chk.text = "Звук"
	audio_chk.button_pressed = not SoundManager.is_muted
	audio_chk.toggled.connect(func(v): SoundManager.is_muted = not v)
	box.add_child(audio_chk)

	var close_btn := button("Закрыть", func(): settings_modal.hide(), Vector2(120, 38))
	box.add_child(close_btn)

func _setup_join_modal() -> void:
	join_modal = PanelContainer.new()
	join_modal.add_theme_stylebox_override("panel", panel_style(Color("0f1e2bef"), Color("38bdf8"), 16))
	anchored(join_modal, -280, -210, 280, 210, 0.5, 0.5)
	add_child(join_modal)
	join_modal.hide()

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	join_modal.add_child(box)

	box.add_child(label("🌐  Локальная сеть (LAN)", 20, Color("38bdf8")))

	var server_list_scroll := ScrollContainer.new()
	server_list_scroll.custom_minimum_size = Vector2(520, 150)
	server_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(server_list_scroll)

	var server_list_vbox := VBoxContainer.new()
	server_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	server_list_vbox.add_theme_constant_override("separation", 6)
	server_list_scroll.add_child(server_list_vbox)

	var searching_lbl := label("🔍 Поиск серверов в локальной сети...", 14, Color("94a3b8"))
	server_list_vbox.add_child(searching_lbl)

	var update_servers_ui = func():
		var servers: Array = NetworkManager.get_discovered_servers_list()
		for child in server_list_vbox.get_children():
			child.queue_free()
		if servers.is_empty():
			var empty_lbl := label("🔍 Поиск серверов в локальной сети...", 14, Color("94a3b8"))
			server_list_vbox.add_child(empty_lbl)
		else:
			for s in servers:
				var row := PanelContainer.new()
				row.add_theme_stylebox_override("panel", panel_style(Color("183548"), Color("38bdf8"), 8))
				var rhbox := HBoxContainer.new()
				rhbox.add_theme_constant_override("separation", 12)
				row.add_child(rhbox)

				var info_lbl := label("🏰 %s  (Хост: %s) · %d/%d · %s" % [s.get("room_name", "Комната"), s.get("host_name", "Хост"), s.get("players", 1), s.get("max_players", 6), s.get("ip", "127.0.0.1")], 14, Color("f1f5f9"))
				info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				rhbox.add_child(info_lbl)

				var s_ip: String = s.get("ip", "127.0.0.1")
				var s_port: int = int(s.get("port", 7777))
				var join_srv_btn := button("Войти", func():
					var err := NetworkManager.join_game(s_ip, s_port)
					if err == OK:
						join_modal.hide()
						set_state("lobby")
				, Vector2(90, 34), true)
				rhbox.add_child(join_srv_btn)
				server_list_vbox.add_child(row)

	NetworkManager.server_discovered.connect(func(_info): update_servers_ui.call())
	NetworkManager.server_expired.connect(func(_key): update_servers_ui.call())

	join_modal.visibility_changed.connect(func():
		if join_modal.visible:
			NetworkManager.start_listening()
			update_servers_ui.call()
		else:
			NetworkManager.stop_listening()
	)

	box.add_child(label("Прямое подключение по IP:", 14, Color("cbd5e1")))
	var ip_edit := LineEdit.new()
	ip_edit.text = "127.0.0.1"
	ip_edit.placeholder_text = "127.0.0.1 или IP в сети"
	box.add_child(ip_edit)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	box.add_child(btn_row)

	var connect_btn := button("Подключиться по IP", func():
		var ip_str: String = ip_edit.text.strip_edges()
		if ip_str.is_empty():
			ip_str = "127.0.0.1"
		var err := NetworkManager.join_game(ip_str, 7777)
		if err == OK:
			join_modal.hide()
			set_state("lobby")
	, Vector2(180, 40), true)
	btn_row.add_child(connect_btn)

	var cancel_btn := button("Отмена", func(): join_modal.hide(), Vector2(100, 40))
	btn_row.add_child(cancel_btn)
