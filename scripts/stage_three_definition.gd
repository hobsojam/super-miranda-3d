class_name StageThreeDefinition
extends RefCounted

# See the note in stage_two_definition.gd on why hand-placed segments need
# consistent point spacing before this engine's uniform, index-based
# Catmull-Rom will parametrize them evenly.
const ROUTE_STEP := 12.0

static func route() -> PackedVector3Array:
	# A slalom: a weave that alternates side to side rather than spiraling
	# (Stage 2's corkscrew) or holding a gentle, mostly-straight line
	# (Stage 1). Built from hand-placed alternating-offset points, the same
	# authoring pattern as Stage 2's switchback, not a parametric formula
	# like the corkscrew - a weave doesn't need arc-length sampling or
	# phase-matching the way a rotating shape does, since nothing here ever
	# turns more than roughly 30-40 degrees off the forward axis. The route
	# also carries a steady net descent (roughly 700 units by the end,
	# steepening through the climax) so it reads as a downhill run, the way
	# a real slalom course is - distinct from Stage 2's descend-then-climb
	# shape.
	var points: PackedVector3Array = _subdivide(_entry_straight_points(), ROUTE_STEP)
	points.append_array(_joined_subdivision(points[points.size() - 1], _weave_points))
	return points

# Subdivides `segment_points(start)` at ROUTE_STEP, including the seam
# between `start` and the segment's own first point - not just the gaps
# within the segment (see the identical helper and its comment in
# stage_two_definition.gd for why the seam specifically matters).
static func _joined_subdivision(start: Vector3, segment_points: Callable) -> PackedVector3Array:
	var joined: PackedVector3Array = PackedVector3Array([start])
	joined.append_array(segment_points.call(start))
	return _subdivide(joined, ROUTE_STEP).slice(1)

static func _entry_straight_points() -> PackedVector3Array:
	# Phase 1 (orientation): near-straight, mirroring Stage 2's gentle slope
	# - the player re-establishes lane control before the weave asks
	# anything of them. +Y reads as screen-down this early in the route
	# (verified the same way as the note in CLAUDE.md's Architecture
	# section on route control-point axes).
	return PackedVector3Array(
		[
			Vector3(0.0, 0.0, 0.0),
			Vector3(0.0, 3.0, -90.0),
			Vector3(-3.0, 7.0, -190.0),
			Vector3(4.0, 13.0, -300.0),
			Vector3(-3.0, 20.0, -420.0),
			Vector3(3.0, 29.0, -540.0),
			Vector3(0.0, 40.0, -650.0),
		]
	)

static func _weave_points(start: Vector3) -> PackedVector3Array:
	# Phases 2-5 as one continuous alternating weave - amplitude and
	# forward spacing both change across phases, but it's mechanically one
	# shape, the same way Stage 2's corkscrew ramp-in is part of one
	# function rather than split out. Lateral sign strictly alternates
	# point to point throughout, including across phase boundaries, so the
	# weave never doubles back on the same side.
	return PackedVector3Array(
		[
			# Phase 2 (introduce): the weave itself is the new idea here,
			# not an enemy - lazy, wide-period swings so the player can
			# learn to read it uncontested. Amplitude ramps 60 -> 90 before
			# scaling (see the scale-down note below).
			start + Vector3(45.0, 19.0, -260.0),
			start + Vector3(-56.0, 37.0, -520.0),
			start + Vector3(67.0, 56.0, -780.0),
			# Phase 3 (escalate): tighter period, amplitude ramps 105 -> 130
			# before scaling.
			start + Vector3(-78.0, 78.0, -1003.0),
			start + Vector3(84.0, 100.0, -1225.0),
			start + Vector3(-90.0, 123.0, -1448.0),
			start + Vector3(95.0, 145.0, -1671.0),
			start + Vector3(-97.0, 167.0, -1894.0),
			# Phase 4 (false summit): one easy, wide recovery swing.
			start + Vector3(52.0, 178.0, -2191.0),
			# Phase 5 (climax): tightest period, amplitude alternates
			# high/low for an irregular, chicane-like rhythm, grade
			# steepens toward the finish.
			start + Vector3(-104.0, 204.0, -2359.0),
			start + Vector3(82.0, 234.0, -2525.0),
			start + Vector3(-100.0, 267.0, -2692.0),
			start + Vector3(85.0, 305.0, -2860.0),
			start + Vector3(-103.0, 345.0, -3027.0),
			start + Vector3(83.0, 390.0, -3193.0),
			start + Vector3(-97.0, 438.0, -3361.0),
			start + Vector3(89.0, 490.0, -3528.0),
			# Finish straight: recenters before the route ends rather than
			# stopping mid-swing.
			start + Vector3(0.0, 531.0, -3677.0),
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
	# Distances are the weave's actual measured apex positions (real arc
	# length, not raw Z - a full-amplitude weave's real travel distance per
	# swing runs noticeably longer than its forward-only offset, unlike the
	# other stages' gentler wobbles), so each hazard lands exactly where
	# the route is already pulling the player toward a lane rather than at
	# an arbitrary round number.
	return [
		# Phase 2 (650-1700ish): solo hazards at the first three apexes,
		# the weave itself being the new idea this phase introduces.
		_hazard(920.0, 2, "flipper"),
		_hazard(1200.0, 11, "flipper"),
		_hazard(1480.0, 13, "splitter"),
		# Phase 3 (1700-3200ish): known kinds combine at successive apexes.
		_hazard(1750.0, 5, "flipper"),
		_hazard(1750.0, 6, "spiker"),
		_hazard(2030.0, 9, "splitter"),
		_hazard(2310.0, 3, "flipper"),
		_hazard(2310.0, 14, "spiker"),
		_hazard(2600.0, 10, "spiker"),
		_hazard(2900.0, 8, "splitter"),
		# Phase 4 (3200-3460ish): one easy beat before the reward.
		_hazard(3230.0, 7, "flipper"),
		# Phase 5 (3460-4720ish): highest density, mixed kinds at each
		# apex; the last three apexes are reserved for the gate gauntlet
		# below rather than mixed with more hazards.
		_hazard(3460.0, 1, "pulsar"),
		_hazard(3710.0, 10, "exploder"),
		_hazard(3960.0, 6, "spiker"),
		_hazard(4210.0, 12, "splitter"),
		_hazard(4470.0, 3, "pulsar"),
	]

static func pickups() -> Array[Dictionary]:
	return [
		_pickup(3300.0, 4, "life"),
		_pickup(4600.0, 4, "purge"),
	]

static func gate_pairs() -> Array[Dictionary]:
	# Two simultaneous-gate choices followed by a single climax gate at the
	# weave's last three apexes, mirroring Stage 2's gate gauntlet shape -
	# gates are Stage 2's mechanic, reused here in a new context (the
	# weave) rather than introduced as a fresh idea. Leaves the finish
	# straight (past the last apex) as a clean run-out with nothing in it,
	# the same way Stage 2 closes out after its last gate.
	return [
		_gate_pair(4720.0, 0, 4, 1),
		_gate_pair(4720.0, 8, 12, 2),
		_gate_pair(4970.0, 2, 6, 3),
		_gate_pair(4970.0, 10, 14, 4),
		_gate_pair(5225.0, 5, 10, 5),
	]

static func guide_overdraw_enabled() -> bool:
	return false

static func ring_samples() -> int:
	return 900

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
