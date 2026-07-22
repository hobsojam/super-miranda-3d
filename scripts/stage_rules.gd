class_name StageRules
extends RefCounted

const STAGE_TARGET_TIME := 180.0
const STAGE_TIME_BONUS := 5000
const ANCHOR_DECAY_MIN_SPEED := 22.0
const ANCHOR_DECAY_MAX_SPEED := 55.0
const ANCHOR_DECAY_TIME_FAST := 3.5

static func format_stage_time(seconds: float) -> String:
	var total_tenths: int = int(roundf(seconds * 10.0))
	var minutes: int = int(float(total_tenths) / 600.0)
	var seconds_part: int = int(float(total_tenths - minutes * 600) / 10.0)
	var tenths: int = total_tenths % 10
	return "%02d:%02d.%d" % [minutes, seconds_part, tenths]

static func stage_clear_time_bonus(seconds: float) -> int:
	var ratio: float = clampf((STAGE_TARGET_TIME - seconds) / STAGE_TARGET_TIME, 0.0, 1.0)
	return int(roundf(ratio * float(STAGE_TIME_BONUS) / 50.0)) * 50

static func gate_lanes(start_lane: int, end_lane: int, lane_count: int) -> Array[Dictionary]:
	var lanes: Array[Dictionary] = []
	var lane: int = wrapi(start_lane, 0, lane_count)
	var end: int = wrapi(end_lane, 0, lane_count)
	lanes.append({"lane": lane, "kind": "gate_post"})
	while lane != end:
		lane = wrapi(lane + 1, 0, lane_count)
		lanes.append({"lane": lane, "kind": "gate_post" if lane == end else "gate_field"})
	return lanes

static func anchor_decay_amount(speed: float, delta: float) -> float:
	var speed_factor: float = clampf(
		(speed - ANCHOR_DECAY_MIN_SPEED) / (ANCHOR_DECAY_MAX_SPEED - ANCHOR_DECAY_MIN_SPEED),
		0.0,
		1.0
	)
	return delta * speed_factor / ANCHOR_DECAY_TIME_FAST
