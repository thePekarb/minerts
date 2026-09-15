class_name HUD
extends Control

signal build_requested(building_type: BuildingConfigs.BuildingType)
signal lumber_zone_tool_requested()
signal cancel_training_requested
signal unload_requested
signal train_unit_requested(unit_type: UnitConfigs.UnitType)
signal gate_toggle_requested()
signal mine_minus_requested()
signal mine_plus_requested()
signal mine_upgrade_requested()
signal mine_eject_requested()
signal exit_cave_requested()

var skin: FrontierHUDStyle
var exit_cave_btn: Button = null

# Top Bar Nodes
@onready var wood_label: Label = $TopBar/HBox/WoodLabel
@onready var stone_label: Label = $TopBar/HBox/StoneLabel
@onready var food_label: Label = $TopBar/HBox/FoodLabel
@onready var ore_label: Label = $TopBar/HBox/OreLabel
@onready var pop_label: Label = $TopBar/HBox/PopLabel
@onready var time_label: Label = $TopBar/HBox/TimeLabel
@onready var day_label: Label = $TopBar/HBox/DayLabel

# Banner
@onready var banner: PanelContainer = $Banner
@onready var banner_label: Label = $Banner/BannerLabel

# Build Dock
@onready var build_dock: PanelContainer = $BuildDock
@onready var build_grid: GridContainer = $BuildDock/VBox/GridContainer
@onready var axe_tool_btn: Button = $BuildDock/VBox/AxeToolBtn

# Selection Inspector
@onready var inspector: PanelContainer = $Inspector
@onready var inspector_title: Label = $Inspector/VBox/TitleLabel
@onready var inspector_subtitle: Label = $Inspector/VBox/SubtitleLabel
@onready var inspector_health_bar: ProgressBar = $Inspector/VBox/HealthBar
@onready var inspector_action_box: HFlowContainer = $Inspector/VBox/ActionBox
@onready var gate_btn: Button = $Inspector/VBox/ActionBox/GateBtn
@onready var mine_stepper: HBoxContainer = $Inspector/VBox/ActionBox/MineStepper
@onready var mine_count_lbl: Label = $Inspector/VBox/ActionBox/MineStepper/MineCountLbl
@onready var mine_minus_btn: Button = $Inspector/VBox/ActionBox/MineStepper/MineMinusBtn
@onready var mine_plus_btn: Button = $Inspector/VBox/ActionBox/MineStepper/MinePlusBtn
@onready var mine_upgrade_btn: Button = $Inspector/VBox/ActionBox/MineUpgradeBtn
@onready var mine_eject_btn: Button = $Inspector/VBox/ActionBox/MineEjectBtn
@onready var train_worker_btn: Button = $Inspector/VBox/ActionBox/TrainWorkerBtn
@onready var train_warrior_btn: Button = $Inspector/VBox/ActionBox/TrainWarriorBtn
@onready var train_archer_btn: Button = $Inspector/VBox/ActionBox/TrainArcherBtn

# Minimap container
@onready var minimap: Minimap = $Minimap

# Selection marquee box
@onready var selection_box: SelectionBox = $SelectionBox

# Floating badge instance
@onready var floating_badge: FloatingBadge = $FloatingBadge

var water_label: Label
var raid_status_label: Label
var inspected_unit: Unit
var boat_btn: Button
var galley_btn: Button
var cancel_queue_btn: Button
var unload_btn: Button
var queue_label: Label
var inspected_building: Building
var inspector_timer: float = 0.0
var banner_timer: float = 0.0

func _ready() -> void:
	_setup_production_controls()
	EventBus.resource_changed.connect(_on_resource_changed)
	EventBus.population_changed.connect(_on_population_changed)
	EventBus.selection_changed.connect(_on_selection_changed)
	EventBus.raid_warning.connect(show_banner)
	EventBus.raid_spawned.connect(func(wave, count): show_banner("Wave %d: %d raiders incoming!" % [wave, count]))

	water_label = Label.new()
	water_label.text = "💧 0"
	$TopBar/HBox.add_child(water_label)
	_setup_raid_status()
	_setup_theme()
	_setup_build_buttons()
	_setup_actions()
	skin=FrontierHUDStyle.new();skin.setup(self)
	_update_all_resources()

	if banner:
		banner.visible = false
	if inspector:
		inspector.visible = false

