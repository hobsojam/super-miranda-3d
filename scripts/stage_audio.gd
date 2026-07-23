class_name StageAudio
extends Node

const STAGE_MUSIC := {
	1: {
		"base_a": "res://audio/music/stage1_base_a.wav",
		"base_b": "res://audio/music/stage1_base_b.wav",
		"drums_high_a": "res://audio/music/stage1_drums_breakbeat_dnb.wav",
		"drums_high_b": "res://audio/music/stage1_drums_breakbeat_dnb.wav",
		"drums_low": "res://audio/music/stage1_drums_sparse.wav",
	},
	2: {
		"base_a": "res://audio/music/stage2_base_a.wav",
		"base_b": "res://audio/music/stage2_base_b.wav",
		"drums_high_a": "res://audio/music/stage2_drums_electro_a.wav",
		"drums_high_b": "res://audio/music/stage2_drums_electro_b.wav",
		"drums_low": "res://audio/music/stage2_drums_sparse.wav",
	},
}

const FIRE_SOUND := preload("res://audio/sfx/player_fire.wav")
const HIT_SOUND := preload("res://audio/sfx/player_hit.wav")
const KILL_SOUND := preload("res://audio/sfx/enemy_killed.wav")
const CLEAR_SOUND := preload("res://audio/sfx/stage_clear.wav")
const GAME_OVER_SOUND := preload("res://audio/sfx/game_over.wav")
const EXPLODER_SOUND := preload("res://audio/sfx/exploder_boom.wav")
const LIFE_PICKUP_SOUND := preload("res://audio/sfx/pickup_life.wav")
const PURGE_PICKUP_SOUND := preload("res://audio/sfx/pickup_purge.wav")

var _base_player: AudioStreamPlayer
var _drums_high_player: AudioStreamPlayer
var _drums_low_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _base_passes: Array[AudioStream] = []
var _drums_high_passes: Array[AudioStream] = []
var _pass_index: int = 0
var _loaded_music_stage: int = 0
var _music_intensity: float = 0.0

static func music_stage_for(stage: int) -> int:
	return 2 if stage >= 2 else 1

static func target_intensity(
	active_pressure: int,
	low_obstacles: int,
	high_obstacles: int
) -> float:
	if high_obstacles <= low_obstacles:
		return 0.0
	var span: float = float(high_obstacles - low_obstacles)
	return clampf(float(active_pressure - low_obstacles) / span, 0.0, 1.0)

static func damage_sound_volume(sound: AudioStream) -> float:
	if sound == EXPLODER_SOUND:
		return -5.0
	return -7.0

func setup(initial_stage: int = 1) -> void:
	_ensure_audio_bus("Music")
	_ensure_audio_bus("Sound")
	_base_player = _music_player_node("BasePlayer")
	_drums_high_player = _music_player_node("DrumsHighPlayer")
	_drums_low_player = _music_player_node("DrumsLowPlayer")
	_base_player.finished.connect(_on_music_pass_finished)
	load_music_stage(initial_stage)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "Sound"
	add_child(_sfx_player)

func stop_all() -> void:
	if _base_player:
		_base_player.stop()
	if _drums_high_player:
		_drums_high_player.stop()
	if _drums_low_player:
		_drums_low_player.stop()
	if _sfx_player:
		_sfx_player.stop()

func load_music_stage(stage: int) -> void:
	var resolved_stage: int = music_stage_for(stage)
	if _loaded_music_stage == resolved_stage:
		return
	_loaded_music_stage = resolved_stage
	var stems: Dictionary = STAGE_MUSIC[resolved_stage]
	_base_passes = [load(stems["base_a"]), load(stems["base_b"])]
	_drums_high_passes = [load(stems["drums_high_a"]), load(stems["drums_high_b"])]
	for stream in _base_passes:
		_set_loop(stream, AudioStreamWAV.LOOP_DISABLED)
	for stream in _drums_high_passes:
		_set_loop(stream, AudioStreamWAV.LOOP_DISABLED)
	var low_drums: AudioStream = load(stems["drums_low"])
	_set_loop(low_drums, AudioStreamWAV.LOOP_FORWARD)
	_drums_low_player.stream = low_drums
	_drums_low_player.volume_db = 0.0
	_drums_high_player.volume_db = -80.0
	_music_intensity = 0.0
	_pass_index = 0
	_play_current_music_pass()
	_drums_low_player.play()

func update_music_intensity(
	delta: float,
	active_pressure: int,
	low_obstacles: int,
	high_obstacles: int,
	crossfade_speed: float
) -> void:
	if _drums_high_player == null or _drums_low_player == null:
		return
	var target: float = target_intensity(active_pressure, low_obstacles, high_obstacles)
	_music_intensity = lerpf(_music_intensity, target, clampf(delta * crossfade_speed, 0.0, 1.0))
	_drums_high_player.volume_db = linear_to_db(clampf(_music_intensity, 0.001, 1.0))
	_drums_low_player.volume_db = linear_to_db(clampf(1.0 - _music_intensity, 0.001, 1.0))

func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	_sfx_player.stream = stream
	_sfx_player.volume_db = volume_db
	_sfx_player.play()

func _music_player_node(node_name: String) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = node_name
	player.bus = "Music"
	add_child(player)
	return player

func _set_loop(stream: AudioStream, mode: int) -> void:
	if stream is AudioStreamWAV:
		stream.loop_mode = mode

func _play_current_music_pass() -> void:
	_base_player.stream = _base_passes[_pass_index]
	_drums_high_player.stream = _drums_high_passes[_pass_index]
	_base_player.volume_db = -9.0
	_drums_high_player.play()
	_base_player.play()

func _on_music_pass_finished() -> void:
	_pass_index = (_pass_index + 1) % _base_passes.size()
	_play_current_music_pass()

func _ensure_audio_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
