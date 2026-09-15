class_name SelectionBox
extends Control

var is_visible_box: bool = false
var start_point: Vector2 = Vector2.ZERO
var current_point: Vector2 = Vector2.ZERO

func start_box(start_pos: Vector2) -> void:
	start_point = start_pos
	current_point = start_pos
	is_visible_box = true
	queue_redraw()

func update_box(pos: Vector2) -> void:
	current_point = pos
	queue_redraw()

func stop_box() -> void:
	is_visible_box = false
	queue_redraw()

func _draw() -> void:
	if not is_visible_box:
		return

	var rect: Rect2 = Rect2(
		minf(start_point.x, current_point.x),
		minf(start_point.y, current_point.y),
		absf(current_point.x - start_point.x),
		absf(current_point.y - start_point.y)
	)

	if rect.size.x > 2.0 and rect.size.y > 2.0:
		# Filled interior
		draw_rect(rect, Color(0.2, 0.65, 1.0, 0.22), true)
		# Crisp border
		draw_rect(rect, Color(0.3, 0.8, 1.0, 0.9), false, 1.5)
