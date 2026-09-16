class_name ProductionPanel
extends PanelContainer

var hud: HUD
var game: Main
var building: Building
var title: Label
var cat_title: Label
var stock: Label
var slots: Array[Dictionary] = []
var catalog: GridContainer
var content_scroll: ScrollContainer
var cards: Array[Dictionary] = []
var message: Label
var timer: float = 0.0
var veil: ColorRect
var crafting: bool = false
var icons: Dictionary = {}

func setup(owner: HUD) -> void:
	hud = owner
	game = hud.get_parent()

	# Dark modal backdrop
	veil = ColorRect.new()
	veil.color = Color(0.02, 0.05, 0.08, 0.65)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.hide()

	hud.add_child(self)

	# Main window styling (Deep dark blue with cyan glowing border, matching mockup)
	var win_style := StyleBoxFlat.new()
	win_style.bg_color = Color("091929fa")
	win_style.border_color = Color("0284c7")
	win_style.set_border_width_all(2)
	win_style.set_corner_radius_all(16)
	win_style.content_margin_left = 22
	win_style.content_margin_right = 22
	win_style.content_margin_top = 18
	win_style.content_margin_bottom = 18
	win_style.shadow_color = Color(0, 0, 0, 0.6)
	win_style.shadow_size = 16
	add_theme_stylebox_override("panel", win_style)

	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left = -480
	offset_right = 480
	offset_top = -285
	offset_bottom = 285
	mouse_filter = Control.MOUSE_FILTER_STOP

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 14)
	content_scroll=ScrollContainer.new()
	content_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(content_scroll)
	root_vbox.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content_scroll.add_child(root_vbox)

	# --- HEADER ---
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 10)
	root_vbox.add_child(heading)

	var banner_icon := Label.new()
	banner_icon.text = "🏰"
	banner_icon.add_theme_font_size_override("font_size", 24)
	heading.add_child(banner_icon)

	title = Label.new()
	title.text = "Очередь найма"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("f8fafc"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(48, 48)
	close_btn.add_theme_font_size_override("font_size", 16)
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color("0f2336")
	close_style.border_color = Color("1e3d5a")
	close_style.set_border_width_all(1)
	close_style.set_corner_radius_all(8)
	close_btn.add_theme_stylebox_override("normal", close_style)
	close_btn.pressed.connect(close)
	heading.add_child(close_btn)

	# --- TOP SECTION: QUEUE ---
	var q_section := VBoxContainer.new()
	q_section.add_theme_constant_override("separation", 8)
	root_vbox.add_child(q_section)

	var q_head := HBoxContainer.new()
	q_head.add_theme_constant_override("separation", 8)
	q_section.add_child(q_head)

	var q_title := Label.new()
	q_title.text = "⌛  В очереди"
	q_title.add_theme_font_size_override("font_size", 18)
	q_title.add_theme_color_override("font_color", Color("f1f5f9"))
	q_head.add_child(q_title)

	var q_hint := Label.new()
	q_hint.text = "(карточка — отмена)"
	q_hint.add_theme_font_size_override("font_size", 13)
	q_hint.add_theme_color_override("font_color", Color("64748b"))
	q_head.add_child(q_hint)

	# 5 Queue Slots Row
	var slots_row := HBoxContainer.new()
	slots_row.add_theme_constant_override("separation", 10)
	var queue_scroll:=ScrollContainer.new()
	queue_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	queue_scroll.custom_minimum_size=Vector2(0,194)
	q_section.add_child(queue_scroll);queue_scroll.add_child(slots_row)

	for i in range(6):
		var index: int = i
		var slot_card := PanelContainer.new()
		slot_card.custom_minimum_size = Vector2(174, 180)
		slot_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slots_row.add_child(slot_card)

		# Slot card visual styles
		var normal_style := StyleBoxFlat.new()
		normal_style.bg_color = Color("091827")
		normal_style.border_color = Color("1e3d5b")
		normal_style.set_border_width_all(1)
		normal_style.set_corner_radius_all(12)
		normal_style.set_content_margin_all(8)

		var active_style := StyleBoxFlat.new()
		active_style.bg_color = Color("0c2438")
		active_style.border_color = Color("38bdf8")
		active_style.set_border_width_all(2)
		active_style.set_corner_radius_all(12)
		active_style.set_content_margin_all(8)

		var empty_style := StyleBoxFlat.new()
		empty_style.bg_color = Color("06121e")
		empty_style.border_color = Color("142738")
		empty_style.set_border_width_all(1)
		empty_style.set_corner_radius_all(12)
		empty_style.set_content_margin_all(8)

		slot_card.add_theme_stylebox_override("panel", empty_style)

		var slot_vbox := VBoxContainer.new()
		slot_vbox.add_theme_constant_override("separation", 4)
		slot_card.add_child(slot_vbox)

		# Top row: slot index badge (1..5)
		var badge_row := HBoxContainer.new()
		slot_vbox.add_child(badge_row)
		badge_row.add_spacer(false)

		var badge := Label.new()
		badge.text = "%d" % (i + 1)
		badge.add_theme_font_size_override("font_size", 12)
		badge.add_theme_color_override("font_color", Color("94a3b8"))
		badge_row.add_child(badge)

		# Character/item image center
		var img_center := CenterContainer.new()
		img_center.custom_minimum_size = Vector2(0, 80)
		slot_vbox.add_child(img_center)

		var img := TextureRect.new()
		img.custom_minimum_size = Vector2(74, 76)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img_center.add_child(img)

		var plus_lbl := Label.new()
		plus_lbl.text = "+"
		plus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus_lbl.add_theme_font_size_override("font_size", 28)
		plus_lbl.add_theme_color_override("font_color", Color("24435e"))
		img_center.add_child(plus_lbl)

		# Status label
		var status_lbl := Label.new()
		status_lbl.text = "Пусто"
		status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_lbl.add_theme_font_size_override("font_size", 13)
		status_lbl.add_theme_color_override("font_color", Color("64748b"))
		slot_vbox.add_child(status_lbl)

		# Bottom progress bar & percentage
		var prog_row := HBoxContainer.new()
		prog_row.add_theme_constant_override("separation", 6)
		slot_vbox.add_child(prog_row)

		var progress := ProgressBar.new()
		progress.custom_minimum_size = Vector2(0, 10)
		progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		progress.show_percentage = false
		var prog_fill := StyleBoxFlat.new()
		prog_fill.bg_color = Color("22c55e")
		prog_fill.set_corner_radius_all(4)
		progress.add_theme_stylebox_override("fill", prog_fill)
		var prog_bg := StyleBoxFlat.new()
		prog_bg.bg_color = Color("0f2334")
		prog_bg.set_corner_radius_all(4)
		progress.add_theme_stylebox_override("background", prog_bg)
		prog_row.add_child(progress)

		var percent_lbl := Label.new()
		percent_lbl.text = "0%"
		percent_lbl.add_theme_font_size_override("font_size", 11)
		percent_lbl.add_theme_color_override("font_color", Color("94a3b8"))
		prog_row.add_child(percent_lbl)

		# Transparent button overlay for canceling orders
		var btn := Button.new()
		btn.flat = true
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot_card.add_child(btn)
		btn.pressed.connect(func(): cancel_job(index))

		slots.append({
			"card": slot_card,
			"button": btn,
			"image": img,
			"plus": plus_lbl,
			"name": status_lbl,
			"progress": progress,
			"prog_row": prog_row,
			"percent": percent_lbl,
			"normal": normal_style,
			"active": active_style,
			"empty": empty_style
		})

	# --- BOTTOM SECTION: AVAILABLE UNITS / CATALOG ---
	var cat_section := VBoxContainer.new()
	cat_section.add_theme_constant_override("separation", 8)
	root_vbox.add_child(cat_section)

	var cat_head := VBoxContainer.new()
	cat_section.add_child(cat_head)

	cat_title = Label.new()
	cat_title.text = "⚔  Доступные юниты"
	cat_title.add_theme_font_size_override("font_size", 18)
	cat_title.add_theme_color_override("font_color", Color("f1f5f9"))
	cat_head.add_child(cat_title)


	stock = Label.new()
	stock.text = ""
	stock.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	stock.add_theme_font_size_override("font_size", 13)
	stock.add_theme_color_override("font_color", Color("94a3b8"))
	cat_head.add_child(stock)

	catalog = GridContainer.new();catalog.columns=3
	catalog.add_theme_constant_override("separation", 12)
	cat_section.add_child(catalog)

	message = Label.new()
	message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", 14)
	message.add_theme_color_override("font_color", Color("fca5a5"))
	root_vbox.add_child(message)

	hide()

func close() -> void:
	hide()
	veil.hide()

func open(b: Building) -> void:
	if not is_instance_valid(b) or b.faction != "player" or not b.is_constructed:
		return
	building = b
	crafting = (b.building_type == BuildingConfigs.BuildingType.WORKSHOP)
	title.text = "⚒️  Очередь создания предметов" if crafting else "🏰  Очередь найма"
	cat_title.text = "📦  Доступные предметы" if crafting else "⚔  Доступные юниты"

	for child in catalog.get_children():
		catalog.remove_child(child)
		child.queue_free()

	cards.clear()
	message.text = ""

	var options: Array = EquipmentConfigs.ITEMS.keys() if crafting else []
	if not crafting:
		for type in UnitConfigs.UnitType.values():
			if not options.has(type) and game.production_system.permitted(b, type):
				options.append(type)

	for option in options:
		var value = option
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 128)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color("0a1b2b")
		card_style.border_color = Color("1e3d5b")
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(12)
		card_style.set_content_margin_all(10)
		card.add_theme_stylebox_override("panel", card_style)
		catalog.add_child(card)

		var card_hbox := HBoxContainer.new()
		card_hbox.add_theme_constant_override("separation", 10)
		card.add_child(card_hbox)

		# Left: Unit / Item portrait
		var pic := TextureRect.new()
		pic.texture = icon(option)
		pic.custom_minimum_size = Vector2(72, 80)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card_hbox.add_child(pic)

		# Middle: Info (Name, Role, Costs)
		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.add_theme_constant_override("separation", 2)
		card_hbox.add_child(info_vbox)

		var name_lbl := Label.new()
		name_lbl.text = display_name(option)
		name_lbl.add_theme_font_size_override("font_size", 17)
		name_lbl.add_theme_color_override("font_color", Color("f8fafc"))
		info_vbox.add_child(name_lbl)

		var role_lbl := Label.new()
		role_lbl.text = role_text(option)
		role_lbl.add_theme_font_size_override("font_size", 12)
		role_lbl.add_theme_color_override("font_color", Color("94a3b8"))
		info_vbox.add_child(role_lbl)

		var cost: Dictionary = EquipmentConfigs.ITEMS[option].cost.duplicate() if crafting else UnitConfigs.get_config(option).get("cost", {}).duplicate()
		if not crafting:
			for key in EquipmentConfigs.required(option):
				cost[key] = cost.get(key, 0) + EquipmentConfigs.required(option)[key]

		var cost_lbl := Label.new()
		cost_lbl.text = cost_row_text(cost)
		cost_lbl.add_theme_font_size_override("font_size", 13)
		cost_lbl.add_theme_color_override("font_color", Color("e2e8f0"))
		info_vbox.add_child(cost_lbl)

		var owned := Label.new()
		owned.add_theme_font_size_override("font_size", 11)
		owned.add_theme_color_override("font_color", Color("64748b"))
		info_vbox.add_child(owned)

		# Right: Big cyan recruitment "+" button
		var add := Button.new()
		add.text = "+\nНанять" if not crafting else "+\nСоздать"
		add.custom_minimum_size = Vector2(62, 66)
		add.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add.add_theme_font_size_override("font_size", 12)

		var btn_normal := StyleBoxFlat.new()
		btn_normal.bg_color = Color("08293d")
		btn_normal.border_color = Color("38bdf8")
		btn_normal.set_border_width_all(2)
		btn_normal.set_corner_radius_all(10)
		add.add_theme_stylebox_override("normal", btn_normal)

		var btn_hover := StyleBoxFlat.new()
		btn_hover.bg_color = Color("113d5c")
		btn_hover.border_color = Color("7dd3fc")
		btn_hover.set_border_width_all(2)
		btn_hover.set_corner_radius_all(10)
		add.add_theme_stylebox_override("hover", btn_hover)

		var btn_disabled := StyleBoxFlat.new()
		btn_disabled.bg_color = Color("081622")
		btn_disabled.border_color = Color("1c3345")
		btn_disabled.set_border_width_all(1)
		btn_disabled.set_corner_radius_all(10)
		add.add_theme_stylebox_override("disabled", btn_disabled)

		add.add_theme_color_override("font_color", Color("38bdf8"))
		add.add_theme_color_override("font_disabled_color", Color("475569"))
		add.pressed.connect(func(): enqueue(value))
		card_hbox.add_child(add)

		cards.append({"option": option, "cost": cost, "owned": owned, "button": add, "card": card})

	show()
	veil.show()
	layout_for(DeviceLayout.safe_rect(get_viewport()))
	refresh()

