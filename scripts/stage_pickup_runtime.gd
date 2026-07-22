class_name StagePickupRuntime
extends RefCounted

class Pickup:
	var spawn_distance: float
	var lane: int
	var distance: float
	var kind: String
	var spawned: bool = false
	var cleared: bool = false

var _lane_count: int = 16
var _hit_window: float = 4.2
var _reveal_distance: float = 520.0
var _pickups: Array[Pickup] = []

static func spawn_distance_for(distance: float, reveal_distance: float) -> float:
	return maxf(distance - reveal_distance, 0.0)

func setup(lane_count: int, hit_window: float, reveal_distance: float) -> void:
	_lane_count = lane_count
	_hit_window = hit_window
	_reveal_distance = reveal_distance

func clear() -> void:
	_pickups.clear()

func all() -> Array[Pickup]:
	return _pickups

func count() -> int:
	return _pickups.size()

func add_pickup(distance: float, lane: int, kind: String) -> Pickup:
	var pickup: Pickup = Pickup.new()
	pickup.distance = distance
	pickup.spawn_distance = spawn_distance_for(pickup.distance, _reveal_distance)
	pickup.lane = wrapi(lane, 0, _lane_count)
	pickup.kind = kind
	_pickups.append(pickup)
	return pickup

func should_activate(pickup: Pickup, player_distance: float) -> bool:
	return not pickup.spawned and player_distance >= pickup.spawn_distance

func activate(pickup: Pickup) -> void:
	pickup.spawned = true

func should_show(pickup: Pickup, player_distance: float) -> bool:
	return pickup.distance - player_distance < _reveal_distance

func has_passed_player(pickup: Pickup, player_distance: float) -> bool:
	return pickup.distance - player_distance < -_hit_window

func can_collect(pickup: Pickup, player_distance: float, player_lane: int) -> bool:
	return absf(pickup.distance - player_distance) <= _hit_window and pickup.lane == player_lane

func clear_pickup(pickup: Pickup) -> void:
	pickup.cleared = true
