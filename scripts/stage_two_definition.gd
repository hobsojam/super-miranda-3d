class_name StageTwoDefinition
extends RefCounted

const CORKSCREW_REVOLUTIONS := 25.0
const CORKSCREW_RADIUS := 14.0
const CORKSCREW_LENGTH := 1220.0
const ROUTE_RING_SAMPLES := 640

# This engine's Catmull-Rom uses uniform, index-based parametrization (see
# StormTube._catmull_rom): it assumes each control-point-to-control-point
# step covers roughly equal distance. The corkscrew needs far denser points
# than a gentle slope or switchback ever would; feeding those straight into
# one spline without equalizing density causes a severe overshoot right at
# the segment boundary (measured: 100+ degrees of tangent swing in a single
# sample). ROUTE_STEP re-subdivides every segment to roughly the same
# spacing so the whole route parametrizes evenly.
const ROUTE_STEP := 12.0

static func route() -> PackedVector3Array:
	# A distinct shape from Stage 1's route so the two stages don't feel like
	# the same tunnel with a different enemy list: a gentle, mostly-straight
	# slope for the first third, a tight corkscrew for the middle third, and
	# an ascending switchback climb for the last third.
	var points: PackedVector3Array = _subdivide(_gentle_slope_points(), ROUTE_STEP)
	points.append_array(_corkscrew_points(points[points.size() - 1]))
	var corkscrew_end: Vector3 = points[points.size() - 1]
	var switchback: PackedVector3Array = PackedVector3Array([corkscrew_end])
	switchback.append_array(_climbing_switchback_points(corkscrew_end))
	# Slice off the leading point: it's corkscrew_end again, already the last
	# entry in `points`, included here only so _subdivide can smooth this
	# specific seam too (see the ROUTE_STEP comment above for why unequal
	# density between segments matters, not just within them).
	points.append_array(_subdivide(switchback, ROUTE_STEP).slice(1))
	return points

static func _gentle_slope_points() -> PackedVector3Array:
	return PackedVector3Array(
		[
			Vector3(0.0, 0.0, 0.0),
			Vector3(0.0, -2.0, -40.0),
			Vector3(4.0, -6.0, -110.0),
			Vector3(-3.0, -11.0, -190.0),
			Vector3(6.0, -17.0, -280.0),
			Vector3(-4.0, -24.0, -380.0),
			Vector3(3.0, -32.0, -490.0),
			Vector3(0.0, -41.0, -610.0),
		]
	)

static func _corkscrew_points(start: Vector3) -> PackedVector3Array:
	var expected_arc_length: float = sqrt(
		pow(TAU * CORKSCREW_REVOLUTIONS * CORKSCREW_RADIUS, 2.0) + pow(CORKSCREW_LENGTH, 2.0)
	)
	var point_count: int = maxi(1, int(ceil(expected_arc_length / ROUTE_STEP)))
	var points: PackedVector3Array = PackedVector3Array()
	for i in range(1, point_count + 1):
		var t: float = float(i) / float(point_count)
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

static func _subdivide(points: PackedVector3Array, step: float) -> PackedVector3Array:
	var result: PackedVector3Array = PackedVector3Array([points[0]])
	for i in range(1, points.size()):
		var a: Vector3 = points[i - 1]
		var b: Vector3 = points[i]
		var steps: int = maxi(1, int(ceil(a.distance_to(b) / step)))
		for s in range(1, steps + 1):
			result.append(a.lerp(b, float(s) / float(steps)))
	return result

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

static func ring_samples() -> int:
	# The corkscrew alone needs far more resolution than Stage 1's gentle
	# bends to avoid aliasing into a jagged mess at 25 revolutions.
	return ROUTE_RING_SAMPLES

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
