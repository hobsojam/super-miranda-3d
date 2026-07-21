extends Camera3D
class_name StormRunner

const MOVE_SOUND := preload("res://audio/sfx/player_move.wav")

@export var storm_path: NodePath
@export var player_path: NodePath
@export var starting_speed: float = 18.0
@export var min_speed: float = 4.0
@export var max_speed: float = 55.0
@export var camera_distance: float = 8.0
@export var camera_lift: float = 2.4
@export var lane_ease_speed: float = 16.0
@export var hold_repeat_delay: float = 0.22
@export var hold_repeat_interval: float = 0.11
@export var start_lane_angle: float = -PI * 0.5

var _storm: StormTube
var _player: StormPlayer
var _distance: float = 0.0
var _lane_index: int = 0
var _lane_angle: float = -PI * 0.5
var _target_lane_angle: float = -PI * 0.5
var _speed: float
var _held_lane_direction: int = 0
var _hold_repeat_timer: float = 0.0
var _input_enabled: bool = true
var _move_audio: AudioStreamPlayer

func _ready() -> void:
	_storm = get_node(storm_path) as StormTube
	_player = get_node(player_path) as StormPlayer
	_ensure_audio_bus("Sound")
	_move_audio = AudioStreamPlayer.new()
	_move_audio.stream = MOVE_SOUND
	_move_audio.bus = "Sound"
	_move_audio.volume_db = -24.0
	add_child(_move_audio)
	_speed = starting_speed
	_target_lane_angle = _lane_angle_for_index(_lane_index)
	_lane_angle = _target_lane_angle

func _process(delta: float) -> void:
	if not _input_enabled:
		_update_route_pose()
		return
	if Input.is_key_pressed(KEY_UP):
		_speed = min(_speed + 18.0 * delta, max_speed)
	if Input.is_key_pressed(KEY_DOWN):
		_speed = max(_speed - 18.0 * delta, min_speed)
	_update_lane_input(delta)
	_lane_angle = lerp_angle(_lane_angle, _target_lane_angle, clampf(lane_ease_speed * delta, 0.0, 1.0))
	_distance = min(_distance + _speed * delta, _storm.route_length)
	_update_route_pose()

func restart_run() -> void:
	_distance = 0.0
	_lane_index = 0
	_target_lane_angle = _lane_angle_for_index(_lane_index)
	_lane_angle = _target_lane_angle

func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled

func distance() -> float:
	return _distance

func lane_index() -> int:
	return _lane_index

func lane_angle_for_index(index: int) -> float:
	return _lane_angle_for_index(index)

func speed() -> float:
	return _speed

func _update_route_pose() -> void:
	var here: StormTube.RouteSample = _storm.sample_at_distance(_distance)
	var ahead: StormTube.RouteSample = _storm.sample_at_distance(_distance + 14.0)
	var behind: StormTube.RouteSample = _storm.sample_at_distance(maxf(_distance - camera_distance, 0.0))
	var radial: Vector3 = here.right * cos(_lane_angle) + here.up * sin(_lane_angle)
	var camera_radial: Vector3 = behind.right * cos(_lane_angle) + behind.up * sin(_lane_angle)

	_player.set_route_pose(here, _lane_angle, _storm.radius)
	global_position = behind.position + camera_radial * (_storm.radius * 0.58) + here.up * camera_lift
	look_at(_player.global_position.lerp(ahead.position, 0.35), here.up)

func _update_lane_input(delta: float) -> void:
	var step_direction: int = 0
	if Input.is_action_just_pressed("ui_left"):
		step_direction = -1
	elif Input.is_action_just_pressed("ui_right"):
		step_direction = 1

	if step_direction != 0:
		_step_lane(step_direction)
		_held_lane_direction = step_direction
		_hold_repeat_timer = hold_repeat_delay
		return

	var held_axis: float = Input.get_axis("ui_left", "ui_right")
	var held_direction: int = 0
	if held_axis < -0.5:
		held_direction = -1
	elif held_axis > 0.5:
		held_direction = 1

	if held_direction == 0:
		_held_lane_direction = 0
		_hold_repeat_timer = 0.0
		return

	if held_direction != _held_lane_direction:
		_held_lane_direction = held_direction
		_hold_repeat_timer = hold_repeat_delay
		return

	_hold_repeat_timer -= delta
	if _hold_repeat_timer <= 0.0:
		_step_lane(held_direction)
		_hold_repeat_timer += hold_repeat_interval

func _step_lane(direction: int) -> void:
	_lane_index = wrapi(_lane_index + direction, 0, _storm.lane_count)
	_target_lane_angle = _lane_angle_for_index(_lane_index)
	_move_audio.play()

func _lane_angle_for_index(index: int) -> float:
	return start_lane_angle + TAU * float(index) / float(_storm.lane_count)

func _ensure_audio_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
