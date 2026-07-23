class_name StageTwoDefinition
extends RefCounted

# This engine's Catmull-Rom uses uniform, index-based parametrization (see
# StormTube._catmull_rom): it assumes each control-point-to-control-point
# step covers roughly equal distance. Feeding it hand-placed segments with
# very different point spacing without equalizing density first can cause
# real overshoot right at the segment boundary (the corkscrew below is far
# denser than the gentle slope or switchback; without equalizing, this
# measured 100+ degrees of tangent swing in a single sample). ROUTE_STEP
# re-subdivides every segment to roughly the same spacing so the whole
# route parametrizes evenly.
const ROUTE_STEP := 12.0

const CORKSCREW_REVOLUTIONS := 8.0
# Radius 75 (diameter 150) with this arc length gives ~100 units of descent
# per loop - a middle ground between the original tight-drill proportions
# (diameter 40, ~280/loop) and a flat, snake-like coil (diameter 280,
# ~40/loop), which would have required tripling the route's length.
const CORKSCREW_RADIUS := 75.0
# The corkscrew's travel distance (arc length), held fixed regardless of how
# many revolutions or what radius it's tuned to. Distance is what hazards,
# gates, and stage pacing are actually keyed to, so retuning how tightly it
# winds shouldn't silently change how far the stage is - a looser coil of
# the same wire length just spans more downward space. The descent depth
# is derived from this and the current revolutions/radius, not the other
# way around (see _corkscrew_points).
const CORKSCREW_ARC_LENGTH := 3854.0
# How many of the leading revolutions ease the radius AND descent rate in
# from 0 to full, smoothstep-eased, instead of snapping straight to full
# amplitude/speed - avoids a sudden, large tangent swing right at the
# gentle-slope handoff (see _corkscrew_points for why both need easing).
# Shorter is better here, counterintuitively: measured max tangent swing
# across the whole route was 27.6 degrees at 0.5, but rose to 70.4 degrees
# at 2.0 revolutions - a longer ramp holds the path closer to the seam
# tangent for longer before the coil's own curvature takes over, which
# sharpens the handoff once it does rather than softening it.
const CORKSCREW_RAMP_REVOLUTIONS := 0.5
const CORKSCREW_RING_SAMPLES := 640

static func route() -> PackedVector3Array:
	# A distinct shape from Stage 1's route so the two stages don't feel like
	# the same tunnel with a different enemy list: a gentle, mostly-straight
	# slope for the first third, a genuine multi-revolution corkscrew for
	# the middle third, and an ascending switchback climb for the last
	# third. The corkscrew coils around a downward axis rather than the
	# direction of travel - a snake coiled on the ground, not a drill bit
	# boring straight ahead - so the incoming forward direction actually
	# loops back over itself each revolution instead of just spiraling
	# further away (see _corkscrew_points). A real spiral also necessarily
	# rotates the camera's screen-relative "up"/"right" through a full turn
	# once per revolution - that's not a bug to fix, it's what a corkscrew
	# is; see the CLAUDE.md Architecture note on route control-point axes
	# for how that interacts with this engine's rotation-minimizing camera
	# frame.
	var points: PackedVector3Array = _subdivide(_gentle_slope_points(), ROUTE_STEP)
	# _corkscrew_points does its own arc-length-based spacing internally
	# (see its comment) rather than going through _subdivide/
	# _joined_subdivision like the other segments - the ramp-in's radius
	# growing from 0 means physical speed varies a lot across the segment,
	# which uniform-t sampling (what _subdivide assumes) doesn't handle.
	points.append_array(_corkscrew_points(points[points.size() - 1]))
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
	# +Y here reads as screen-DOWN this early in the route (verified against
	# the camera's actual look_at basis, same as the note on route
	# control-point axes in CLAUDE.md) - -Y would read as climbing, not
	# descending.
	return PackedVector3Array(
		[
			Vector3(0.0, 0.0, 0.0),
			Vector3(0.0, 2.0, -40.0),
			Vector3(4.0, 6.0, -110.0),
			Vector3(-3.0, 11.0, -190.0),
			Vector3(6.0, 17.0, -280.0),
			Vector3(-4.0, 24.0, -380.0),
			Vector3(3.0, 32.0, -490.0),
			Vector3(0.0, 41.0, -610.0),
		]
	)

