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
	# turns more than roughly 35-55 degrees off the forward axis at an
	# apex (see the ring_samples note on how much render resolution that
	# actually costs). The route also carries a steady net descent
	# (roughly 680 units by the end, steepening through the climax) so it
	# reads as a downhill run, the way a real slalom course is - distinct
	# from Stage 2's descend-then-climb shape.
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
	#
	# Forward spacing between apexes is deliberately much shorter than
	# amplitude here (period ~110-140 against amplitude ~55-155, versus the
	# first pass's ~220-260 period against similar amplitude) - playtesting
	# the first version showed it read as "long stretches of straight road
	# with occasional bends," not a continuous weave. With Catmull-Rom
	# tangents built from a point's two same-side neighbors (roughly
	# (next-prev)/2), a wide, gentle zigzag lets the curve flatten out
	# through each apex and only really bend in the gaps between them; a
	# tight zigzag forces real, continuous curvature everywhere instead.
	return PackedVector3Array(
		[
			# Phase 2 (introduce): the weave itself is the new idea here,
			# not an enemy - amplitude ramps 55 -> 100 so the bend is still
			# readable on the first few swings, but the period is already
			# tight enough that it never goes flat.
			start + Vector3(44.0, 14.0, -112.0),
			start + Vector3(-60.0, 29.0, -224.0),
			start + Vector3(72.0, 43.0, -336.0),
			start + Vector3(-80.0, 58.0, -448.0),
			# Phase 3 (escalate): tighter period still, amplitude ramps
			# 92 -> 112.
			start + Vector3(92.0, 78.0, -536.0),
			start + Vector3(-98.0, 99.0, -624.0),
			start + Vector3(102.0, 120.0, -712.0),
			start + Vector3(-107.0, 141.0, -800.0),
			start + Vector3(112.0, 162.0, -888.0),
			# Phase 4 (false summit): one easier, wider-period recovery
			# swing - the one deliberate breather in the weave.
			start + Vector3(-60.0, 178.0, -1032.0),
			# Phase 5 (climax): tightest period of all, amplitude alternates
			# high/low for an irregular, chicane-like rhythm, grade
			# steepens toward the finish.
			start + Vector3(120.0, 206.0, -1104.0),
			start + Vector3(-108.0, 236.0, -1176.0),
			start + Vector3(124.0, 269.0, -1248.0),
			start + Vector3(-104.0, 304.0, -1320.0),
			start + Vector3(120.0, 342.0, -1392.0),
			start + Vector3(-112.0, 382.0, -1464.0),
			start + Vector3(124.0, 424.0, -1536.0),
			start + Vector3(-108.0, 469.0, -1608.0),
			start + Vector3(120.0, 516.0, -1680.0),
			start + Vector3(-112.0, 566.0, -1752.0),
			start + Vector3(120.0, 618.0, -1824.0),
			# Finish straight: recenters before the route ends rather than
			# stopping mid-swing.
			start + Vector3(0.0, 642.0, -1920.0),
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
	# an arbitrary round number. Every apex through phase 5 carries at
	# least one hazard now (the first pass left long gaps between apexes,
	# which combined with the wide, gentle geometry that pass also had -
	# see the note on _weave_points - to read as empty and easy).
	return [
		# Phase 2 (650-1700ish): one hazard per apex, still solo kinds - the
		# weave itself is what's new here, not enemy combinations.
		_hazard(770.0, 2, "flipper"),
		_hazard(930.0, 11, "flipper"),
		_hazard(1100.0, 13, "splitter"),
		_hazard(1290.0, 7, "flipper"),
		# Phase 3 (1700-2600ish): known kinds combine at every apex.
		_hazard(1480.0, 5, "flipper"),
		_hazard(1480.0, 6, "spiker"),
		_hazard(1690.0, 9, "splitter"),
		_hazard(1910.0, 3, "flipper"),
		_hazard(1910.0, 14, "spiker"),
		_hazard(2140.0, 8, "splitter"),
		_hazard(2140.0, 1, "pulsar"),
		_hazard(2380.0, 10, "spiker"),
		_hazard(2380.0, 4, "splitter"),
		# Phase 4 (2600-2800ish): one easy beat before the reward - the one
		# deliberate breather, same as the false-summit swing itself.
		_hazard(2600.0, 7, "flipper"),
		# Phase 5 (2800-4510ish): highest density, mixed kinds, often two
		# per apex; the last three apexes are reserved for the gate
		# gauntlet below rather than mixed with more hazards.
		_hazard(2800.0, 1, "pulsar"),
		_hazard(3040.0, 10, "exploder"),
		_hazard(3290.0, 6, "spiker"),
		_hazard(3290.0, 12, "splitter"),
		_hazard(3530.0, 3, "pulsar"),
		_hazard(3770.0, 9, "exploder"),
		_hazard(3770.0, 15, "spiker"),
		_hazard(4010.0, 2, "splitter"),
		_hazard(4260.0, 7, "pulsar"),
		_hazard(4260.0, 13, "exploder"),
		_hazard(4510.0, 5, "spiker"),
	]

static func pickups() -> Array[Dictionary]:
	return [
		_pickup(2650.0, 4, "life"),
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
		_gate_pair(4750.0, 0, 4, 1),
		_gate_pair(4750.0, 8, 12, 2),
		_gate_pair(5000.0, 2, 6, 3),
		_gate_pair(5000.0, 10, 14, 4),
		_gate_pair(5250.0, 5, 10, 5),
	]

static func guide_overdraw_enabled() -> bool:
	return false

static func ring_samples() -> int:
	# The weave's amplitude-to-period ratio is much higher than Stage 1's
	# gentle bends or even Stage 2's switchback, so real curvature is packed
	# far more densely per unit distance. 1600 still left samples in the
	# high 40s/low 50s at the tightest phase-5 apexes (aliasing, not real
	# geometry - measured turn dropped from ~52 degrees to ~34 once
	# resolution was high enough), so this needs to go well past what any
	# other stage requires.
	return 2400

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
