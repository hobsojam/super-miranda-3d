class_name StageThreeDefinition
extends RefCounted

# See the note in stage_two_definition.gd on why hand-placed segments need
# consistent point spacing before this engine's uniform, index-based
# Catmull-Rom will parametrize them evenly.
const ROUTE_STEP := 12.0

# How far (in Z) the weave's fine-sampling loop walks. Real route distance
# ends up somewhat more than this once the lateral sine wobble is added
# (see _weave_points), so this is a tuning input, not the final route
# length - measure route_length and adjust if it drifts.
const WEAVE_FORWARD_DISTANCE := 3390.0
# Base lateral amplitude; _weave_envelope's knot values are multipliers on
# this, not absolute amplitudes.
const WEAVE_AMPLITUDE_SCALE := 110.0
# The minimum radius of curvature (see _weave_points) the weave is allowed
# to reach anywhere, in world units. Must stay well above the tube's own
# cross-section radius (12, see StormTube.radius) - if a bend's radius of
# curvature approaches the tube radius, the inside wall of that bend
# pinches and inverts, which read in actual play as the inside lane
# "pushing the player out and around" through the turn. Measured directly
# (radius = step / turn_angle_radians between consecutive rendered
# samples) rather than assumed: an earlier hand-placed-zigzag version of
# this weave measured a worst-case radius of 1.2 (0.1x the tube radius) at
# its tightest apex, and even the original, much gentler first draft
# measured 6.4 (0.53x) - both unsafe, neither caught by only checking
# render-sample turn angle, which only detects aliasing, not genuine tight
# curvature. 45 gives roughly a 3.75x safety margin.
const WEAVE_CURVATURE_SAFETY_RADIUS := 45.0
const WEAVE_Y_BASE_RATE := 0.12
const WEAVE_Y_ENVELOPE_RATE := 0.30

static func route() -> PackedVector3Array:
	# A slalom: a weave that alternates side to side rather than spiraling
	# (Stage 2's corkscrew) or holding a gentle, mostly-straight line
	# (Stage 1). The route also carries a steady net descent, steepening
	# through the climax, so it reads as a downhill run, the way a real
	# slalom course is - distinct from Stage 2's descend-then-climb shape.
	var points: PackedVector3Array = _subdivide(_entry_straight_points(), ROUTE_STEP)
	# _weave_points does its own arc-length-based spacing internally (see
	# its comment), the same reason _corkscrew_points in
	# stage_two_definition.gd bypasses _subdivide/_joined_subdivision.
	points.append_array(_weave_points(points[points.size() - 1]))
	return points

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

# The weave's "excitement" schedule as a multiplier on WEAVE_AMPLITUDE_SCALE,
# piecewise-linear between knots (t, level). t runs 0-1 across the whole
# weave; the knot bands below correspond to phases 2 (introduce) through 5
# (climax) from STAGE_DESIGN.md's five-phase curve. Starting and ending at
# level 0 means amplitude - and therefore lateral velocity, since the sine
# phase also starts at exactly 0 (see _weave_points) - eases in and out
# from genuinely zero rather than snapping to a nonzero swing at the seam,
# the same class of fix as the corkscrew's entrance phase-shift in
# stage_two_definition.gd, just achieved differently here.
static func _weave_envelope(t: float) -> float:
	var knots: Array[Vector2] = [
		Vector2(0.00, 0.0), # start of phase 2
		Vector2(0.08, 0.55),
		Vector2(0.22, 0.70), # end of phase 2
		Vector2(0.48, 1.00), # phase 3 escalate peak
		Vector2(0.58, 0.40), # phase 4 false summit dip
		Vector2(0.66, 0.45), # end of phase 4
		Vector2(0.80, 1.35), # phase 5 climax peak
		Vector2(1.00, 0.0), # finish straight, recenters
	]
	for i in range(1, knots.size()):
		if t <= knots[i].x:
			var a: Vector2 = knots[i - 1]
			var b: Vector2 = knots[i]
			var local_t: float = 0.0 if b.x <= a.x else (t - a.x) / (b.x - a.x)
			return lerpf(a.y, b.y, local_t)
	return knots[knots.size() - 1].y

