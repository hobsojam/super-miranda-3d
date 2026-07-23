class_name EnemySkillRuntime
extends RefCounted

var _lane_count: int = 16
var _hit_window: float = 4.2
var _spiker_retreat_speed: float = 7.0
var _spiker_drop_spacing: float = 70.0
var _spiker_lane_step_interval: float = 1.35
var _pulsar_fire_interval: float = 2.0

func setup(
	lane_count: int,
	hit_window: float,
	spiker_retreat_speed: float,
	spiker_drop_spacing: float,
	spiker_lane_step_interval: float,
	pulsar_fire_interval: float
) -> void:
	_lane_count = lane_count
	_hit_window = hit_window
	_spiker_retreat_speed = spiker_retreat_speed
	_spiker_drop_spacing = spiker_drop_spacing
	_spiker_lane_step_interval = spiker_lane_step_interval
	_pulsar_fire_interval = pulsar_fire_interval

func update(
	hazard: StageHazardRuntime.Hazard,
	delta: float,
	player_distance: float,
	stage_end_distance: float
) -> Dictionary:
	match hazard.kind:
		"spiker":
			return _update_spiker(hazard, delta, player_distance, stage_end_distance)
		"pulsar":
			return _update_pulsar(hazard, delta)
	return {}

func _update_spiker(
	hazard: StageHazardRuntime.Hazard,
	delta: float,
	player_distance: float,
	stage_end_distance: float
) -> Dictionary:
	var travel: float = _spiker_retreat_speed * delta
	hazard.distance += travel
	if hazard.distance >= stage_end_distance - _hit_window:
		hazard.cleared = true
		return {"type": "cleared"}
	hazard.spike_drop_meter += travel
	hazard.spiker_lane_timer -= delta
	if hazard.spiker_lane_timer <= 0.0:
		hazard.spiker_lane_timer = _spiker_lane_step_interval
		hazard.lane = wrapi(hazard.lane + hazard.spiker_lane_direction, 0, _lane_count)
		hazard.spiker_lane_direction *= -1
	if hazard.spike_drop_meter >= _spiker_drop_spacing:
		hazard.spike_drop_meter -= _spiker_drop_spacing
		var drop_distance: float = hazard.distance - _spiker_drop_spacing
		if drop_distance > player_distance + _hit_window:
			return {"type": "spike_drop", "distance": drop_distance, "lane": hazard.lane}
	return {}

func _update_pulsar(hazard: StageHazardRuntime.Hazard, delta: float) -> Dictionary:
	hazard.pulse_timer -= delta
	if hazard.pulse_timer > 0.0:
		return {}
	hazard.pulse_timer = _pulsar_fire_interval
	return {"type": "fire_bolt", "lane": hazard.lane, "distance": hazard.distance}
