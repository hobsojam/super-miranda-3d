class_name RimObstacleManager
extends RefCounted

class RimObstacle:
	var lane: int
	var kind: String
	var marker: Node3D
	var hop_timer: float = 0.0
	var fuse_timer: float = 0.0
	var stability: float = 1.0

var flipper_hop_interval: float = 0.45
var exploder_fuse_time: float = 0.7

var _storm: StormTube
var _runner: Node
var _obstacles: Array[RimObstacle] = []

static func should_anchor_kind(kind: String) -> bool:
	return kind != "gate_field" and kind != "gate_post"

static func stack_offset(index: int) -> float:
	if index == 0:
		return 0.0
	var side: float = 1.0 if index % 2 == 1 else -1.0
	return side * ceil(float(index) / 2.0) * 0.62

static func step_lane_toward(from_lane: int, target_lane: int, lane_count: int) -> int:
	var diff: int = target_lane - from_lane
	diff = ((diff % lane_count) + lane_count) % lane_count
	if diff > lane_count / 2:
		diff -= lane_count
	if diff == 0:
		return from_lane
	var step: int = 1 if diff > 0 else -1
	return wrapi(from_lane + step, 0, lane_count)

func setup(storm: StormTube, runner: Node, hop_interval: float, fuse_time: float) -> void:
	_storm = storm
	_runner = runner
	flipper_hop_interval = hop_interval
	exploder_fuse_time = fuse_time

func count() -> int:
	return _obstacles.size()

func anchor(lane: int, kind: String) -> void:
	var obstacle: RimObstacle = RimObstacle.new()
	obstacle.lane = lane
	obstacle.kind = kind
	obstacle.hop_timer = flipper_hop_interval
	obstacle.fuse_timer = exploder_fuse_time
	obstacle.marker = _build_obstacle_marker(kind)
	_storm.add_child(obstacle.marker)
	_obstacles.append(obstacle)
	_update_pose(obstacle, _lane_stack_index(obstacle))

func update(delta: float, player_lane: int, speed: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i in range(_obstacles.size() - 1, -1, -1):
		var obstacle: RimObstacle = _obstacles[i]
		var decay_event: Dictionary = _decay_obstacle(obstacle, delta, speed)
		if not decay_event.is_empty():
			_obstacles.remove_at(i)
			events.append(decay_event)
			continue
		match obstacle.kind:
			"flipper":
				obstacle.hop_timer -= delta
				if obstacle.hop_timer <= 0.0:
					obstacle.hop_timer = flipper_hop_interval
					obstacle.lane = step_lane_toward(
						obstacle.lane,
						player_lane,
						_storm.lane_count
					)
			"exploder":
				obstacle.fuse_timer -= delta
				if obstacle.fuse_timer <= 0.0:
					_obstacles.remove_at(i)
					events.append(_remove_event(obstacle, "exploded"))
					continue
		_update_pose(obstacle, _lane_stack_index(obstacle))
	return events

func take_collision(player_lane: int) -> Dictionary:
	for i in range(_obstacles.size() - 1, -1, -1):
		var obstacle: RimObstacle = _obstacles[i]
		if obstacle.lane != player_lane:
			continue
		_obstacles.remove_at(i)
		return _remove_event(obstacle, "collision")
	return {}

func purge() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for obstacle in _obstacles:
		positions.append(obstacle.marker.global_position)
		obstacle.marker.queue_free()
	_obstacles.clear()
	return positions

func clear() -> void:
	for obstacle in _obstacles:
		obstacle.marker.queue_free()
	_obstacles.clear()

func positions() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for obstacle in _obstacles:
		result.append(obstacle.marker.global_position)
	return result

func _decay_obstacle(obstacle: RimObstacle, delta: float, speed: float) -> Dictionary:
	var decay: float = StageRules.anchor_decay_amount(speed, delta)
	if decay <= 0.0:
		return {}
	obstacle.stability -= decay
	var pulse_scale: float = 1.0 + (1.0 - obstacle.stability) * 0.18
	obstacle.marker.scale = Vector3.ONE * 1.15 * pulse_scale
	if obstacle.stability > 0.0:
		return {}
	return _remove_event(obstacle, "decayed")

func _remove_event(obstacle: RimObstacle, event_type: String) -> Dictionary:
	var position: Vector3 = obstacle.marker.global_position
	obstacle.marker.queue_free()
	return {"type": event_type, "kind": obstacle.kind, "position": position}

func _build_obstacle_marker(kind: String) -> Node3D:
	var marker: Node3D = StageMarkerFactory.build_enemy_marker(kind)
	marker.scale = Vector3.ONE * 1.15
	return marker

func _update_pose(obstacle: RimObstacle, stack_index: int) -> void:
	var sample: StormTube.RouteSample = _storm.sample_at_distance(_runner.distance() + 1.8)
	var lane_angle: float = _runner.lane_angle_for_index(obstacle.lane)
	var radial: Vector3 = sample.right * cos(lane_angle) + sample.up * sin(lane_angle)
	var forward: Vector3 = sample.tangent.normalized()
	var side: Vector3 = radial.cross(forward).normalized()
	var side_offset: float = stack_offset(stack_index)
	obstacle.marker.global_position = (
		sample.position
		+ radial * (_storm.radius * 0.86)
		+ side * side_offset
	)
	obstacle.marker.global_basis = Basis(side, radial, -forward).orthonormalized()
	StageMarkerFactory.animate_enemy_art(obstacle.marker, obstacle.kind)

func _lane_stack_index(obstacle: RimObstacle) -> int:
	var index: int = 0
	for other in _obstacles:
		if other == obstacle:
			return index
		if other.lane == obstacle.lane:
			index += 1
	return index
