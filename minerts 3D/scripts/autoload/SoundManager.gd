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

func play_spatial(sound_name: String, world_pos: Vector3, max_distance: float = 28.0, base_vol_db: float = 0.0, pitch_var: float = 0.06) -> void:
	if is_muted:
		return
	if is_instance_valid(camera):
		var listener_pos: Vector3 = camera.current_focus if ("current_focus" in camera) else camera.global_position
		var dist: float = Vector2(listener_pos.x - world_pos.x, listener_pos.z - world_pos.z).length()
		if dist > max_distance:
			return # Inaudible beyond max distance - spatial cutoff
		var factor: float = clampf(1.0 - (dist / max_distance), 0.0, 1.0)
		var vol_db: float = base_vol_db + linear_to_db(maxf(factor * factor, 0.01))
		var pitch: float = 1.0 + randf_range(-pitch_var, pitch_var)
		play_sound(sound_name, vol_db, pitch)
	else:
		play_sound(sound_name, base_vol_db)

# ==============================================================================
# Thematic Sound Triggers
# ==============================================================================

# Wood Chopping (Axe) - sounds in proximity to the chopping process
func play_chop(pos: Vector3 = Vector3.INF) -> void:
	if pos != Vector3.INF:
		play_spatial("chop", pos, 24.0, 1.5)
	else:
		play_sound("chop", 1.5)

# Ore & Stone Mining (Pickaxe on rock/ore)
func play_ore_mine(pos: Vector3 = Vector3.INF) -> void:
	if pos != Vector3.INF:
		play_spatial("ore_mining", pos, 28.0, 1.5)
	else:
		play_sound("ore_mining", 1.5)

func play_mine() -> void:
	play_ore_mine()

func play_ore_pick(pos: Vector3 = Vector3.INF) -> void:
	if pos != Vector3.INF:
		play_spatial("ore_pick", pos, 26.0, 2.0)
	else:
		play_sound("ore_pick", 2.0)

# Construction (Hammering wood/structures)
func play_build(pos: Vector3 = Vector3.INF) -> void:
	if pos != Vector3.INF:
		play_spatial("build", pos, 30.0, 1.0)
	else:
		play_sound("build", 1.0)

# Bow & Arrow
func play_arrow(pos: Vector3 = Vector3.INF) -> void:
	if pos != Vector3.INF:
		play_spatial("arrow", pos, 32.0, 1.0)
	else:
		play_sound("arrow", 1.0)

# Zombie (Night raid / attack / groan)
func play_zombie(pos: Vector3 = Vector3.INF) -> void:
	if pos != Vector3.INF:
		play_spatial("zombie", pos, 28.0, 2.0)
	else:
		play_sound("zombie", 2.0)

# Creeper
func play_creeper_fuse(pos: Vector3 = Vector3.INF) -> void:
	if pos != Vector3.INF:
		play_spatial("creeper_fuse", pos, 28.0, 2.0)
	else:
		play_sound("creeper_fuse", 2.0)

func play_creeper_explosion(pos: Vector3 = Vector3.INF) -> void:
	if pos != Vector3.INF:
		play_spatial("creeper_explosion", pos, 55.0, 4.0)
	else:
		play_sound("creeper_explosion", 4.0)

# Eating Apple (Food consumption, training units, harvest)
func play_eat_apple() -> void:
	play_sound("eat_apple", 2.0)

# Melee Sword Strike / Blade Clash
func play_knife_scrape(pos: Vector3 = Vector3.INF) -> void:
	if pos != Vector3.INF:
		play_spatial("knife_scrape", pos, 26.0, 1.0)
	else:
		play_sound("knife_scrape", 1.0)

# Male Death Cry (When a colonist falls in battle)
func play_male_death(pos: Vector3 = Vector3.INF) -> void:
	if pos != Vector3.INF:
		play_spatial("male_death", pos, 35.0, 2.0)
	else:
		play_sound("male_death", 2.0)

# Wolf / Wild animal growl
func play_wolf_growl(pos: Vector3 = Vector3.INF) -> void:
	if pos != Vector3.INF:
		play_spatial("wolf_growl", pos, 28.0, 1.0)
	else:
		play_sound("wolf_growl", 1.0)

# UI & Misc
func play_click() -> void:
	play_sound("click", -4.0)

func play_select() -> void:
	play_sound("select_unit", -2.0)

func play_attack() -> void:
	play_sound("attack", 0.0)

func play_horn() -> void:
	play_sound("raid_horn", 2.0)

func play_chest() -> void:
	play_sound("chest", 0.0)

func play_pop() -> void:
	play_sound("pop", -2.0)

func play_hit() -> void:
	play_sound("hit", 0.0)

func _load_all_sounds() -> void:
	_pregenerate_sounds()

	# Custom theme recordings (with procedural fallbacks if file missing)
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

	var s_knife: AudioStream = _load_wav_file("res://assets/sounds/knife_scrape.wav")
	if s_knife: sound_cache["knife_scrape"] = s_knife

	var s_death: AudioStream = _load_wav_file("res://assets/sounds/male_death.wav")
	if s_death: sound_cache["male_death"] = s_death

	var s_wolf: AudioStream = _load_wav_file("res://assets/sounds/wolf_growl.wav")
	if s_wolf: sound_cache["wolf_growl"] = s_wolf

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

