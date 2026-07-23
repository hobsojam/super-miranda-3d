class_name StageTwoDefinition
extends RefCounted

# This engine's Catmull-Rom uses uniform, index-based parametrization (see
# StormTube._catmull_rom): it assumes each control-point-to-control-point
# step covers roughly equal distance. Feeding it hand-placed segments with
# very different point spacing without equalizing density first can cause
# real overshoot right at the segment boundary (this route used to have a
# tightly-wound corkscrew section that measured 100+ degrees of tangent
# swing in a single sample from exactly that mismatch). ROUTE_STEP
# re-subdivides every segment to roughly the same spacing so the whole
# route parametrizes evenly, even though the current shape is gentle enough
# that it isn't strictly load-bearing anymore - cheap insurance to keep.
const ROUTE_STEP := 12.0

static func route() -> PackedVector3Array:
	# A distinct shape from Stage 1's route so the two stages don't feel like
	# the same tunnel with a different enemy list: a gentle, mostly-straight
	# slope for the first third, a single continuous helical bend to the
	# right and down for the middle third, and an ascending switchback climb
	# for the last third. The middle bend deliberately never completes a
	# full revolution - earlier corkscrew attempts (multiple full turns)
	# made the whole tube roll around the travel axis, which made hazards
	# almost impossible to track against a constantly-rotating reference
	# frame. This is meant to read as one sustained banking turn, not a
	# spiral you rotate through.
	var points: PackedVector3Array = _subdivide(_gentle_slope_points(), ROUTE_STEP)
	points.append_array(_joined_subdivision(points[points.size() - 1], _helix_bend_points))
	points.append_array(_joined_subdivision(points[points.size() - 1], _climbing_switchback_points))
	return points

# Subdivides `segment_points(start)` at ROUTE_STEP, including the seam
# between `start` and the segment's own first point - not just the gaps
# within the segment. Missing that seam specifically (not just under-
# sampling within a segment) has caused two real, measured bugs already:
# a ~92-unit unsubdivided gap and, separately, a ~135-unit one.
static func _joined_subdivision(start: Vector3, segment_points: Callable) -> PackedVector3Array:
	var joined: PackedVector3Array = PackedVector3Array([start])
	joined.append_array(segment_points.call(start))
	return _subdivide(joined, ROUTE_STEP).slice(1)

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

static func _helix_bend_points(start: Vector3) -> PackedVector3Array:
	# One continuous, monotonic bend to the right (x keeps increasing) and
	# down (y keeps decreasing) as the route advances (z keeps decreasing) -
	# no reversal, no wrapping around past a quarter turn's worth of visual
	# banking. Point spacing matches the gentle slope and switchback (~150-
	# 180 z-units apart before _subdivide runs).
	return PackedVector3Array(
		[
			start + Vector3(20.0, -8.0, -150.0),
			start + Vector3(55.0, -20.0, -320.0),
			start + Vector3(100.0, -38.0, -500.0),
			start + Vector3(150.0, -60.0, -680.0),
			start + Vector3(205.0, -86.0, -850.0),
			start + Vector3(260.0, -115.0, -1010.0),
			start + Vector3(315.0, -148.0, -1160.0),
			start + Vector3(365.0, -184.0, -1300.0),
		]
	)

static func _climbing_switchback_points(start: Vector3) -> PackedVector3Array:
	return PackedVector3Array(
		[
			start + Vector3(48.0, 35.2, -256.0),
			start + Vector3(-54.4, 83.2, -544.0),
			start + Vector3(60.8, 139.2, -864.0),
			start + Vector3(-48.0, 203.2, -1216.0),
			start + Vector3(38.4, 283.2, -1584.0),
			start + Vector3(0.0, 371.2, -2016.0),
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
	return 220

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