func _setup_build_buttons() -> void:
	if axe_tool_btn:
		axe_tool_btn.pressed.connect(func():
			SoundManager.play_click()
			lumber_zone_tool_requested.emit()
		)

	# Build buttons for all 8 buildings
	var building_types: Array = [
		BuildingConfigs.BuildingType.CAMPFIRE,
		BuildingConfigs.BuildingType.HUT,
		BuildingConfigs.BuildingType.STORAGE,
		BuildingConfigs.BuildingType.WALL,
		BuildingConfigs.BuildingType.GATE,
		BuildingConfigs.BuildingType.TOWER,
		BuildingConfigs.BuildingType.BARRACKS,
		BuildingConfigs.BuildingType.WORKSHOP,
		BuildingConfigs.BuildingType.FARM,
		BuildingConfigs.BuildingType.WELL,
		BuildingConfigs.BuildingType.MINE,
		BuildingConfigs.BuildingType.PORT
	]

	if build_grid:
		for child in build_grid.get_children():
			child.queue_free()

		for type in building_types:
			var cfg: Dictionary = BuildingConfigs.get_config(type)
			var btn: Button = Button.new()
			btn.custom_minimum_size = Vector2(64, 48)
			btn.text = "%s\n%s" % [cfg.get("icon", "🏛️"), cfg.get("name", "")]
			btn.tooltip_text = "Cost: %s" % [str(cfg.get("cost", {}))]
			btn.pressed.connect(func():
				SoundManager.play_click()
				build_requested.emit(type)
			)
			build_grid.add_child(btn)

func _setup_actions() -> void:
	if gate_btn:
		gate_btn.pressed.connect(func():
			SoundManager.play_click()
			gate_toggle_requested.emit()
		)
	if mine_minus_btn:
		mine_minus_btn.pressed.connect(func():
			SoundManager.play_click()
			mine_minus_requested.emit()
		)
	if mine_plus_btn:
		mine_plus_btn.pressed.connect(func():
			SoundManager.play_click()
			mine_plus_requested.emit()
		)
	if mine_upgrade_btn:
		mine_upgrade_btn.pressed.connect(func():
			SoundManager.play_click()
			mine_upgrade_requested.emit()
		)
	if mine_eject_btn:
		mine_eject_btn.pressed.connect(func():
			SoundManager.play_click()
			mine_eject_requested.emit()
		)
	if train_worker_btn:
		train_worker_btn.pressed.connect(func():
			SoundManager.play_click()
			train_unit_requested.emit(UnitConfigs.UnitType.WORKER)
		)
	if train_warrior_btn:
		train_warrior_btn.pressed.connect(func():
			SoundManager.play_click()
			train_unit_requested.emit(UnitConfigs.UnitType.WARRIOR)
		)
	if train_archer_btn:
		train_archer_btn.pressed.connect(func():
			SoundManager.play_click()
			train_unit_requested.emit(UnitConfigs.UnitType.ARCHER)
		)

	exit_cave_btn = Button.new()
	exit_cave_btn.text = "▲ На поверхность [R]"
	exit_cave_btn.visible = false
	if inspector and inspector.has_node("VBox/ActionBox"):
		inspector.get_node("VBox/ActionBox").add_child(exit_cave_btn)
	exit_cave_btn.pressed.connect(func():
		SoundManager.play_click()
		exit_cave_requested.emit()
	)

func _update_all_resources() -> void:
	_on_resource_changed("wood", EconomyManager.resources["wood"])
	_on_resource_changed("stone", EconomyManager.resources["stone"])
	_on_resource_changed("food", EconomyManager.resources["food"])
	_on_resource_changed("ore", EconomyManager.resources["ore"])
	_on_resource_changed("water", EconomyManager.resources.get("water", 0))
	_on_population_changed(EconomyManager.current_population, EconomyManager.max_population)

func _on_resource_changed(type: String, amount: int) -> void:
	match type:
		"wood": if wood_label: wood_label.text = "%d" % amount
		"stone": if stone_label: stone_label.text = "%d" % amount
		"food": if food_label: food_label.text = "%d" % amount
		"water":
			if water_label:water_label.text = "💧 %d" % amount;water_label.visible=amount>0
		"ore":
			if ore_label:ore_label.text = "✨ %d" % amount;ore_label.visible=amount>0

func _on_population_changed(cur: int, maximum: int) -> void:
	if pop_label:
		pop_label.text = "%d / %d" % [cur, maximum]

func update_time_display(day: int, time_str: String) -> void:
	if day_label:
		day_label.text = "День %d" % day
	if time_label:
		time_label.text = "%s" % time_str