func _pregenerate_sounds() -> void:
	sound_cache["explosion"] = _gen_noise_thud(55.0, 0.5, 0.55)
	sound_cache["fuse"] = _gen_slide(260.0, 1300.0, 0.7, "sine", 0.2)
	sound_cache["click"] = _gen_tone(800.0, 0.04, "sine", 0.3)
	sound_cache["select_unit"] = _gen_slide(440.0, 660.0, 0.12, "sine", 0.35)
	sound_cache["order_move"] = _gen_slide(600.0, 480.0, 0.08, "triangle", 0.3)
	sound_cache["build"] = _gen_noise_thud(180.0, 0.12, 0.4)
	sound_cache["build_done"] = _gen_chord([523.25, 659.25, 783.99], 0.35, 0.4)
	sound_cache["chop"] = _gen_noise_thud(220.0, 0.09, 0.45)
	sound_cache["mine"] = _gen_tone(1100.0, 0.08, "square", 0.25)
	sound_cache["attack"] = _gen_slide(300.0, 150.0, 0.14, "sawtooth", 0.4)
	sound_cache["hit"] = _gen_noise_thud(120.0, 0.15, 0.5)
	sound_cache["pop"] = _gen_slide(500.0, 850.0, 0.08, "sine", 0.35)
	sound_cache["chest"] = _gen_arpeggio([440.0, 554.37, 659.25, 880.0], 0.08, 0.35)
	sound_cache["raid_horn"] = _gen_slide(130.0, 98.0, 1.2, "sawtooth", 0.5)

func _gen_tone(freq: float, duration: float, wave: String, vol: float) -> AudioStreamWAV:
	var rate: int = 22050
	var samples: int = int(float(rate) * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples * 2)

	for i in range(samples):
		var t: float = float(i) / float(rate)
		var env: float = 1.0 - (float(i) / float(samples)) # Linear decay
		var s: float = 0.0
		if wave == "sine":
			s = sin(TAU * freq * t)
		elif wave == "triangle":
			s = (2.0 / PI) * asin(sin(TAU * freq * t))
		elif wave == "square":
			s = 1.0 if sin(TAU * freq * t) >= 0.0 else -1.0
		elif wave == "sawtooth":
			s = (fmod(freq * t, 1.0) * 2.0) - 1.0

		var val: int = int(clampf(s * env * vol, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val)

	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream

func _gen_slide(start_freq: float, end_freq: float, duration: float, wave: String, vol: float) -> AudioStreamWAV:
	var rate: int = 22050
	var samples: int = int(float(rate) * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples * 2)
	var phase: float = 0.0

	for i in range(samples):
		var alpha: float = float(i) / float(samples)
		var freq: float = lerpf(start_freq, end_freq, alpha)
		var env: float = 1.0 - alpha
		phase += TAU * freq * (1.0 / float(rate))
		var s: float = sin(phase) if wave != "sawtooth" else (fmod(phase / TAU, 1.0) * 2.0) - 1.0
		var val: int = int(clampf(s * env * vol, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val)

	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream

func _gen_noise_thud(freq: float, duration: float, vol: float) -> AudioStreamWAV:
	var rate: int = 22050
	var samples: int = int(float(rate) * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples * 2)

	for i in range(samples):
		var alpha: float = float(i) / float(samples)
		var env: float = pow(1.0 - alpha, 2.0)
		var s: float = (sin(TAU * freq * (float(i) / float(rate))) * 0.6) + ((randf() * 2.0 - 1.0) * 0.4)
		var val: int = int(clampf(s * env * vol, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val)

	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream

func _gen_chord(freqs: Array, duration: float, vol: float) -> AudioStreamWAV:
	var rate: int = 22050
	var samples: int = int(float(rate) * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples * 2)

	for i in range(samples):
		var t: float = float(i) / float(rate)
		var alpha: float = float(i) / float(samples)
		var env: float = 1.0 - alpha
		var s: float = 0.0
		for f in freqs:
			s += sin(TAU * float(f) * t)
		s /= float(freqs.size())
		var val: int = int(clampf(s * env * vol, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val)

	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream

func _gen_arpeggio(notes: Array, note_duration: float, vol: float) -> AudioStreamWAV:
	var rate: int = 22050
	var total_samples: int = int(float(rate) * note_duration * float(notes.size()))
	var data: PackedByteArray = PackedByteArray()
	data.resize(total_samples * 2)

	var note_samples: int = int(float(rate) * note_duration)
	for n in range(notes.size()):
		var freq: float = float(notes[n])
		for i in range(note_samples):
			var idx: int = n * note_samples + i
			var t: float = float(i) / float(rate)
			var env: float = 1.0 - (float(i) / float(note_samples) * 0.5)
			var s: float = sin(TAU * freq * t)
			var val: int = int(clampf(s * env * vol, -1.0, 1.0) * 32767.0)
			data.encode_s16(idx * 2, val)

	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream

func _exit_tree() -> void:
	for player in sfx_players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	sound_cache.clear()
