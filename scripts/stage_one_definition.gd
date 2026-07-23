class_name StageOneDefinition
extends RefCounted

static func hazards() -> Array[Dictionary]:
	return [
		# Phase 1 (0-680): orientation, deliberately empty.

		# Phase 2a: introduce flipper, alone.
		_hazard(680.0, 4, "flipper"),
		_hazard(800.0, 12, "flipper"),
		_hazard(930.0, 8, "flipper"),

		# Phase 2b: introduce spiker, alone.
		_hazard(1080.0, 2, "spiker"),
		_hazard(1220.0, 11, "spiker"),

		# Phase 2c: introduce splitter, alone (its own flipper payoff on death
		# is a soft callback to the kind just learned above).
		_hazard(1400.0, 5, "splitter"),
		_hazard(1480.0, 6, "splitter"),
		_hazard(1560.0, 7, "splitter"),

		# Phase 3: escalate by combining flipper + spiker, no new kind yet.
		_hazard(1750.0, 14, "flipper"),
		_hazard(1850.0, 3, "spiker"),
		_hazard(1930.0, 13, "flipper"),
		_hazard(1930.0, 11, "spiker"),
		_hazard(2020.0, 12, "flipper"),

		# Phase 2d: introduce pulsar, alone.
		_hazard(2100.0, 7, "pulsar"),
		_hazard(2220.0, 9, "pulsar"),

		# Phase 2e: introduce exploder, lightly paired with known pulsar.
		_hazard(2500.0, 0, "exploder"),
		_hazard(2560.0, 8, "pulsar"),
		_hazard(2650.0, 8, "exploder"),

		# Phase 4: false summit. One easy, familiar beat; otherwise thin,
		# not empty. See pickups() for the reward half of this beat.
		_hazard(2820.0, 15, "flipper"),

		# Phase 5: fight to the finish. Every known kind, at density.
		_hazard(3080.0, 6, "splitter"),
		_hazard(3150.0, 10, "pulsar"),
		_hazard(3220.0, 4, "flipper"),
		_hazard(3280.0, 0, "exploder"),
		_hazard(3280.0, 12, "flipper"),
		_hazard(3350.0, 2, "spiker"),
		_hazard(3420.0, 9, "pulsar"),
		_hazard(3480.0, 5, "splitter"),
		_hazard(3480.0, 13, "exploder"),
		_hazard(3560.0, 15, "flipper"),
		_hazard(3560.0, 3, "flipper"),
		_hazard(3620.0, 7, "pulsar"),
	]

static func pickups() -> Array[Dictionary]:
	return [
		# Mid-ramp: purge is useful heading into the escalate/pulsar/exploder
		# stretch, so it lands before density climbs.
		_pickup(1300.0, 6, "purge"),
		# Phase 4 reward beat: the "you made it" pickup in the false summit.
		_pickup(2900.0, 1, "life"),
	]

static func gate_pairs() -> Array[Dictionary]:
	return [
		# The stage's one capstone: a single gate, not a gauntlet (Stage 2
		# owns gates-as-recurring-mechanic). This is the first gate the
		# player has ever seen, so it gets a generous 5-lane span like
		# Stage 2's individual gates, not a tight squeeze. Reveals ~520
		# units out (same window as hazards), so it's visible on the
		# horizon through most of phase 5 — a thing to aim for, not a
		# last-second surprise.
		_gate_pair(3680.0, 6, 10, 1),
	]

static func guide_overdraw_enabled() -> bool:
	return true

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
