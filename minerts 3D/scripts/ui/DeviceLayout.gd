class_name DeviceLayout
extends RefCounted

static func is_mobile() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios")

static func configure_window(window: Window) -> void:
	if not is_mobile():return
	var density: float=DisplayServer.screen_get_scale() if OS.has_feature("ios") else clampf(DisplayServer.screen_get_dpi()/160.0,1.0,4.0)
	window.content_scale_size=Vector2i(Vector2(window.size)/maxf(density,1.0))
	window.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS

static func safe_rect(viewport: Viewport) -> Rect2:
	var logical: Rect2=viewport.get_visible_rect()
	if not is_mobile():return logical.grow(-8)
	var physical:=DisplayServer.get_display_safe_area()
	var window_size: Vector2=Vector2(viewport.get_window().size)
	if physical.size.x<=0 or physical.size.y<=0 or window_size.x<=0:return logical.grow(-8)
	var ratio: Vector2=logical.size/window_size
	return Rect2(Vector2(physical.position)*ratio,Vector2(physical.size)*ratio).intersection(logical).grow(-8)

static func place(control: Control,rect: Rect2) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.position=rect.position;control.size=rect.size
