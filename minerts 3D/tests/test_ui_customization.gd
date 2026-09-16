extends Node

var game: Main
var failures: int = 0

func check(ok: bool, msg: String) -> void:
	if ok:
		print("PASS: ", msg)
	else:
		failures += 1
		push_error("FAIL: " + msg)

func _ready() -> void:
	SoundManager.is_muted = true
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var ipad_size := Vector2i(1194, 834)
	get_window().content_scale_size = ipad_size
	DisplayServer.window_set_size(ipad_size)

	# --- PART 1: UILayoutManager verification ---
	print("--- Testing UILayoutManager ---")
	check(UILayoutManager != null, "UILayoutManager autoload is loaded")
	check(UILayoutManager.get_preset_names().has("По умолчанию"), "Builtin preset 'По умолчанию' exists")
	check(UILayoutManager.get_preset_names().has("Для левши"), "Builtin preset 'Для левши' exists")
	check(UILayoutManager.get_preset_names().has("Компактный"), "Builtin preset 'Компактный' exists")

	# Test custom preset saving & loading
	UILayoutManager.set_element_offset("minimap", Vector2(100, -50))
	UILayoutManager.set_element_scale("minimap", 1.25)
	var saved := UILayoutManager.save_preset("Мой планшет")
	check(saved, "save_preset('Мой планшет') succeeded")
	check(UILayoutManager.get_preset_names().has("Мой планшет"), "'Мой планшет' in preset names")
	check(UILayoutManager.get_element_scale("minimap") == 1.25, "Custom minimap scale is 1.25")

	# Switch to another preset and back
	UILayoutManager.apply_preset("Для левши")
	check(UILayoutManager.active_preset_name == "Для левши", "Applied 'Для левши'")
	UILayoutManager.apply_preset("Мой планшет")
	check(UILayoutManager.active_preset_name == "Мой планшет", "Re-applied 'Мой планшет'")
	check(UILayoutManager.get_element_scale("minimap") == 1.25, "Restored scale 1.25")

	# Delete test preset
	UILayoutManager.delete_user_preset("Мой планшет")
	check(not UILayoutManager.user_presets.has("Мой планшет"), "Deleted 'Мой планшет'")

	# Reset to default
	UILayoutManager.reset_to_default()
	check(UILayoutManager.active_preset_name == "По умолчанию", "Reset to default preset")

	# --- PART 2: UI Editor Overlay Screenshot ---
	print("--- Capturing UI Editor Overlay on iPad ---")
	var editor_script = load("res://scripts/ui/UIEditorOverlay.gd")
	var editor: Control = editor_script.new()
	add_child(editor)
	for i in range(15):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://art/test-results/mobile-network/ipad-ui-editor.png")
	editor.queue_free()
	for i in range(5):
		await get_tree().process_frame

	# --- PART 3: In-Game HUD & Command Lock Testing ---
	print("--- Testing In-Game HUD and Touch Command Lock ---")
	game = load("res://scenes/Main.tscn").instantiate()
	add_child(game)
	game.goblin_ai.set_process(false)
	game.time_of_day_system.set_process(false)
	game.time_of_day_system.time_of_day = 0.35
	game.time_of_day_system._update_lighting()

	for i in range(25):
		await get_tree().process_frame

	game.responsive_hud.layout()
	check(is_instance_valid(game.responsive_hud.command_lock_btn), "Command Lock button is instantiated in ResponsiveHUD")

	# Select worker
	var worker: Unit = game.all_units[0]
	game.selection_system.select_single_unit(worker, false)
	for i in range(5):
		await get_tree().process_frame

	# Initial state: Command Lock is OFF
	check(not game.touch_controls.command_lock_active, "Command Lock starts OFF (Safe Selection Mode)")
	check(game.responsive_hud.command_lock_btn.text.contains("ВЫКЛ"), "Button shows 'ВЫКЛ'")

	# Test safe tap: clicking empty terrain while lock is OFF must NOT order unit to move
	var worker_initial_pos := worker.position
	var world_pt := Vector2(500, 300)
	game.touch_controls._tap(world_pt)
	for i in range(5):
		await get_tree().process_frame
	check(worker.path.is_empty() and worker.state == UnitConfigs.UnitState.IDLE, "Safe tap did not issue attack/move order in safe mode")

	# Capture HUD with Command Lock OFF and worker selected
	game.selection_system.select_single_unit(worker, false)
	for i in range(5):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://art/test-results/mobile-network/ipad-command-lock-off.png")

	# Toggle Command Lock ON
	var locked := game.touch_controls.toggle_command_lock()
	check(locked, "toggle_command_lock turned lock ON")
	check(game.touch_controls.command_lock_active, "command_lock_active is true")
	for i in range(5):
		await get_tree().process_frame
	check(game.responsive_hud.command_lock_btn.text.contains("ВКЛ"), "Button shows 'ВКЛ'")

	# Capture HUD with Command Lock ON (glowing locked state) and worker selected
	game.selection_system.select_single_unit(worker, false)
	for i in range(5):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://art/test-results/mobile-network/ipad-command-lock-on.png")

	# Test command tap: clicking terrain while lock is ON orders unit!
	game.selection_system.select_single_unit(worker, false)
	game.touch_controls._tap(Vector2(400, 400))
	for i in range(5):
		await get_tree().process_frame
	check(not worker.path.is_empty() or worker.state == UnitConfigs.UnitState.MOVING, "Command tap successfully issued move order to worker")

	# Switch to 'Для левши' preset and capture
	UILayoutManager.apply_preset("Для левши")
	game.selection_system.select_single_unit(worker, false)
	for i in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://art/test-results/mobile-network/ipad-preset-lefty.png")

	print("=== UI CUSTOMIZATION & COMMAND LOCK TEST FINISHED with %d failures ===" % failures)
	get_tree().quit(failures)