func role_text(option: Variant) -> String:
	if option is String:
		return "Оружие и снаряжение"
	match option:
		UnitConfigs.UnitType.WORKER, UnitConfigs.UnitType.GOBLIN_WORKER:
			return "⛏  Сбор ресурсов"
		UnitConfigs.UnitType.ARCHER, UnitConfigs.UnitType.GOBLIN_ARCHER:
			return "🎯  Дальний бой"
		UnitConfigs.UnitType.WARRIOR, UnitConfigs.UnitType.GOBLIN_WARRIOR, UnitConfigs.UnitType.GOBLIN_SPEARMAN:
			return "🛡  Ближний бой"
		UnitConfigs.UnitType.SPIDER_RIDER:
			return "🕷  Кавалерия"
		UnitConfigs.UnitType.TROLL:
			return "💥  Тяжёлый штурм"
		UnitConfigs.UnitType.SCOUT:
			return "👁  Быстрая разведка"
		UnitConfigs.UnitType.BOAT:
			return "⛵  Лодка"
		UnitConfigs.UnitType.GALLEY:
			return "🚢  Боевой флот"
		_:
			return "Боевой юнит"

func cost_row_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	if cost.get("wood", 0) > 0:
		parts.append("🪵 %d" % cost["wood"])
	if cost.get("stone", 0) > 0:
		parts.append("🪨 %d" % cost["stone"])
	if cost.get("food", 0) > 0:
		parts.append("🍞 %d" % cost["food"])
	if cost.get("ore", 0) > 0:
		parts.append("✨ %d" % cost["ore"])
	for k in cost:
		if k not in ["wood", "stone", "food", "ore", "water"]:
			parts.append("%s %d" % [EquipmentConfigs.ITEMS.get(k, {}).get("name", k), cost[k]])
	return "  ".join(parts)

