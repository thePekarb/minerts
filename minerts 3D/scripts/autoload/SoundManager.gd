extends Node

var is_muted: bool = false
var sfx_players: Array[AudioStreamPlayer] = []
const POOL_SIZE: int = 8
var sound_cache: Dictionary = {}

func _ready() -> void:
	for i in range(POOL_SIZE):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(p)
		sfx_players.append(p)

	EventBus.sound_requested.connect(play_sound)
	_pregenerate_sounds()

func toggle_mute() -> bool:
	is_muted = not is_muted
	if is_muted:
		for player in sfx_players:
			player.stop()
	return is_muted

func play_sound(sound_name: String) -> void:
	if is_muted:
		return
	var stream: AudioStreamWAV = sound_cache.get(sound_name, null)
	if not stream:
		return

	for p in sfx_players:
		if not p.playing:
			p.stream = stream
			p.play()
			return
	# If all busy, steal the first player
	sfx_players[0].stream = stream
	sfx_players[0].play()

func play_click() -> void:
	play_sound("click")

func play_select() -> void:
	play_sound("select_unit")

func play_build() -> void:
	play_sound("build")

func play_chop() -> void:
	play_sound("chop")

func play_mine() -> void:
	play_sound("mine")

func play_attack() -> void:
	play_sound("attack")

func play_horn() -> void:
	play_sound("raid_horn")

func play_chest() -> void:
	play_sound("chest")

func play_pop() -> void:
	play_sound("pop")

func play_hit() -> void:
	play_sound("hit")

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
