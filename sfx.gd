extends Node

# Efectos de sonido (autoload Sfx). Los .wav salen de tools/generate_sfx.py en assets/sounds/sfx. Suenan por
# el bus "SFX" (su volumen se ajusta en Opciones), con un grupo de reproductores para que se solapen, un
# poco de variación de tono para que lo repetido no suene igual y sin repetir el mismo sonido dos veces en
# el mismo instante (un golpe que alcanza a dos enemigos suena una vez).

const SFX_DIR := "res://assets/sounds/sfx"
const BUS := &"SFX"
const VOICES := 16
const SAME_SOUND_GAP_MS := 35
# Volumen (dB) y variación de tono de cada sonido; lo que no está aquí va a 0 dB y ±5 %.
const MIX := {
	"step": [-11.0, 0.14], "land": [-7.0, 0.08], "jump": [-9.0, 0.06], "air_jump": [-6.0, 0.06],
	"skid": [-8.0, 0.08], "wallride": [-8.0, 0.06], "wall_jump": [-5.0, 0.06], "grab": [-7.0, 0.08],
	"dash": [-6.0, 0.06], "swing_light": [-5.0, 0.1], "swing_heavy": [-3.0, 0.05], "dash_attack": [-4.0, 0.06],
	"uppercut": [-3.0, 0.05], "spin": [-3.0, 0.04], "hit_light": [-2.0, 0.1], "hit_heavy": [0.0, 0.06],
	"heavy_land": [-1.0, 0.04], "bounce": [-4.0, 0.06], "shine": [-4.0, 0.03], "parry": [-1.0, 0.02],
	"block": [-3.0, 0.06], "shine_break": [-1.0, 0.0], "hurt": [-2.0, 0.05], "death": [0.0, 0.0],
	"enemy_die": [-3.0, 0.08], "enemy_swing": [-7.0, 0.06], "knife_throw": [-5.0, 0.06],
	"knife_hit": [-5.0, 0.08], "knife_catch": [-8.0, 0.05], "rank_up": [-9.0, 0.0], "growl": [-3.0, 0.03],
	"ui_move": [-14.0, 0.0], "ui_select": [-10.0, 0.0], "shine_hold": [-10.0, 0.0],
	"enemy_alert": [-9.0, 0.0], "boss_alert": [-8.0, 0.0], "enemy_hurt": [-8.0, 0.1], "boss_hurt": [-5.0, 0.08],
	"enemy_charge": [-10.0, 0.0], "enemy_shoot": [-7.0, 0.08], "projectile_pop": [-9.0, 0.1], "zap": [-6.0, 0.08],
	"boss_swing": [-4.0, 0.06], "shockwave": [-2.0, 0.04], "boss_charge": [-4.0, 0.0], "boss_spin": [-4.0, 0.03],
	"boss_dash": [-5.0, 0.06], "rapier": [-5.0, 0.1], "dagger_throw": [-6.0, 0.04], "bow_draw": [-11.0, 0.04],
	"arrow_shot": [-4.0, 0.06], "rain_mark": [-11.0, 0.05], "arrow_rain": [-6.0, 0.03], "teleport": [-6.0, 0.03],
	"sun_hit": [-6.0, 0.06], "hawk_screech": [-7.0, 0.04], "hawk_dive": [-8.0, 0.05], "guard_break": [-3.0, 0.04],
}
# Sonidos en bucle (se arrancan con start_loop y se paran con stop_loop).
const LOOPS := ["shine_hold"]
const LOOP_FADE := 0.08

var streams := {}
var players: Array[AudioStreamPlayer] = []
var next_voice := 0
var last_played := {}
var loop_players := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus()
	_load_streams()
	for i in range(VOICES):
		var player := AudioStreamPlayer.new()
		player.bus = BUS
		add_child(player)
		players.append(player)

func play(sound: String, volume_offset_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream: AudioStream = streams.get(sound)
	if stream == null:
		return
	var now := Time.get_ticks_msec()
	if now - int(last_played.get(sound, -100000)) < SAME_SOUND_GAP_MS:
		return
	last_played[sound] = now
	Rumble.on_sound(sound)
	var mix: Array = MIX.get(sound, [0.0, 0.05])
	var player := _free_voice()
	player.stream = stream
	player.volume_db = mix[0] + volume_offset_db
	player.pitch_scale = max(pitch * (1.0 + randf_range(-mix[1], mix[1])), 0.05)
	player.play()

func start_loop(sound: String, volume_offset_db: float = 0.0) -> void:
	# Sonido mantenido (el zumbido del shine): entra con un fundido corto y se pausa con el juego.
	var stream: AudioStream = streams.get(sound)
	if stream == null:
		return
	var player: AudioStreamPlayer = loop_players.get(sound)
	if player == null:
		player = AudioStreamPlayer.new()
		player.bus = BUS
		player.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(player)
		loop_players[sound] = player
	var target: float = float(MIX.get(sound, [0.0, 0.0])[0]) + volume_offset_db
	_kill_fade(player)
	player.stream = stream
	player.volume_db = -40.0
	if not player.playing:
		player.play()
	var tween := player.create_tween()
	tween.tween_property(player, "volume_db", target, LOOP_FADE)
	player.set_meta(&"fade", tween)

func stop_loop(sound: String) -> void:
	var player: AudioStreamPlayer = loop_players.get(sound)
	if player == null or not player.playing:
		return
	_kill_fade(player)
	var tween := player.create_tween()
	tween.tween_property(player, "volume_db", -40.0, LOOP_FADE)
	tween.tween_callback(player.stop)
	player.set_meta(&"fade", tween)

func is_looping(sound: String) -> bool:
	var player: AudioStreamPlayer = loop_players.get(sound)
	return player != null and player.playing

func _kill_fade(player: AudioStreamPlayer) -> void:
	var previous: Tween = player.get_meta(&"fade") if player.has_meta(&"fade") else null
	if previous and previous.is_valid():
		previous.kill()

func has_sound(sound: String) -> bool:
	return streams.has(sound)

func _free_voice() -> AudioStreamPlayer:
	for i in range(VOICES):
		var player := players[(next_voice + i) % VOICES]
		if not player.playing:
			next_voice = (next_voice + i + 1) % VOICES
			return player
	# Todos sonando: se reutiliza el más antiguo (el siguiente en la rueda).
	var oldest := players[next_voice]
	next_voice = (next_voice + 1) % VOICES
	return oldest

func _load_streams() -> void:
	var dir := DirAccess.open(SFX_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		# En el juego exportado solo quedan los .import; el recurso se carga igual por la ruta original.
		var name := file.trim_suffix(".import").trim_suffix(".remap")
		if name.get_extension() != "wav":
			continue
		var stream := load(SFX_DIR.path_join(name)) as AudioStream
		if stream:
			if name.get_basename() in LOOPS and stream is AudioStreamWAV:
				stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
				stream.loop_begin = 0
				stream.loop_end = stream.data.size() / 2
			streams[name.get_basename()] = stream

func _ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, BUS)
	AudioServer.set_bus_send(index, &"Master")
