class_name UILayoutManagerAutoload
extends Node

signal layout_changed()

const PRESETS_FILE_PATH := "user://ui_layout_presets.json"

# Active layout settings for key HUD elements
# offset: Vector2 pixel offset from its standard position
# scale: float scale multiplier (0.60 to 1.50)
var current_layout: Dictionary = {}
var active_preset_name: String = "По умолчанию"

# Built-in presets
var builtin_presets: Dictionary = {
	"По умолчанию": {
		"top_bar": {"offset": Vector2.ZERO, "scale": 1.0},
		"inspector": {"offset": Vector2.ZERO, "scale": 1.0},
		"minimap": {"offset": Vector2.ZERO, "scale": 1.0},
		"build_dock": {"offset": Vector2.ZERO, "scale": 1.0},
		"raid": {"offset": Vector2.ZERO, "scale": 1.0},
		"command_lock": {"offset": Vector2.ZERO, "scale": 1.0}
	},
	"Для левши": {
		"top_bar": {"offset": Vector2.ZERO, "scale": 1.0},
		"inspector": {"offset": Vector2(0, 0), "scale": 1.0},
		"minimap": {"offset": Vector2(850, 0), "scale": 1.05}, # Shifted to right side
		"build_dock": {"offset": Vector2(-850, 0), "scale": 1.0}, # Shifted to left side
		"raid": {"offset": Vector2(900, 0), "scale": 1.0},
		"command_lock": {"offset": Vector2(-750, -40), "scale": 1.15} # Near left thumb
	},
	"Компактный": {
		"top_bar": {"offset": Vector2(0, -6), "scale": 0.85},
		"inspector": {"offset": Vector2(0, 10), "scale": 0.85},
		"minimap": {"offset": Vector2(0, 10), "scale": 0.85},
		"build_dock": {"offset": Vector2(0, 0), "scale": 0.85},
		"raid": {"offset": Vector2(0, -6), "scale": 0.85},
		"command_lock": {"offset": Vector2(0, 10), "scale": 0.90}
	}
}

# User saved presets: name -> layout dictionary
var user_presets: Dictionary = {}

func _ready() -> void:
	reset_to_default()
	load_user_presets()

func reset_to_default() -> void:
	current_layout = _clone_dict(builtin_presets["По умолчанию"])
	active_preset_name = "По умолчанию"
	layout_changed.emit()

func get_element_offset(element_id: String) -> Vector2:
	if current_layout.has(element_id) and current_layout[element_id].has("offset"):
		var off = current_layout[element_id]["offset"]
		if off is Vector2:
			return off
		elif off is Array and off.size() >= 2:
			return Vector2(off[0], off[1])
	return Vector2.ZERO

func get_element_scale(element_id: String) -> float:
	if current_layout.has(element_id) and current_layout[element_id].has("scale"):
		return clampf(float(current_layout[element_id]["scale"]), 0.6, 1.5)
	return 1.0

func set_element_offset(element_id: String, offset: Vector2) -> void:
	if not current_layout.has(element_id):
		current_layout[element_id] = {"offset": Vector2.ZERO, "scale": 1.0}
	current_layout[element_id]["offset"] = offset
	layout_changed.emit()

func set_element_scale(element_id: String, scale_val: float) -> void:
	if not current_layout.has(element_id):
		current_layout[element_id] = {"offset": Vector2.ZERO, "scale": 1.0}
	current_layout[element_id]["scale"] = clampf(scale_val, 0.6, 1.5)
	layout_changed.emit()

func get_preset_names() -> Array[String]:
	var names: Array[String] = []
	for k in builtin_presets.keys():
		names.append(k)
	for k in user_presets.keys():
		if not names.has(k):
			names.append(k)
	return names

func apply_preset(preset_name: String) -> bool:
	if builtin_presets.has(preset_name):
		current_layout = _clone_dict(builtin_presets[preset_name])
		active_preset_name = preset_name
		layout_changed.emit()
		return true
	elif user_presets.has(preset_name):
		current_layout = _clone_dict(user_presets[preset_name])
		active_preset_name = preset_name
		layout_changed.emit()
		return true
	return false

func save_preset(preset_name: String) -> bool:
	var trimmed := preset_name.strip_edges()
	if trimmed.is_empty():
		return false
	user_presets[trimmed] = _clone_dict(current_layout)
	active_preset_name = trimmed
	save_user_presets()
	layout_changed.emit()
	return true

func delete_user_preset(preset_name: String) -> bool:
	if user_presets.has(preset_name):
		user_presets.erase(preset_name)
		if active_preset_name == preset_name:
			reset_to_default()
		save_user_presets()
		return true
	return false

func save_user_presets() -> void:
	var file := FileAccess.open(PRESETS_FILE_PATH, FileAccess.WRITE)
	if not file:
		return
	var serialized: Dictionary = {}
	for p_name in user_presets.keys():
		var p_dict: Dictionary = user_presets[p_name]
		var ser_p: Dictionary = {}
		for elem in p_dict.keys():
			var off: Vector2 = p_dict[elem].get("offset", Vector2.ZERO)
			var sc: float = p_dict[elem].get("scale", 1.0)
			ser_p[elem] = {"offset": [off.x, off.y], "scale": sc}
		serialized[p_name] = ser_p
	var data_to_save := {
		"active_preset": active_preset_name,
		"presets": serialized
	}
	file.store_string(JSON.stringify(data_to_save, "\t"))
	file.close()

func load_user_presets() -> void:
	if not FileAccess.file_exists(PRESETS_FILE_PATH):
		return
	var file := FileAccess.open(PRESETS_FILE_PATH, FileAccess.READ)
	if not file:
		return
	var json_text := file.get_as_text()
	file.close()
	
	var parsed = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		return
	
	var presets_data: Dictionary = parsed.get("presets", {})
	user_presets.clear()
	for p_name in presets_data.keys():
		var ser_p: Dictionary = presets_data[p_name]
		var loaded_p: Dictionary = {}
		for elem in ser_p.keys():
			var off_arr = ser_p[elem].get("offset", [0, 0])
			var off := Vector2(off_arr[0], off_arr[1]) if (off_arr is Array and off_arr.size() >= 2) else Vector2.ZERO
			var sc: float = clampf(float(ser_p[elem].get("scale", 1.0)), 0.6, 1.5)
			loaded_p[elem] = {"offset": off, "scale": sc}
		user_presets[p_name] = loaded_p
		
	var last_active: String = parsed.get("active_preset", "")
	if not last_active.is_empty():
		apply_preset(last_active)

func _clone_dict(src: Dictionary) -> Dictionary:
	var res: Dictionary = {}
	for k in src.keys():
		var item = src[k]
		if item is Dictionary:
			res[k] = _clone_dict(item)
		else:
			res[k] = item
	return res
