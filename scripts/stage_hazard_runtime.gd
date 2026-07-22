class_name StageHazardRuntime
extends RefCounted

class Hazard:
	var spawn_distance: float
	var lane: int
	var distance: float
	var kind: String
	var spawned: bool = false
	var cleared: bool = false
	var hit: bool = false
	var anchored: bool = false
	var skill_ready: bool = false
	var pulse_timer: float = 0.0
	var spike_drop_meter: float = 0.0
	var spiker_lane_timer: float = 0.0
	var spiker_lane_direction: int = 1
	var gate_id: int = -1

var _lane_count: int = 16
var _stage_end_distance: float = 1.0
var _hit_window: float = 4.2
var _reveal_distance: float = 520.0
var _pulsar_fire_interval: float = 2.0
var _spiker_lane_step_interval: float = 1.35
var _hazards: Array[Hazard] = []

static func spawn_distance_for(distance: float, reveal_distance: float) -> float:
	return maxf(distance - reveal_distance, 0.0)

static func should_reject_spawn(
	distance: float,
	stage_end_distance: float,
	hit_window: float
) -> bool:
	return distance >= stage_end_distance - hit_window

func setup(
	lane_count: int,
	stage_end_distance: float,
	hit_window: float,
	reveal_distance: float,
	pulsar_fire_interval: float,
	spiker_lane_step_interval: float
) -> void:
	_lane_count = lane_count
	_stage_end_distance = maxf(stage_end_distance, 1.0)
	_hit_window = hit_window
	_reveal_distance = reveal_distance
	_pulsar_fire_interval = pulsar_fire_interval
	_spiker_lane_step_interval = spiker_lane_step_interval

func clear() -> void:
	_hazards.clear()

func all() -> Array[Hazard]:
	return _hazards

func count() -> int:
	return _hazards.size()

func add_hazard(
	distance: float,
	lane: int,
	kind: String,
	gate_id: int = -1,
	spawned: bool = false
) -> Hazard:
	if should_reject_spawn(distance, _stage_end_distance, _hit_window):
		return null
	var hazard: Hazard = Hazard.new()
	hazard.distance = distance
	hazard.spawn_distance = spawn_distance_for(hazard.distance, _reveal_distance)
	hazard.lane = wrapi(lane, 0, _lane_count)
	hazard.kind = kind
	hazard.gate_id = gate_id
	hazard.spawned = spawned
	_init_hazard_skill(hazard)
	_hazards.append(hazard)
	return hazard

func add_gate_pair(distance: float, start_lane: int, end_lane: int, gate_id: int) -> void:
	for gate_part in StageRules.gate_lanes(start_lane, end_lane, _lane_count):
		add_hazard(distance, gate_part["lane"], gate_part["kind"], gate_id)

func spawn_hazard(distance: float, lane: int, kind: String) -> Hazard:
	return add_hazard(distance, lane, kind, -1, true)

func should_activate(hazard: Hazard, player_distance: float) -> bool:
	return not hazard.spawned and player_distance >= hazard.spawn_distance

func should_show(hazard: Hazard, player_distance: float) -> bool:
	return hazard.distance - player_distance < _reveal_distance

func has_passed_player(hazard: Hazard, player_distance: float) -> bool:
	return hazard.distance - player_distance < -_hit_window

func update_closing(delta: float, closing_speed: float) -> void:
	for hazard in _hazards:
		if not hazard.spawned or hazard.cleared:
			continue
		hazard.distance -= closing_speed * delta

func active_pressure(player_distance: float) -> int:
	var count: int = 0
	for hazard in _hazards:
		if hazard.spawned and not hazard.cleared and should_show(hazard, player_distance):
			count += 1
	return count

func _init_hazard_skill(hazard: Hazard) -> void:
	hazard.skill_ready = false
	hazard.pulse_timer = _pulsar_fire_interval
	hazard.spike_drop_meter = 0.0
	hazard.spiker_lane_timer = _spiker_lane_step_interval
	hazard.spiker_lane_direction = 1 if hazard.lane % 2 == 0 else -1
