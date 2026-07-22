class_name StageTwoDefinition
extends RefCounted

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
