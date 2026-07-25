class_name StageFourDefinition
extends RefCounted

const ROUTE_STEP := 12.0

static func route() -> PackedVector3Array:
	# Stage 4 deliberately gives the player long sightlines. The tube climbs
	# through a broad reactor shaft, but its gentle lateral drift never hides
	# the charged lane bands that define the stage.
	return _subdivide(
		PackedVector3Array(
			[
				Vector3(0.0, 0.0, 0.0),
				Vector3(0.0, -5.0, -120.0),
				Vector3(8.0, -18.0, -300.0),
				Vector3(-10.0, -40.0, -520.0),
				Vector3(14.0, -68.0, -760.0),
				Vector3(-16.0, -100.0, -1010.0),
				Vector3(18.0, -136.0, -1270.0),
				Vector3(-20.0, -176.0, -1540.0),
				Vector3(16.0, -220.0, -1820.0),
				Vector3(-12.0, -268.0, -2110.0),
				Vector3(10.0, -320.0, -2410.0),
				Vector3(-8.0, -376.0, -2720.0),
				Vector3(12.0, -436.0, -3040.0),
				Vector3(-14.0, -500.0, -3370.0),
				Vector3(10.0, -568.0, -3710.0),
				Vector3(0.0, -640.0, -4060.0),
				Vector3(0.0, -688.0, -4320.0),
			]
		),
		ROUTE_STEP
	)

static func hazards() -> Array[Dictionary]:
	return [
		# Phase 1 (0-560): empty orientation runway.

		# Phase 2 (~560-1300): reactor panels debut alone at 720 and 950.
		# One familiar flipper follows only after both patterns have been seen.
		_hazard(1210.0, 8, "flipper"),

		# Phase 3 (~1350-2650): known enemies combine with alternating bands.
		_hazard(1480.0, 5, "spiker"),
		_hazard(1640.0, 12, "flipper"),
		_hazard(1810.0, 2, "splitter"),
		_hazard(1990.0, 9, "pulsar"),
		_hazard(2180.0, 4, "spiker"),
		_hazard(2180.0, 13, "flipper"),
		_hazard(2400.0, 7, "splitter"),
		_hazard(2400.0, 15, "pulsar"),
		_hazard(2580.0, 10, "exploder"),

		# Phase 4 (~2700-3050): powered-down breather and reward beat.
		_hazard(2820.0, 6, "flipper"),

		# Phase 5 (~3100-4200): highest combined pressure. The final pulse
		# band is the capstone, so there is no recycled gate gauntlet.
		_hazard(3180.0, 1, "pulsar"),
		_hazard(3180.0, 11, "spiker"),
		_hazard(3400.0, 4, "exploder"),
		_hazard(3400.0, 13, "flipper"),
		_hazard(3620.0, 7, "splitter"),
		_hazard(3620.0, 15, "pulsar"),
		_hazard(3830.0, 2, "spiker"),
		_hazard(3830.0, 9, "exploder"),
		_hazard(3830.0, 14, "flipper"),
		_hazard(4040.0, 5, "pulsar"),
		_hazard(4040.0, 10, "splitter"),
		_hazard(4040.0, 15, "exploder"),
	]

static func environmental_hazards() -> Array[Dictionary]:
	var panels: Array[Dictionary] = []

	# Phase 2: small, isolated blocks with generous safe space.
	_add_band(panels, 720.0, [2, 3, 4, 5], 0.0)
	_add_band(panels, 950.0, [10, 11, 12, 13], 1.2)

	# Phase 3: complementary halves and alternating-lane patterns.
	_add_band(panels, 1420.0, [0, 1, 2, 3, 8, 9, 10, 11], 0.0)
	_add_band(panels, 1720.0, [4, 5, 6, 7, 12, 13, 14, 15], 1.2)
	_add_band(panels, 2040.0, [0, 2, 4, 6, 8, 10, 12, 14], 0.6)
	_add_band(panels, 2360.0, [1, 3, 5, 7, 9, 11, 13, 15], 1.8)
	_add_band(panels, 2580.0, [0, 1, 2, 3, 4, 8, 9, 10, 11, 12], 0.0)

	# Phase 4 intentionally has no reactor bands.

	# Phase 5: quicker visual alternation, always leaving at least six safe
	# lanes until the four-lane final shutdown corridor.
	_add_band(panels, 3160.0, [0, 1, 2, 3, 8, 9, 10, 11], 0.0)
	_add_band(panels, 3380.0, [4, 5, 6, 7, 12, 13, 14, 15], 1.2)
	_add_band(panels, 3600.0, [0, 2, 4, 6, 8, 10, 12, 14], 0.6)
	_add_band(panels, 3810.0, [0, 1, 5, 6, 7, 8, 9, 13, 14, 15], 1.8)
	_add_band(panels, 4020.0, [2, 3, 4, 7, 8, 9, 10, 12, 13, 14], 0.0)
	_add_band(panels, 4180.0, [0, 1, 2, 5, 6, 7, 8, 9, 10, 13, 14, 15], 1.2)
	return panels

static func pickups() -> Array[Dictionary]:
	return [
		_pickup(2260.0, 6, "purge"),
		_pickup(2920.0, 4, "life"),
	]

static func gate_pairs() -> Array[Dictionary]:
	return []

static func guide_overdraw_enabled() -> bool:
	return false

static func ring_samples() -> int:
	return 520

static func _subdivide(points: PackedVector3Array, step: float) -> PackedVector3Array:
	var result: PackedVector3Array = PackedVector3Array([points[0]])
	for i in range(1, points.size()):
		var a: Vector3 = points[i - 1]
		var b: Vector3 = points[i]
		var steps: int = maxi(1, int(ceil(a.distance_to(b) / step)))
		for s in range(1, steps + 1):
			result.append(a.lerp(b, float(s) / float(steps)))
	return result

static func _hazard(distance: float, lane: int, kind: String) -> Dictionary:
	return {"distance": distance, "lane": lane, "kind": kind}

static func _pickup(distance: float, lane: int, kind: String) -> Dictionary:
	return {"distance": distance, "lane": lane, "kind": kind}

static func _add_band(
	panels: Array[Dictionary],
	distance: float,
	lanes: Array,
	phase_offset: float
) -> void:
	for lane in lanes:
		panels.append(
			{"distance": distance, "lane": int(lane), "phase_offset": phase_offset}
		)