static func _weave_points(start: Vector3) -> PackedVector3Array:
	# A genuine parametric sine wave in x, sampled finely and emitted by
	# real arc length - the same technique _corkscrew_points in
	# stage_two_definition.gd uses for the same reason: a curve assembled
	# from a handful of hand-placed points, connected by this engine's
	# Catmull-Rom, has locally unpredictable curvature at each vertex (its
	# tangent only matches position and direction, not curvature, between
	# points) - fine sampling a real formula instead makes curvature an
	# explicit, checkable property instead of an accident of how far apart
	# the hand-placed points happened to be.
	#
	# Wavelength is derived from amplitude so radius of curvature at the
	# peak of any swing - where curvature is highest, since curvature there
	# is amplitude * (TAU/wavelength)^2 - always comes out to exactly
	# WEAVE_CURVATURE_SAFETY_RADIUS regardless of how big that swing's
	# amplitude is: wavelength = TAU * sqrt(safety_radius * amplitude)
	# solves radius = wavelength^2 / (TAU^2 * amplitude) for wavelength
	# given a fixed target radius. That keeps the tightest and widest
	# swings equally safe instead of only tuning the worst case by hand.
	var fine_steps: int = 8000
	var forward_step: float = WEAVE_FORWARD_DISTANCE / float(fine_steps)
	var points: PackedVector3Array = PackedVector3Array()
	var last_emitted: Vector3 = start
	var accumulated: float = 0.0
	var phase_accum: float = 0.0
	var z: float = start.z
	var y: float = start.y
	for i in range(1, fine_steps + 1):
		var t: float = float(i) / float(fine_steps)
		var envelope: float = _weave_envelope(t)
		var amplitude: float = WEAVE_AMPLITUDE_SCALE * envelope
		# sqrt(amplitude^2 + floor^2) instead of maxf(amplitude, floor): a
		# hard maxf clamp is non-smooth exactly at the crossover, which
		# showed up as a genuine curvature spike (measured radius as low as
		# 1.6, well under the tube radius) right where the finish taper's
		# amplitude crossed the floor - not just aliasing, since it moved
		# to wherever that crossover happened when the taper was retimed.
		# This floor is smooth everywhere, so amplitude approaching 0 makes
		# wavelength approach a fixed value continuously instead of kinking
		# into it.
		var smoothed_amplitude: float = sqrt(amplitude * amplitude + 25.0)
		var wavelength: float = TAU * sqrt(WEAVE_CURVATURE_SAFETY_RADIUS * smoothed_amplitude)
		phase_accum += TAU * forward_step / wavelength
		var x: float = amplitude * sin(phase_accum)
		z -= forward_step
		y += forward_step * (WEAVE_Y_BASE_RATE + WEAVE_Y_ENVELOPE_RATE * envelope)
		var candidate: Vector3 = Vector3(x, y, z)
		accumulated += last_emitted.distance_to(candidate)
		last_emitted = candidate
		if accumulated >= ROUTE_STEP or i == fine_steps:
			points.append(candidate)
			accumulated = 0.0
	return points

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
	# Distances are the weave's actual measured apex positions (local
	# extrema in x along the rendered route) - unlike the old hand-placed
	# version, the curve doesn't have authored "apex points" to read
	# distances off directly, so these were found by scanning the built
	# route for sign changes in lateral velocity, the same way the old
	# version's apex distances had to be re-measured (not assumed) after
	# any geometry change.
	return [
		# Phase 2 (~690-1600): one hazard per apex, still solo kinds - the
		# weave itself is what's new here, not enemy combinations.
		_hazard(790.0, 2, "flipper"),
		_hazard(940.0, 11, "flipper"),
		_hazard(1150.0, 13, "splitter"),
		_hazard(1380.0, 7, "flipper"),
		# Phase 3 (~1600-2800): known kinds combine at every apex.
		_hazard(1630.0, 5, "flipper"),
		_hazard(1630.0, 6, "spiker"),
		_hazard(1900.0, 9, "splitter"),
		_hazard(2180.0, 3, "flipper"),
		_hazard(2180.0, 14, "spiker"),
		_hazard(2480.0, 8, "splitter"),
		_hazard(2480.0, 1, "pulsar"),
		_hazard(2800.0, 10, "spiker"),
		_hazard(2800.0, 4, "splitter"),
		# Phase 4 (~3100ish): one easy beat before the reward - amplitude
		# genuinely dips here too (the false-summit swings are visibly
		# smaller), matching the breather in content.
		_hazard(3100.0, 7, "flipper"),
		# Phase 5 (~3700-4630): highest density, mixed kinds, often two per
		# apex; the last three apexes are reserved for the gate gauntlet
		# below rather than mixed with more hazards.
		_hazard(3700.0, 1, "pulsar"),
		_hazard(3940.0, 10, "exploder"),
		_hazard(4260.0, 6, "spiker"),
		_hazard(4260.0, 12, "splitter"),
		_hazard(4630.0, 3, "pulsar"),
		_hazard(4630.0, 9, "exploder"),
	]

static func pickups() -> Array[Dictionary]:
	return [
		_pickup(3200.0, 4, "life"),
		_pickup(4800.0, 4, "purge"),
	]

static func gate_pairs() -> Array[Dictionary]:
	# Two simultaneous-gate choices followed by a single climax gate at the
	# weave's last three apexes (by this point the taper has already
	# brought amplitude back down, so these sit on a calmer part of the
	# curve, not the climax's sharpest swings), mirroring Stage 2's gate
	# gauntlet shape - gates are Stage 2's mechanic, reused here in a new
	# context rather than introduced as a fresh idea. Leaves a short clean
	# run-out after the last gate, the same way Stage 2 closes out.
	return [
		_gate_pair(4920.0, 0, 4, 1),
		_gate_pair(4920.0, 8, 12, 2),
		_gate_pair(5120.0, 2, 6, 3),
		_gate_pair(5120.0, 10, 14, 4),
		_gate_pair(5250.0, 5, 10, 5),
	]

static func guide_overdraw_enabled() -> bool:
	return false

static func ring_samples() -> int:
	return 640

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