func show_banner(msg: String) -> void:
	if banner and banner_label:
		banner_label.text = msg
		banner.visible = true
		banner_timer = 5.0

func _process(delta: float) -> void:
	if skin:skin.update_inspector()
	inspector_timer += delta
	if inspector_timer >= 0.15 and inspector.visible:
		inspector_timer = 0.0
		if is_instance_valid(inspected_unit) and inspected_unit.is_alive:
			if UnitConfigs.is_vessel(inspected_unit.unit_type):
				queue_label.text="Пассажиры: %d / %d · ПКМ по берегу: высадка · U: выгрузить" % [inspected_unit.passengers.size(),inspected_unit.config.capacity]
			inspector_health_bar.value = inspected_unit.health
			inspector_subtitle.text = "HP: %d / %d | Speed: %.1f | Dmg: %d | Armor: %d" % [inspected_unit.health, inspected_unit.max_health, inspected_unit.speed, inspected_unit.attack_damage, inspected_unit.armor]
		elif is_instance_valid(inspected_building) and inspected_building.is_alive:
			if inspected_building.faction=="player" and queue_label.visible:
				queue_label.text=get_parent().production_system.queue_text(inspected_building)
			inspector_health_bar.value = inspected_building.health
			inspector_subtitle.text = "HP: %d / %d | %s" % [inspected_building.health, inspected_building.max_health, "Constructed" if inspected_building.is_constructed else "Building %.0f%%" % inspected_building.construction_progress]
	if banner and banner.visible:
		banner_timer -= delta
		if banner_timer <= 0.0:
			banner.visible = false

func _on_selection_changed(units: Array[Unit], building: Building) -> void:
	inspected_unit = units[0] if units.size() == 1 else null
	inspected_building = building
	if not inspector:
		return

	if not units.is_empty():
		inspector.visible = true
		_hide_all_inspector_actions()
		var any_underground: bool = false
		for u in units:
			if is_instance_valid(u) and u.underground_unit:
				any_underground = true
				break
		if exit_cave_btn:
			exit_cave_btn.visible = any_underground

		if units.size() == 1:
			var u: Unit = units[0] as Unit
			if UnitConfigs.is_vessel(u.unit_type):unload_btn.visible=true;queue_label.visible=true
			inspector_title.text = "%s %s" % [u.config.get("icon", "👤"), u.config.get("name", "Unit")]
			inspector_subtitle.text = "HP: %d / %d | Speed: %.1f | Dmg: %d" % [int(u.health), int(u.max_health), u.speed, int(u.attack_damage)]
			if u.underground_unit:
				inspector_subtitle.text += " | ⛏️ В пещере"
			inspector_health_bar.visible = true
			inspector_health_bar.max_value = u.max_health
			inspector_health_bar.value = u.health
		else:
			inspector_title.text = "👥 Selected Group (%d)" % units.size()
			inspector_subtitle.text = "Command group ready" + (" (в пещере)" if any_underground else "")
			inspector_health_bar.visible = false
	elif is_instance_valid(building) and building.is_alive:
		inspector.visible = true
		_hide_all_inspector_actions()
		inspector_title.text = "%s %s (Lv %d)" % [building.config.get("icon", "🏛️"), building.config.get("name", "Building"), building.level]
		var status_str: String = "Constructed" if building.is_constructed else "Under Construction (%.0f%%)" % building.construction_progress
		inspector_subtitle.text = "HP: %d / %d | %s" % [int(building.health), int(building.max_health), status_str]
		inspector_health_bar.visible = true
		inspector_health_bar.max_value = building.max_health
		inspector_health_bar.value = building.health

		if building.faction!="player":
			inspector_title.text="Гоблины · "+building.config.name
			return
		if building.is_constructed and building.building_type in [BuildingConfigs.BuildingType.CAMPFIRE,BuildingConfigs.BuildingType.HUT,BuildingConfigs.BuildingType.BARRACKS,BuildingConfigs.BuildingType.WORKSHOP,BuildingConfigs.BuildingType.PORT]:
			queue_label.visible=true;cancel_queue_btn.visible=true
		if building.building_type==BuildingConfigs.BuildingType.PORT and building.is_constructed:
			boat_btn.visible=true;galley_btn.visible=true
		if building.is_gate and building.is_constructed:
			gate_btn.visible = true
			gate_btn.text = "🚪 Gate: Open [O]" if building.is_open else "🚪 Gate: Closed & Locked [O]"

		elif building.building_type == BuildingConfigs.BuildingType.MINE and building.is_constructed:
			mine_stepper.visible = true
			mine_count_lbl.text = "Miners: %d / %d" % [building.assigned_miners.size(), building.max_miners]
			mine_minus_btn.disabled = (building.assigned_miners.size() <= 0)
			mine_plus_btn.disabled = (building.assigned_miners.size() >= building.max_miners)

			mine_upgrade_btn.visible = (building.level < 2)
			mine_eject_btn.visible = true

		elif (building.building_type == BuildingConfigs.BuildingType.CAMPFIRE or building.building_type == BuildingConfigs.BuildingType.HUT) and building.is_constructed:
			train_worker_btn.visible = true

		elif (building.building_type == BuildingConfigs.BuildingType.WORKSHOP or building.building_type == BuildingConfigs.BuildingType.BARRACKS) and building.is_constructed:
			train_warrior_btn.visible = true
			train_archer_btn.visible = true
	else:
		inspector.visible = false

