class_name StageOneDefinition
extends RefCounted

static func hazards() -> Array[Dictionary]:
	return [
		_hazard(720.0, 4, "flipper"),
		_hazard(820.0, 12, "flipper"),
		_hazard(930.0, 6, "flipper"),
		_hazard(1080.0, 2, "spiker"),
		_hazard(1080.0, 10, "spiker"),
		_hazard(1260.0, 5, "splitter"),
		_hazard(1260.0, 6, "splitter"),
		_hazard(1260.0, 7, "splitter"),
		_hazard(1510.0, 14, "flipper"),
		_hazard(1600.0, 13, "flipper"),
		_hazard(1690.0, 12, "flipper"),
		_hazard(1900.0, 3, "spiker"),
		_hazard(1900.0, 11, "spiker"),
		_hazard(2140.0, 7, "pulsar"),
		_hazard(2250.0, 8, "pulsar"),
		_hazard(2360.0, 9, "pulsar"),
		_hazard(2600.0, 0, "exploder"),
		_hazard(2600.0, 8, "exploder"),
		_hazard(2860.0, 15, "flipper"),
		_hazard(3080.0, 4, "flipper"),
		_hazard(3180.0, 12, "flipper"),
		_hazard(3360.0, 6, "splitter"),
		_hazard(3540.0, 10, "pulsar"),
		_hazard(3640.0, 2, "exploder"),
	]

static func pickups() -> Array[Dictionary]:
	return [
		_pickup(1360.0, 6, "purge"),
		_pickup(1450.0, 1, "life"),
	]

static func gate_pairs() -> Array[Dictionary]:
	return []

static func guide_overdraw_enabled() -> bool:
	return true

static func _hazard(distance: float, lane: int, kind: String) -> Dictionary:
	return {"distance": distance, "lane": lane, "kind": kind}

static func _pickup(distance: float, lane: int, kind: String) -> Dictionary:
	return {"distance": distance, "lane": lane, "kind": kind}
