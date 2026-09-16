extends Node

var is_muted: bool = false
var camera: Camera3D = null
var sfx_players: Array[AudioStreamPlayer] = []
const POOL_SIZE: int = 16
var sound_cache: Dictionary = {}

func _ready() -> void:
	for i in range(POOL_SIZE):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(p)
		sfx_players.append(p)

	EventBus.sound_requested.connect(play_sound)
	_load_all_sounds()

func set_camera(cam: Camera3D) -> void:
	camera = cam

func toggle_mute() -> bool:
	is_muted = not is_muted
	if is_muted:
		for player in sfx_players:
			player.stop()
	return is_muted

func play_sound(sound_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if is_muted:
		return
	var stream: AudioStream = sound_cache.get(sound_name, null)
	if not stream:
		return

	for p in sfx_players:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.pitch_scale = pitch_scale
			p.play()
			return
	# If all busy, steal the first player
	sfx_players[0].stream = stream
	sfx_players[0].volume_db = volume_db
	sfx_players[0].pitch_scale = pitch_scale
	sfx_players[0].play()

func play_spatial(sound_name: String, world_pos: Vector3, max_distance: float = 18.0, base_vol_db: float = 0.0, pitch_var: float = 0.05) -> void:
	if is_muted:
		return
	if not is_instance_valid(camera):
		var tree: SceneTree = get_tree()
		if tree and tree.current_scene:
			camera = tree.current_scene.find_child("Camera3D", true, false) as Camera3D
	if not is_instance_valid(camera):
		return # Never play spatial sounds globally
	
	var listener_pos: Vector3 = camera.global_position
	if camera is RTSCamera:
		listener_pos = (camera as RTSCamera).current_focus
	elif "current_focus" in camera:
		listener_pos = camera.get("current_focus")
	
	var dist: float = Vector2(listener_pos.x - world_pos.x, listener_pos.z - world_pos.z).length()
	if dist > max_distance:
		return # Inaudible beyond max distance
	
	var factor: float = clampf(1.0 - (dist / max_distance), 0.0, 1.0)
	var vol_db: float = base_vol_db + linear_to_db(maxf(factor * factor * factor, 0.0001))
	var pitch: float = 1.0 + randf_range(-pitch_var, pitch_var)
	play_sound(sound_name, vol_db, pitch)

# ==============================================================================
# Thematic Sound Triggers
# ==============================================================================

# Wood Chopping (Axe) - strictly in proximity to the chopping process
func play_chop(pos: Vector3 = Vector3.INF) -> void:
	if pos != Vector3.INF:
		play_spatial("chop", pos, 18.0, 1.0)

# Ore & Stone Mining (Pickaxe on rock/ore) - only when near or clicked
func play_ore_mine(pos: Vector3 = Vector3.INF) -> void:
	if pos != Vector3.INF:
		play_spatial("ore_mining", pos, 20.0, 1.0)

func play_mine() -> void:
	# Passive mine cycles are silent by design
	pass

func play_ore_pick(pos: Vector3 = Vector3.INF) -> void:
	if pos != Vector3.INF:
		play_spatial("ore_pick", pos, 20.0, 1.5)

# Construction (Hammering wood/structures) - strictly spatial
func play_build(pos: Vector3 = Vector3.INF) -> void:
	if pos != Vector3.INF:
		play_spatial("build", pos, 20.0, 0.5)

# Bow & Arrow
func play_arrow(pos: Vector3 = Vector3.INF) -> void:
	if pos != Vector3.INF:
		play_spatial("arrow", pos, 22.0, 0.5)

# Zombie (Night raid / attack / groan)
func play_zombie(pos: Vector3 = Vector3.INF) -> void:
	if pos != Vector3.INF:
		play_spatial("zombie", pos, 20.0, 1.5)
	else:
		play_sound("zombie", -3.0)

# Creeper
func play_creeper_fuse(pos: Vector3 = Vector3.INF) -> void:
	if pos != Vector3.INF:
		play_spatial("creeper_fuse", pos, 22.0, 1.5)

func play_creeper_explosion(pos: Vector3 = Vector3.INF) -> void:
	if pos != Vector3.INF:
		play_spatial("creeper_explosion", pos, 45.0, 3.0)
	else:
		play_sound("creeper_explosion", 1.0)

# Eating Apple (Food consumption, training units, harvest)
func play_eat_apple() -> void:
	play_sound("eat_apple", 1.0)

# ==============================================================================
# Silent compatibility stubs for obsolete non-theme / procedural calls
# ==============================================================================

func play_click() -> void:
	pass

func play_select() -> void:
	pass

func play_attack() -> void:
	pass

func play_horn() -> void:
	pass

func play_chest() -> void:
	pass

func play_pop() -> void:
	pass

func play_hit() -> void:
	pass

func play_knife_scrape(_pos: Vector3 = Vector3.INF) -> void:
	pass

func play_male_death(_pos: Vector3 = Vector3.INF) -> void:
	pass

func play_wolf_growl(_pos: Vector3 = Vector3.INF) -> void:
	pass

func _load_all_sounds() -> void:
	# Custom theme recordings (strictly the 7 user theme sounds)
	var s_chop: AudioStream = _load_wav_file("res://assets/sounds/wood_chop_single.wav")
	if not s_chop: s_chop = _load_wav_file("res://assets/sounds/wood_chop.wav")
	if s_chop: sound_cache["chop"] = s_chop

	var s_ore: AudioStream = _load_wav_file("res://assets/sounds/ore_mining.wav")
	if s_ore: sound_cache["ore_mining"] = s_ore

	var s_pick: AudioStream = _load_wav_file("res://assets/sounds/ore_pick_single.wav")
	if not s_pick: s_pick = s_ore
	if s_pick: sound_cache["ore_pick"] = s_pick

	var s_build: AudioStream = _load_wav_file("res://assets/sounds/construction.wav")
	if s_build: sound_cache["build"] = s_build

	var s_arrow: AudioStream = _load_wav_file("res://assets/sounds/arrow_single.wav")
	if not s_arrow: s_arrow = _load_wav_file("res://assets/sounds/arrow_shot.wav")
	if s_arrow: sound_cache["arrow"] = s_arrow

	var s_zombie: AudioStream = _load_wav_file("res://assets/sounds/zombie.wav")
	if s_zombie: sound_cache["zombie"] = s_zombie

	var s_fuse: AudioStream = _load_wav_file("res://assets/sounds/creeper_fuse.wav")
	if s_fuse: sound_cache["creeper_fuse"] = s_fuse

	var s_boom: AudioStream = _load_wav_file("res://assets/sounds/creeper_explosion.wav")
	if not s_boom: s_boom = _load_wav_file("res://assets/sounds/creeper.wav")
	if s_boom:
		sound_cache["creeper_explosion"] = s_boom
		sound_cache["explosion"] = s_boom

	var s_eat: AudioStream = _load_wav_file("res://assets/sounds/eat_apple.wav")
	if s_eat: sound_cache["eat_apple"] = s_eat

func _load_wav_file(path: String) -> AudioStreamWAV:
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is AudioStreamWAV:
			return res
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	if bytes.size() < 44 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		return null
	var pos: int = 12
	var rate: int = 44100
	var channels: int = 1
	var bits: int = 16
	while pos < bytes.size() - 8:
		var cid: String = bytes.slice(pos, pos + 4).get_string_from_ascii()
		var csize: int = bytes.decode_u32(pos + 4)
		if cid == "fmt " and csize >= 16:
			channels = bytes.decode_u16(pos + 8 + 2)
			rate = bytes.decode_u32(pos + 8 + 4)
			bits = bytes.decode_u16(pos + 8 + 14)
		elif cid == "data":
			var wav_stream := AudioStreamWAV.new()
			wav_stream.format = AudioStreamWAV.FORMAT_16_BITS if bits == 16 else AudioStreamWAV.FORMAT_8_BITS
			wav_stream.mix_rate = rate
			wav_stream.stereo = (channels == 2)
			wav_stream.data = bytes.slice(pos + 8, pos + 8 + csize)
			return wav_stream
		pos += 8 + csize
	return null

func _exit_tree() -> void:
	for player in sfx_players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	sound_cache.clear()
