class_name SoundDirector
extends Node

const CUES: Array[String] = ["hit_light_1", "hit_light_2", "hit_light_3", "hit_heavy_1", "hit_heavy_2", "hit_heavy_3", "part_pop", "snap", "core_pop", "blade", "burst", "cannon", "halo", "jump", "boost", "land", "ui_move", "ui_confirm", "warning", "ready", "go", "victory", "phase", "prism", "rail", "rail_charge", "switch"]
var audio_enabled: bool = DisplayServer.get_name() != "headless"
var sounds: Dictionary = {}
var voices: Array[AudioStreamPlayer2D] = []
var voice_priority: Array[int] = []
var ui_player: AudioStreamPlayer
var music: AudioStreamPlayer
var session: MatchSession
var cue_times: Dictionary = {}
var duck: float = 0.0
var rumble: float = 0.55
var master_volume: float = 0.8
var music_volume: float = 0.48
var sfx_volume: float = 0.85
var ui_volume: float = 0.65
var ambience_volume: float = 0.3

func _ready() -> void:
	for bus in ["Music", "SFX", "UI", "Ambience"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	var limiter := AudioEffectLimiter.new()
	limiter.ceiling_db = -1.0
	limiter.threshold_db = -3.0
	AudioServer.add_bus_effect(0, limiter)
	for cue in CUES:
		var path: String = "res://audio/sfx/%s.wav" % cue
		if ResourceLoader.exists(path):
			sounds[cue] = load(path)
	for id in Roster.IDS:
		var special := String(Roster.part(Roster.mech(id).native_weapon).attack.feedback)
		if special.begins_with("chassis/"):
			sounds[special] = load("res://audio/sfx/%s.wav" % special)
		for role in ["light", "heavy", "hit", "guard", "boost", "ko"]:
			var bank := "chassis/%s_%s" % [id, role]
			sounds[bank] = load("res://audio/sfx/%s.wav" % bank)
	for i in range(24):
		var player := AudioStreamPlayer2D.new()
		player.bus = "SFX"
		player.max_distance = 100000.0
		player.attenuation = 0.0
		player.panning_strength = 0.7
		add_child(player)
		voices.append(player)
		voice_priority.append(0)
	ui_player = AudioStreamPlayer.new()
	ui_player.bus = "UI"
	ui_player.volume_db = 3.0
	add_child(ui_player)
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	add_child(music)
	apply_volumes()

func attach(match_session: MatchSession) -> void:
	session = match_session
	session.combat_event.connect(_on_event)
	for voice in voices:
		voice.stop()
	var path: String = session.stage.definition.music
	music.stop()
	if ResourceLoader.exists(path):
		music.stream = load(path)
		_loop_music()
		if audio_enabled: music.play()

func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, master_volume)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(0.0001, music_volume)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(0.0001, sfx_volume)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("UI"), linear_to_db(maxf(0.0001, ui_volume)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambience"), linear_to_db(maxf(0.0001, ambience_volume)))

func _process(delta: float) -> void:
	duck = move_toward(duck, 0.0, delta * 10.0)
	music.volume_db = -duck
	var paused: bool = session != null and is_instance_valid(session) and session.paused
	music.stream_paused = paused
	for voice in voices:
		voice.stream_paused = paused

func cue(name: String, point: Vector2 = Vector2.ZERO, priority: int = 1, level: float = 0.0, pitch: float = 1.0) -> void:
	if not audio_enabled or not sounds.has(name):
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	var spacing: float = 0.035 if priority >= 3 else 0.07
	if now - float(cue_times.get(name, -10.0)) < spacing:
		return
	cue_times[name] = now
	var slot: int = -1
	for i in range(voices.size()):
		if not voices[i].playing:
			slot = i
			break
	if slot < 0:
		for i in range(voices.size()):
			if voice_priority[i] < priority:
				slot = i
				break
	if slot < 0:
		return
	var voice: AudioStreamPlayer2D = voices[slot]
	voice_priority[slot] = priority
	voice.stream = sounds[name]
	voice.volume_db = level
	voice.pitch_scale = pitch
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	voice.position = viewport_size * 0.5 + Vector2(clampf(point.x / 1500.0, -1.0, 1.0) * viewport_size.x * 0.45, 0.0)
	voice.play()

func ui_cue(name: String = "ui_confirm") -> void:
	if audio_enabled and sounds.has(name):
		ui_player.stream = sounds[name]
		ui_player.play()

func _on_event(kind: StringName, payload: Dictionary) -> void:
	var fighter: Fighter = payload.get("fighter")
	var point: Vector2 = fighter.position if fighter else Vector2.ZERO
	var bank := "chassis/%s_" % fighter.data.id if fighter else ""
	match kind:
		&"hit":
			var heavy: bool = payload.attack.breaker
			if payload.get("armored", false):
				cue(bank + "guard", point, 4, 0.0, 0.91)
			else:
				cue(bank + "hit", point, 3, 0.0 if heavy else -2.0, 0.83 if heavy else 1.03)
				if payload.get("shielded", false):
					cue(bank + "guard", point, 1, -8.0 if heavy else -12.0, 1.1)
			_rumble(fighter, 0.55 if heavy else 0.2, 0.10 if heavy else 0.045)
			_rumble(payload.source, 0.35 if heavy else 0.13, 0.065)
			if heavy:
				duck = maxf(duck, 2.0)
		&"part_pop":
			cue("part_pop", point, 4, 4.0)
			_rumble(fighter, 0.8, 0.16)
			duck = 4.0
		&"core_pop":
			cue(bank + "ko", point, 5, 1.0)
			duck = 6.0
			_rumble(fighter, 1.0, 0.28)
		&"snap":
			cue("snap", point, 4, 5.0)
			_rumble(fighter, 0.35, 0.075)
		&"parry":
			cue(bank + "guard", point, 4, 1.0)
		&"attack_active":
			if payload.special or payload.attack.id == &"zero_scope":
				cue(String(payload.attack.feedback), point, 2, 0.0 if payload.attack.id == &"pile_shot" else 1.0)
			else:
				cue(bank + ("heavy" if payload.attack.breaker else "light"), point, 2, -3.0)
		&"attack_start":
			if payload.attack.id == &"rail_shot": cue("rail_charge", point, 1, -2.0)
		&"jump": cue(bank + "boost", point, 0, -9.0, 1.4 if payload.air else 1.25)
		&"dodge": cue(bank + "boost", point, 1, -4.0)
		&"land": cue("land", point, 0, -2.0)
		&"repair": cue("halo", point, 2, -6.0)
		&"go": cue("go", Vector2.ZERO, 5, -1.0)
		&"final_thirty": cue("warning", Vector2.ZERO, 4, -1.0)
		&"match_end":
			music.stop()
			cue("victory", Vector2.ZERO, 5, 0.0)

func _rumble(fighter: Fighter, strength: float, duration: float) -> void:
	if rumble <= 0.0 or not session or not fighter:
		return
	var device: int = session.input_router.devices[fighter.slot]
	if device >= 0:
		Input.start_joy_vibration(device, strength * rumble * 0.4, strength * rumble, duration)

func _loop_music() -> void:
	if music.stream is AudioStreamWAV:
		var stream := music.stream as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	elif music.stream is AudioStreamOggVorbis:
		music.stream.loop = true
		music.stream.loop_offset = 0.0

func menu_music() -> void:
	var path: String = "res://audio/music/hangar.wav"
	if ResourceLoader.exists(path):
		music.stream = load(path)
		_loop_music()
		if audio_enabled: music.play()
	session = null

func stop_all() -> void:
	music.stream_paused = false
	music.stop()
	music.stream = null
	ui_player.stream_paused = false
	ui_player.stop()
	ui_player.stream = null
	for voice in voices:
		voice.stream_paused = false
		voice.stop()
		voice.stream = null

func _exit_tree() -> void:
	stop_all()