func icon(option: Variant) -> Texture2D:
	if not icons.has(option):
		icons[option] = _make_icon(option)
	return icons[option]

func _make_icon(option: Variant) -> Texture2D:
	if option is String:
		var i: int = EquipmentConfigs.ITEMS.keys().find(option)
		var regions: Array[Rect2] = [
			Rect2(142, 538, 125, 137),
			Rect2(625, 535, 121, 137),
			Rect2(1093, 531, 119, 144),
			Rect2(140, 707, 125, 145),
			Rect2(625, 718, 124, 133),
			Rect2(1092, 711, 124, 143)
		]
		return hud.skin.atlas("equipment-reference.png", regions[i])

	if option in [UnitConfigs.UnitType.WORKER, UnitConfigs.UnitType.GOBLIN_WORKER]:
		if ResourceLoader.exists("res://assets/ui/unit_worker_transparent.png"):
			return load("res://assets/ui/unit_worker_transparent.png")
	elif option in [UnitConfigs.UnitType.ARCHER, UnitConfigs.UnitType.SCOUT, UnitConfigs.UnitType.GOBLIN_ARCHER]:
		if ResourceLoader.exists("res://assets/ui/unit_archer_transparent.png"):
			return load("res://assets/ui/unit_archer_transparent.png")
	elif option in [UnitConfigs.UnitType.WARRIOR, UnitConfigs.UnitType.GOBLIN_WARRIOR, UnitConfigs.UnitType.GOBLIN_SPEARMAN, UnitConfigs.UnitType.SPIDER_RIDER, UnitConfigs.UnitType.TROLL]:
		if ResourceLoader.exists("res://assets/ui/unit_knight_transparent.png"):
			return load("res://assets/ui/unit_knight_transparent.png")
	elif UnitConfigs.is_vessel(option):
		return hud.skin.atlas("build-reference.png", Rect2(594, 1270, 169, 135))

	return hud.skin.atlas("recruit-reference.png", Rect2(160, 298, 158, 167))