func _hide_all_inspector_actions() -> void:
	for control in [boat_btn,galley_btn,cancel_queue_btn,unload_btn,queue_label]:
		if control:control.visible=false
	gate_btn.visible = false
	mine_stepper.visible = false
	mine_upgrade_btn.visible = false
	mine_eject_btn.visible = false
	train_worker_btn.visible = false
	train_warrior_btn.visible = false
	train_archer_btn.visible = false
	if exit_cave_btn:
		exit_cave_btn.visible = false

func _setup_theme() -> void:
	var ui_theme: Theme = Theme.new()
	ui_theme.default_font_size = 16
	ui_theme.set_color("font_color", "Label", Color("e8e6db"))
	for state_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color("263c43") if state_name == "hover" else Color("17272f")
		if state_name == "pressed":
			style.bg_color = Color("36534e")
		style.border_color = Color("d9b879") if state_name in ["hover", "focus"] else Color("40535a")
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		ui_theme.set_stylebox(state_name, "Button", style)
	ui_theme.set_color("font_color", "Button", Color("e8e6db"))
	ui_theme.set_color("font_hover_color", "Button", Color("ffe0a2"))
	theme = ui_theme

func _setup_raid_status() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(16, 60)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.09, 0.13, 0.93)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	raid_status_label = Label.new()
	raid_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(raid_status_label)
	add_child(panel)

func update_raid_display(raid: RaidSystem, clock_system: TimeOfDaySystem) -> void:
	var alive: int = raid.remaining_enemies()
	if alive > 0:
		raid_status_label.text = "Волна %d · Врагов: %d" % [raid.current_wave, alive]
		raid_status_label.modulate = Color("ffc185")
	elif raid.has_spawned_night_wave:
		raid_status_label.text = "Волна %d отбита" % raid.current_wave
		raid_status_label.modulate = Color("8ed6aa")
	else:
		var seconds: int = int(ceil(maxf(0.0, RaidSystem.RAID_TIME - clock_system.time_of_day) * clock_system.day_duration_seconds))
		raid_status_label.text = "через %d:%02d" % [int(seconds / 60), seconds % 60]
		raid_status_label.modulate = Color("e8e6db")
	minimap.raid_origins = raid.active_altar_positions

func _setup_production_controls() -> void:
	var actions: Node = $Inspector/VBox/ActionBox
	boat_btn=Button.new();boat_btn.text="Лодка · 18 с · 45 дерева, 10 еды";actions.add_child(boat_btn)
	boat_btn.pressed.connect(func():train_unit_requested.emit(UnitConfigs.UnitType.BOAT))
	galley_btn=Button.new();galley_btn.text="Галера · 32 с · 110 дерева, 25 камня, 25 еды";actions.add_child(galley_btn)
	galley_btn.pressed.connect(func():train_unit_requested.emit(UnitConfigs.UnitType.GALLEY))
	cancel_queue_btn=Button.new();cancel_queue_btn.text="Отменить последнего в очереди";actions.add_child(cancel_queue_btn)
	cancel_queue_btn.pressed.connect(func():cancel_training_requested.emit())
	unload_btn=Button.new();unload_btn.text="Высадить пассажиров [U]";actions.add_child(unload_btn)
	unload_btn.pressed.connect(func():unload_requested.emit())
	queue_label=Label.new();queue_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;queue_label.custom_minimum_size=Vector2(400,45);$Inspector/VBox.add_child(queue_label)
	for control in [boat_btn,galley_btn,cancel_queue_btn,unload_btn,queue_label]:control.visible=false
