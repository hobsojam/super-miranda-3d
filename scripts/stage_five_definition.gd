class_name StageFiveDefinition
extends RefCounted

const ROUTE_STEP := 10.0
const VORTEX_LENGTH := 4650.0
const VORTEX_TURNS := 4.25
const VORTEX_RADIUS := 92.0
const VORTEX_END_RADIUS := 30.0

static func route() -> PackedVector3Array:
	var route_points: PackedVector3Array = _subdivide(
		PackedVector3Array(
			[
				Vector3(0.0, 0.0, 0.0),
				Vector3(0.0, 0.0, -180.0),
				Vector3(0.0, 0.0, -420.0),
			]
		),
		ROUTE_STEP
	)
	route_points.append_array(_vortex_points(route_points[-1]))
	return route_points

static func hazards() -> Array[Dictionary]:
	return [
		# Phase 1: clear approach to the vortex.

		# Phase 2: the first two storm fronts stand alone.
		_hazard(1280.0, 7, "flipper"),

		# Phase 3: moving openings combine with familiar enemy roles.
		_hazard(1510.0, 2, "spiker"),
		_hazard(1670.0, 11, "pulsar"),
		_hazard(1850.0, 5, "splitter"),
		_hazard(2040.0, 14, "flipper"),
		_hazard(2200.0, 8, "exploder"),
		_hazard(2380.0, 1, "pulsar"),
		_hazard(2380.0, 10, "spiker"),
		_hazard(2570.0, 4, "splitter"),
		_hazard(2730.0, 13, "exploder"),

		# Phase 4: the eye of the storm.
		_hazard(3040.0, 8, "flipper"),

		# Phase 5: the tightening core combines every pressure type.
		_hazard(3400.0, 3, "pulsar"),
		_hazard(3400.0, 12, "spiker"),
		_hazard(3610.0, 6, "splitter"),
		_hazard(3610.0, 15, "exploder"),
		_hazard(3830.0, 1, "flipper"),
		_hazard(3830.0, 9, "pulsar"),
		_hazard(4050.0, 5, "spiker"),
		_hazard(4050.0, 13, "splitter"),
		_hazard(4270.0, 2, "exploder"),
		_hazard(4270.0, 8, "pulsar"),
		_hazard(4270.0, 15, "flipper"),
		_hazard(4490.0, 4, "splitter"),
		_hazard(4490.0, 11, "spiker"),
		_hazard(4700.0, 7, "exploder"),
		_hazard(4700.0, 14, "pulsar"),
	]

static func storm_fronts() -> Array[Dictionary]:
	return [
		# Phase 2: wide openings and slow, opposing rotation.
		_front(760.0, 5, 0.0, 0.18),
		_front(1080.0, 5, 8.0, -0.22),

		# Phase 3: rotation accelerates before the first narrow opening.
		_front(1480.0, 5, 3.0, 0.26),
		_front(1810.0, 5, 12.0, -0.30),
		_front(2150.0, 5, 6.0, 0.34),
		_front(2510.0, 3, 1.0, -0.30),

		# Phase 4 intentionally leaves a long clear eye.

		# Phase 5: narrow openings alternate direction through the core.
		_front(3350.0, 5, 9.0, 0.38),
		_front(3690.0, 3, 2.0, -0.36),
		_front(4030.0, 3, 13.0, 0.42),
		_front(4370.0, 3, 5.0, -0.46),
		_front(4710.0, 3, 10.0, 0.50),
	]

static func environmental_hazards() -> Array[Dictionary]:
	return []

static func pickups() -> Array[Dictionary]:
	return [
		_pickup(2670.0, 6, "purge"),
		_pickup(3150.0, 8, "life"),
	]

static func gate_pairs() -> Array[Dictionary]:
	return []

static func guide_overdraw_enabled() -> bool:
	return false

static func ring_samples() -> int:
	return 650

static func _vortex_points(start: Vector3) -> PackedVector3Array:
	var points: PackedVector3Array = PackedVector3Array()
	var fine_steps: int = 6000
	var last_sample: Vector3 = start
	var accumulated: float = 0.0
	for index in range(1, fine_steps + 1):
		var progress: float = float(index) / float(fine_steps)
		var ramp_progress: float = clampf(progress / 0.10, 0.0, 1.0)
		var ramp: float = ramp_progress * ramp_progress * (3.0 - 2.0 * ramp_progress)
		var shrink_progress: float = clampf((progress - 0.10) / 0.90, 0.0, 1.0)
		var shrink: float = shrink_progress * shrink_progress * (3.0 - 2.0 * shrink_progress)
		var radius: float = lerpf(VORTEX_RADIUS, VORTEX_END_RADIUS, shrink) * ramp
		var angle: float = progress * VORTEX_TURNS * TAU
		var candidate: Vector3 = start + Vector3(
			radius * (cos(angle) - 1.0),
			radius * sin(angle),
			-VORTEX_LENGTH * progress
		)
		accumulated += last_sample.distance_to(candidate)
		last_sample = candidate
		if accumulated >= ROUTE_STEP or index == fine_steps:
			points.append(candidate)
			accumulated = 0.0
	return points

static func _subdivide(points: PackedVector3Array, step: float) -> PackedVector3Array:
	var result: PackedVector3Array = PackedVector3Array([points[0]])
	for index in range(1, points.size()):
		var start: Vector3 = points[index - 1]
		var end: Vector3 = points[index]
		var steps: int = maxi(1, int(ceil(start.distance_to(end) / step)))
		for subdivision in range(1, steps + 1):
			result.append(start.lerp(end, float(subdivision) / float(steps)))
	return result

static func _hazard(distance: float, lane: int, kind: String) -> Dictionary:
	return {"distance": distance, "lane": lane, "kind": kind}

static func _pickup(distance: float, lane: int, kind: String) -> Dictionary:
	return {"distance": distance, "lane": lane, "kind": kind}

static func _front(
	distance: float,
	opening_lanes: int,
	phase_lane: float,
	lanes_per_second: float
) -> Dictionary:
	return {
		"distance": distance,
		"opening_lanes": opening_lanes,
		"phase_lane": phase_lane,
		"lanes_per_second": lanes_per_second,
	}
