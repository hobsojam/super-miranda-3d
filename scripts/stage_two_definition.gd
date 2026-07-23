class_name StageTwoDefinition
extends RefCounted

const CORKSCREW_TURN_COUNT := 16
const CORKSCREW_REVOLUTIONS := 2.5
const CORKSCREW_RADIUS := 26.0
const CORKSCREW_LENGTH := 1220.0

static func route() -> PackedVector3Array:
	# A distinct shape from Stage 1's route so the two stages don't feel like
	# the same tunnel with a different enemy list: a gentle, mostly-straight
	# slope for the first third, a tight corkscrew for the middle third, and
	# an ascending switchback climb for the last third.
	var points: PackedVector3Array = _gentle_slope_points()
	points.append_array(_corkscrew_points(points[points.size() - 1]))
	points.append_array(_climbing_switchback_points(points[points.size() - 1]))
	return points

static func _gentle_slope_points() -> PackedVector3Array:
	return PackedVector3Array(
		[
			Vector3(0.0, 0.0, 0.0),
			Vector3(0.0, -4.0, -80.0),
			Vector3(4.0, -12.0, -220.0),
			Vector3(-3.0, -22.0, -380.0),
			Vector3(6.0, -34.0, -560.0),
			Vector3(-4.0, -48.0, -760.0),
			Vector3(3.0, -64.0, -980.0),
			Vector3(0.0, -82.0, -1220.0),
		]
	)

static func _corkscrew_points(start: Vector3) -> PackedVector3Array:
	var points: PackedVector3Array = PackedVector3Array()
	for i in range(1, CORKSCREW_TURN_COUNT + 1):
		var t: float = float(i) / float(CORKSCREW_TURN_COUNT)
		var angle: float = t * CORKSCREW_REVOLUTIONS * TAU
		var z: float = start.z - t * CORKSCREW_LENGTH
		points.append(
			Vector3(
				CORKSCREW_RADIUS * cos(angle),
				start.y + CORKSCREW_RADIUS * sin(angle),
				z
			)
		)
	return points

static func _climbing_switchback_points(start: Vector3) -> PackedVector3Array:
	return PackedVector3Array(
		[
			start + Vector3(30.0, 22.0, -160.0),
			start + Vector3(-34.0, 52.0, -340.0),
			start + Vector3(38.0, 87.0, -540.0),
			start + Vector3(-30.0, 127.0, -760.0),
			start + Vector3(24.0, 177.0, -990.0),
			start + Vector3(0.0, 232.0, -1260.0),
		]
	)

static func hazards() -> Array[Dictionary]:
	return [
		_hazard(650.0, 1, "flipper"),
		_hazard(780.0, 5, "flipper"),
		_hazard(910.0, 9, "flipper"),
		_hazard(1040.0, 13, "flipper"),
		_hazard(1240.0, 3, "splitter"),
		_hazard(1240.0, 4, "splitter"),
		_hazard(1440.0, 11, "spiker"),
		_hazard(1660.0, 6, "pulsar"),
		_hazard(1810.0, 7, "pulsar"),
		_hazard(1960.0, 8, "pulsar"),
		_hazard(2220.0, 2, "exploder"),
		_hazard(2220.0, 10, "exploder"),
		_hazard(2520.0, 15, "flipper"),
		_hazard(2820.0, 0, "splitter"),
	]

static func pickups() -> Array[Dictionary]:
	return [
		_pickup(1340.0, 4, "purge"),
		_pickup(2350.0, 4, "life"),
	]

static func gate_pairs() -> Array[Dictionary]:
	return [
		_gate_pair(3260.0, 0, 4, 1),
		_gate_pair(3260.0, 8, 12, 2),
		_gate_pair(3500.0, 2, 6, 3),
		_gate_pair(3500.0, 10, 14, 4),
		_gate_pair(3620.0, 5, 10, 5),
	]

static func guide_overdraw_enabled() -> bool:
	return false

static func _hazard(distance: float, lane: int, kind: String) -> Dictionary:
	return {"distance": distance, "lane": lane, "kind": kind}

static func _pickup(distance: float, lane: int, kind: String) -> Dictionary:
	return {"distance": distance, "lane": lane, "kind": kind}

static func _gate_pair(distance: float, start_lane: int, end_lane: int, gate_id: int) -> Dictionary:
	return {
		"distance": distance,
		"start_lane": start_lane,
		"end_lane": end_lane,
		"gate_id": gate_id,
	}