func display_name(option: Variant) -> String:
	return EquipmentConfigs.ITEMS[option].name if option is String else FrontierHUDStyle.NAMES[option]

func enqueue(option: Variant) -> void:
	message.text = game.workshop_system.enqueue(building, option) if crafting else game.production_system.enqueue(building, option)
	refresh()

func cancel_job(index: int) -> void:
	if crafting:
		game.workshop_system.cancel(building, index)
	elif index < building.training_queue.size():
		game.production_system.cancel(building, index)
	message.text = "Заказ отменён. Ресурсы возвращены."
	refresh()

func refresh() -> void:
	if not is_instance_valid(building) or not building.is_alive:
		close()
		return

	var jobs: Array = building.crafting_queue if crafting else building.training_queue
	var inventory: Dictionary = FactionEconomy.resources(building.faction)

	if crafting:
		var parts: Array[String] = []
		for key in EquipmentConfigs.ITEMS:
			parts.append("%s: %d" % [EquipmentConfigs.ITEMS[key].name, inventory.get(key, 0)])
		stock.text = "В запасе · " + "  ".join(parts)
	else:
		stock.text = "Население: %d / %d" % [game.production_system.population(building.faction), game.production_system.capacity(building.faction)]

	for i in range(slots.size()):
		var slot: Dictionary = slots[i]
		slot.button.disabled = (i >= jobs.size())
		slot.prog_row.visible = (i == 0 and not jobs.is_empty())

		if i >= jobs.size():
			slot.card.add_theme_stylebox_override("panel", slot.empty)
			slot.image.texture = null
			slot.image.visible = false
			slot.plus.visible = true
			slot.name.text = "Пусто"
			slot.name.add_theme_color_override("font_color", Color("64748b"))
			continue

		var job: Dictionary = jobs[i]
		var option = job.item if crafting else job.type
		slot.image.texture = icon(option)
		slot.image.visible = true
		slot.plus.visible = false

		if i == 0:
			slot.card.add_theme_stylebox_override("panel", slot.active)
			slot.name.text = "Создание"
			slot.name.add_theme_color_override("font_color", Color("38bdf8"))
			var pct: int = int(clampf(100.0 * job.progress / maxf(0.01, job.duration), 0.0, 100.0))
			slot.progress.value = pct
			slot.percent.text = "%d%%" % pct
		else:
			slot.card.add_theme_stylebox_override("panel", slot.normal)
			slot.name.text = "В очереди"
			slot.name.add_theme_color_override("font_color", Color("94a3b8"))

	for card in cards:
		if crafting:
			card.owned.text = "На складе: %d" % inventory.get(card.option, 0)
		else:
			var req: Dictionary = EquipmentConfigs.required(card.option)
			card.owned.text = ("Требуется: " + EquipmentConfigs.cost_text(req)) if not req.is_empty() else "Без оружия"

		var can_afford: bool = FactionEconomy.can_afford(building.faction, card.cost)
		var pop_ok: bool = crafting or UnitConfigs.is_vessel(card.option) or (game.production_system.population(building.faction) < game.production_system.capacity(building.faction))
		var queue_ok: bool = (jobs.size() < slots.size())

		card.button.disabled = not (can_afford and pop_ok and queue_ok)
		if not queue_ok:
			card.button.tooltip_text = "Очередь заполнена (%d мест)" % slots.size()
		elif not pop_ok:
			card.button.tooltip_text = "Лимит населения! Постройте хижину."
		elif not can_afford:
			card.button.tooltip_text = "Недостаточно ресурсов: " + EquipmentConfigs.cost_text(card.cost)
		else:
			card.button.tooltip_text = "Нажмите для найма"

	if crafting and not jobs.is_empty() and jobs[0].progress >= jobs[0].duration:
		message.text = "Предмет готов. Склад заполнен — постройте ещё один."
	elif message.text.begins_with("Предмет готов."):
		message.text = ""

func _process(delta: float) -> void:
	if not visible:
		return
	timer += delta
	if timer >= 0.1:
		timer = 0.0
		refresh()

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func layout_for(safe: Rect2) -> void:
	var extent:=Vector2(minf(1220,safe.size.x-8),minf(750,safe.size.y-8))
	DeviceLayout.place(self,Rect2(safe.get_center()-extent*.5,extent))
	var width: float=extent.x-48
	catalog.columns=clampi(int(width/350),1,3)
	title.add_theme_font_size_override("font_size",22 if width<700 else 32)
	title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	for card in catalog.get_children():card.custom_minimum_size=Vector2(maxf(0,(width-20)/catalog.columns),142)
