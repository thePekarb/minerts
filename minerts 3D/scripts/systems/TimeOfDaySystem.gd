class_name TimeOfDaySystem
extends Node

@export var day_duration_seconds: float = 360.0 # 6 minutes for a full day-night cycle
@export var start_time: float = 0.35 # Start morning

var time_of_day: float = 0.35
var current_day: int = 1

var sun_light: DirectionalLight3D
var world_environment: WorldEnvironment

func init_lighting(sun: DirectionalLight3D, env: WorldEnvironment) -> void:
	sun_light = sun
	world_environment = env
	time_of_day = start_time
	_update_lighting()

func _process(delta: float) -> void:
	var prev_time: float = time_of_day
	time_of_day += delta / maxf(day_duration_seconds, 0.1)

	if time_of_day >= 1.0:
		time_of_day -= 1.0
		current_day += 1
		EventBus.day_passed.emit(current_day)

	_update_lighting()
	EventBus.time_of_day_changed.emit(time_of_day)

func _update_lighting() -> void:
	if not is_instance_valid(sun_light):
		return

	var elevation: float = sin((time_of_day - 0.25) * TAU)
	var daylight: float = smoothstep(-0.12, 0.3, elevation)
	var warmth: float = 1.0 - smoothstep(0.0, 0.65, absf(elevation))
	# The same directional light becomes a downward-facing moon at night.
	sun_light.rotation = Vector3(-maxf(0.18, absf(elevation) * 1.2), deg_to_rad(-45.0), 0.0)
	sun_light.light_energy = lerpf(0.22, 0.95, daylight)
	var day_color: Color = Color("fff1d5").lerp(Color("ffc185"), warmth * 0.65)
	sun_light.light_color = Color("8da9df").lerp(day_color, daylight)

	if is_instance_valid(world_environment) and world_environment.environment:
		var env: Environment = world_environment.environment
		env.ambient_light_energy = lerpf(0.20, 0.46, daylight)
		env.ambient_light_color = Color("7185b1").lerp(Color("c5d9e5"), daylight)
		env.fog_light_color = Color("26354e").lerp(Color("afc8ce"), daylight)
		if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
			var sky: ProceduralSkyMaterial = env.sky.sky_material
			sky.sky_top_color = Color("0c172f").lerp(Color("518aaf"), daylight)
			sky.sky_horizon_color = Color("344560").lerp(Color("d6d9c7").lerp(Color("edaf88"), warmth), daylight)
			sky.ground_horizon_color = sky.sky_horizon_color

func get_formatted_time() -> String:
	var total_hours: float = time_of_day * 24.0
	var hours: int = int(total_hours)
	var mins: int = int((total_hours - float(hours)) * 60.0)
	return "%02d:%02d" % [hours, mins]
