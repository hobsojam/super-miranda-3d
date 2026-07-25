class_name StageStormFrontRuntime
extends RefCounted

class StormFront:
	var spawn_distance: float
	var distance: float
	var opening_lanes: int
	var phase_lane: float
	var lanes_per_second: float
	var spawned: bool = false
	var cleared: bool = false
	var hit: bool = false

var _lane_count: int = 16
var _hit_window: float = 4.2
var _reveal_distance: float = 620.0
var _fronts: Array[StormFront] = []

static func opening_center_for(
	elapsed_time: float,
	phase_lane: float,
	lanes_per_second: float,
	lane_count: int
) -> float:
	return fposmod(phase_lane + elapsed_time * lanes_per_second, float(lane_count))

static func circular_lane_distance(lane: int, center_lane: float, lane_count: int) -> float:
	var difference: float = absf(float(lane) - center_lane)
	return minf(difference, float(lane_count) - difference)

static func lane_is_safe(
	lane: int,
	center_lane: float,
	opening_lanes: int,
	lane_count: int
) -> bool:
	var half_width: int = maxi(opening_lanes, 1) / 2
	return circular_lane_distance(lane, center_lane, lane_count) <= float(half_width)

func setup(lane_count: int, hit_window: float, reveal_distance: float) -> void:
	_lane_count = lane_count
	_hit_window = hit_window
	_reveal_distance = reveal_distance

func clear() -> void:
	_fronts.clear()

func all() -> Array[StormFront]:
	return _fronts

func count() -> int:
	return _fronts.size()

func add_front(
	distance: float,
	opening_lanes: int,
	phase_lane: float,
	lanes_per_second: float
) -> StormFront:
	var front: StormFront = StormFront.new()
	front.distance = distance
	front.spawn_distance = maxf(distance - _reveal_distance, 0.0)
	front.opening_lanes = opening_lanes
	front.phase_lane = phase_lane
	front.lanes_per_second = lanes_per_second
	_fronts.append(front)
	return front

func should_activate(front: StormFront, player_distance: float) -> bool:
	return not front.spawned and player_distance >= front.spawn_distance

func should_show(front: StormFront, player_distance: float) -> bool:
	return front.distance - player_distance <= _reveal_distance

func has_passed_player(front: StormFront, player_distance: float) -> bool:
	return front.distance - player_distance < -_hit_window

func opening_center(front: StormFront, elapsed_time: float) -> float:
	return opening_center_for(
		elapsed_time,
		front.phase_lane,
		front.lanes_per_second,
		_lane_count
	)

func can_damage(
	front: StormFront,
	player_distance: float,
	player_lane: int,
	elapsed_time: float
) -> bool:
	return (
		front.spawned
		and not front.cleared
		and not front.hit
		and absf(front.distance - player_distance) <= _hit_window
		and not lane_is_safe(
			player_lane,
			opening_center(front, elapsed_time),
			front.opening_lanes,
			_lane_count
		)
	)

func active_pressure(player_distance: float) -> int:
	var pressure: int = 0
	for front in _fronts:
		if (
			front.spawned
			and not front.cleared
			and should_show(front, player_distance)
			and not has_passed_player(front, player_distance)
		):
			pressure += 1
	return pressure

func mark_hit(front: StormFront) -> void:
	front.hit = true

func clear_front(front: StormFront) -> void:
	front.cleared = true