static func _corkscrew_points(start: Vector3) -> PackedVector3Array:
	# Coils around a DOWNWARD axis, not the direction of travel: loops lie
	# in the horizontal-ish x/z plane and stack downward as they progress -
	# a snake coiled on the ground, not a drill bit boring straight ahead.
	# y keeps increasing here, not decreasing: verified against the
	# camera's actual look_at basis that +y reads as screen-DOWN this early
	# in the route, same as the note on route control-point axes in
	# CLAUDE.md. z (the incoming forward direction) oscillates back and
	# forth each loop instead of monotonically decreasing, so the path
	# genuinely loops back over where it's already been, the way a coiled
	# body loops back over its own earlier coils.
	#
	# Sampled by actual arc length, not by uniform steps in t/angle: during
	# the ramp-in, radius grows from 0, so physical speed varies a lot
	# across the segment (near-stationary at the very start, full speed once
	# the ramp completes). Uniform-t sampling put many points on top of each
	# other in real space during the ramp despite their angle differing a
	# lot - measured as a genuinely unstable spline fit (a 0.3-unit step
	# paired with a 120+ degree tangent swing), not just uneven spacing.
	# Walking a fine parametric sampling and only emitting a point once
	# accumulated real distance reaches ROUTE_STEP fixes this at the source.
	var circumferential: float = TAU * CORKSCREW_REVOLUTIONS * CORKSCREW_RADIUS
	var descent_length: float = sqrt(
		maxf(CORKSCREW_ARC_LENGTH * CORKSCREW_ARC_LENGTH - circumferential * circumferential, 0.0)
	)
	var fine_steps: int = 4000
	# The lateral radius eases in from 0 via eased_ramp, but a plain linear
	# `t * descent_length` for y does NOT ease in - it starts at full
	# descent speed from t=0. With a wide radius, that meant the path
	# snapped almost immediately from "mostly forward" to "mostly straight
	# down" while the sideways swing was still near zero, before the ramp
	# had contributed any real lateral motion to blend it with - measured
	# as a genuine 150+ degree direction change right at the handoff, not
	# a sampling artifact (confirmed by testing fine_steps up to 150000
	# with no change, and by testing longer ramp windows with no change -
	# only easing y's own rate, not just radius, fixed it). Pre-summing the
	# ramp weight lets y's rate follow the same ease curve as radius while
	# still totaling exactly descent_length by the end.
	var ramp_weight_sum: float = 0.0
	for i in range(1, fine_steps + 1):
		var t: float = float(i) / float(fine_steps)
		var angle: float = t * CORKSCREW_REVOLUTIONS * TAU
		var ramp: float = clampf(angle / (CORKSCREW_RAMP_REVOLUTIONS * TAU), 0.0, 1.0)
		ramp_weight_sum += ramp * ramp * (3.0 - 2.0 * ramp)
	var points: PackedVector3Array = PackedVector3Array()
	var last_emitted: Vector3 = start
	var accumulated: float = 0.0
	var ramp_weight_accum: float = 0.0
	for i in range(1, fine_steps + 1):
		var t: float = float(i) / float(fine_steps)
		var angle: float = t * CORKSCREW_REVOLUTIONS * TAU
		var ramp: float = clampf(angle / (CORKSCREW_RAMP_REVOLUTIONS * TAU), 0.0, 1.0)
		var eased_ramp: float = ramp * ramp * (3.0 - 2.0 * ramp)
		ramp_weight_accum += eased_ramp
		var y: float = start.y + descent_length * (ramp_weight_accum / ramp_weight_sum)
		var radius: float = CORKSCREW_RADIUS * eased_ramp
		# angle is offset by PI so the coil's initial tangential direction
		# continues the incoming -Z travel direction instead of starting
		# backward: with no offset, d/dangle of (cos(angle), sin(angle)) at
		# angle=0 points toward +Z (back the way we came), so the coil had
		# to wind through roughly a quarter turn before its motion actually
		# resumed heading forward - measured as a real ~94 degree reversal
		# right at the seam (the corkscrew's first raw point landed at
		# z=-599, less negative/further back than the slope's z=-610
		# endpoint it started from), not just a numerical artifact.
		var candidate: Vector3 = Vector3(
			-radius * cos(angle), y, start.z - radius * sin(angle)
		)
		accumulated += last_emitted.distance_to(candidate)
		last_emitted = candidate
		if accumulated >= ROUTE_STEP or i == fine_steps:
			points.append(candidate)
			accumulated = 0.0
	return points

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
	# The corkscrew alone needs far more resolution than Stage 1's gentle
	# bends to avoid aliasing into a jagged mess at CORKSCREW_REVOLUTIONS
	# revolutions.
	return CORKSCREW_RING_SAMPLES

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
