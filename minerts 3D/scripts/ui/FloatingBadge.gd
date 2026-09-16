class_name FloatingBadge
extends Control

signal minus_clicked()
signal plus_clicked()
signal upgrade_clicked()
signal eject_clicked()
signal delete_clicked()

@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/VBox/Header/TitleLabel
@onready var count_label: Label = $Panel/VBox/HBox/CountLabel
@onready var minus_btn: Button = $Panel/VBox/HBox/MinusBtn
@onready var plus_btn: Button = $Panel/VBox/HBox/PlusBtn
@onready var upgrade_btn: Button = $Panel/VBox/UpgradeBtn
@onready var eject_btn: Button = $Panel/VBox/EjectBtn
var delete_btn: Button = null

var target_node: Node3D = null
var target_pos: Vector3 = Vector3.ZERO
var camera: Camera3D = null
var is_mine: bool = false

func _ready() -> void:
	if minus_btn:
		minus_btn.pressed.connect(func(): minus_clicked.emit())
	if plus_btn:
		plus_btn.pressed.connect(func(): plus_clicked.emit())
	if upgrade_btn:
		upgrade_btn.pressed.connect(func(): upgrade_clicked.emit())
	if eject_btn:
		eject_btn.pressed.connect(func(): eject_clicked.emit())
	
	delete_btn = Button.new()
	delete_btn.text = "🗑 Удалить зону"
	delete_btn.custom_minimum_size = Vector2(0, 24)
	delete_btn.pressed.connect(func(): delete_clicked.emit())
	var vbox: VBoxContainer = panel.get_node_or_null("VBox") as VBoxContainer
	if vbox:
		vbox.add_child(delete_btn)
	delete_btn.visible = false

func show_for_lumber_zone(zone_badge: Node3D, current_workers: int, max_w: int, cam: Camera3D) -> void:
	camera = cam
	target_node = zone_badge
	is_mine = false
	visible = true

	if title_label:
		title_label.text = "🌲 Lumber Zone"
	if upgrade_btn:
		upgrade_btn.visible = false
	if eject_btn:
		eject_btn.visible = false
	if delete_btn:
		delete_btn.visible = true

	update_count(current_workers, max_w)
	_update_screen_position()

func show_for_mine(mine: Building, current_miners: int, max_m: int, cam: Camera3D) -> void:
	camera = cam
	target_node = mine
	is_mine = true
	visible = true

	if title_label:
		title_label.text = "⛏️ Deep Mine" if mine.level >= 2 else "⛏️ Stone Mine"

	if upgrade_btn:
		if mine.level < 2:
			upgrade_btn.visible = true
			upgrade_btn.text = "Upgrade to Deep Mine (40 St, 20 W)"
		else:
			upgrade_btn.visible = false

	if eject_btn:
		eject_btn.visible = true
		eject_btn.text = "Eject All"
	if delete_btn:
		delete_btn.visible = false

	update_count(current_miners, max_m)
	_update_screen_position()

func update_count(current: int, maximum: int) -> void:
	if count_label:
		count_label.text = "%d / %d" % [current, maximum]
	if minus_btn:
		minus_btn.disabled = (current <= 0)
	if plus_btn:
		plus_btn.disabled = (current >= maximum)

func hide_badge() -> void:
	visible = false
	target_node = null
	if delete_btn:
		delete_btn.visible = false

func _process(_delta: float) -> void:
	if visible and is_instance_valid(target_node) and is_instance_valid(camera):
		_update_screen_position()
	elif visible and not is_instance_valid(target_node):
		hide_badge()

func _update_screen_position() -> void:
	if not is_instance_valid(camera) or not is_instance_valid(target_node):
		return
	var w_pos: Vector3 = target_node.global_position + Vector3(0, 2.8, 0)
	if camera.is_position_behind(w_pos):
		visible = false
		return
	visible = true
	var screen_p: Vector2 = camera.unproject_position(w_pos)
	# Center badge on screen pos
	position = screen_p - (size * 0.5)
