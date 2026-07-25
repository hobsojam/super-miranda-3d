class_name StageEnvironmentRuntime
extends RefCounted

enum PulseState {
	INACTIVE,
	WARNING,
	ACTIVE,
}

class ReactorPanel:
	var spawn_distance: float
	var distance: float
	var lane: int
	var phase_offset: float
	var spawned: bool = false
	var cleared: bool = false
	var hit: bool = false

var _lane_count: int = 16
var _hit_window: float = 4.2
var _reveal_distance: float = 520.0
var _pulse_period: float = 2.4
var _active_duration: float = 0.8
var _warning_duration: float = 0.55
var _panels: Array[ReactorPanel] = []

static func spawn_distance_for(distance: float, reveal_distance: float) -> float:
	return maxf(distance - reveal_distance, 0.0)

static func pulse_state_for(
	elapsed_time: float,
	phase_offset: float,
	period: float,
	active_duration: float,
	warning_duration: float
) -> PulseState:
	var safe_period: float = maxf(period, 0.001)
	var cycle_position: float = fposmod(elapsed_time + phase_offset, safe_period)
	if cycle_position < clampf(active_duration, 0.0, safe_period):
		return PulseState.ACTIVE
	if cycle_position >= safe_period - clampf(warning_duration, 0.0, safe_period):
		return PulseState.WARNING
	return PulseState.INACTIVE

func setup(
	lane_count: int,
	hit_window: float,
	reveal_distance: float,
	pulse_period: float,
	active_duration: float,
	warning_duration: float
) -> void:
	_lane_count = lane_count
	_hit_window = hit_window
	_reveal_distance = reveal_distance
	_pulse_period = pulse_period
	_active_duration = active_duration
	_warning_duration = warning_duration

func clear() -> void:
	_panels.clear()

func all() -> Array[ReactorPanel]:
	return _panels

func count() -> int:
	return _panels.size()

func active_pressure(player_distance: float, panels_per_pressure: int = 4) -> int:
	var visible_panels: int = 0
	for panel in _panels:
		if (
			panel.spawned
			and not panel.cleared
			and should_show(panel, player_distance)
			and not has_passed_player(panel, player_distance)
		):
			visible_panels += 1
	return ceili(float(visible_panels) / float(maxi(panels_per_pressure, 1)))

func add_panel(distance: float, lane: int, phase_offset: float) -> ReactorPanel:
	var panel: ReactorPanel = ReactorPanel.new()
	panel.distance = distance
	panel.spawn_distance = spawn_distance_for(distance, _reveal_distance)
	panel.lane = wrapi(lane, 0, _lane_count)
	panel.phase_offset = phase_offset
	_panels.append(panel)
	return panel

func should_activate(panel: ReactorPanel, player_distance: float) -> bool:
	return not panel.spawned and player_distance >= panel.spawn_distance

func should_show(panel: ReactorPanel, player_distance: float) -> bool:
	return panel.distance - player_distance <= _reveal_distance

func has_passed_player(panel: ReactorPanel, player_distance: float) -> bool:
	return panel.distance - player_distance < -_hit_window

func pulse_state(panel: ReactorPanel, elapsed_time: float) -> PulseState:
	return pulse_state_for(
		elapsed_time,
		panel.phase_offset,
		_pulse_period,
		_active_duration,
		_warning_duration
	)

func can_damage(
	panel: ReactorPanel,
	player_distance: float,
	player_lane: int,
	elapsed_time: float
) -> bool:
	return (
		panel.spawned
		and not panel.cleared
		and not panel.hit
		and panel.lane == player_lane
		and absf(panel.distance - player_distance) <= _hit_window
		and pulse_state(panel, elapsed_time) == PulseState.ACTIVE
	)

func mark_hit(panel: ReactorPanel) -> void:
	panel.hit = true

func clear_panel(panel: ReactorPanel) -> void:
	panel.cleared = true
