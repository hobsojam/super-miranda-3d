extends SceneTree

const StageRulesScript := preload("res://scripts/stage_rules.gd")
const StageHudScript := preload("res://scripts/stage_hud.gd")
const StageMarkerFactoryScript := preload("res://scripts/stage_marker_factory.gd")
const StageOneDefinitionScript := preload("res://scripts/stage_one_definition.gd")
const StageTwoDefinitionScript := preload("res://scripts/stage_two_definition.gd")
const StormPlayerScript := preload("res://scripts/storm_player.gd")

var _failures: int = 0

func _initialize() -> void:
	_test_stage_time_formatting()
	_test_stage_time_bonus()
	_test_gate_lanes()
	_test_anchor_decay()
	_test_stage_hud()
	_test_marker_factory()
	_test_stage_definitions()
	_test_player_fire_intent()

	if _failures == 0:
		print("All tests passed")
		quit(0)
	else:
		push_error("%d test failure(s)" % _failures)
		quit(1)

func _test_stage_time_formatting() -> void:
	_assert_eq(StageRulesScript.format_stage_time(0.0), "00:00.0", "formats zero time")
	_assert_eq(StageRulesScript.format_stage_time(65.24), "01:05.2", "formats minutes and tenths")
	_assert_eq(
		StageRulesScript.format_stage_time(179.96),
		"03:00.0",
		"rounds up to next second"
	)

func _test_stage_time_bonus() -> void:
	_assert_eq(StageRulesScript.stage_clear_time_bonus(0.0), 5000, "awards full time bonus")
	_assert_eq(StageRulesScript.stage_clear_time_bonus(90.0), 2500, "awards half time bonus")
	_assert_eq(StageRulesScript.stage_clear_time_bonus(180.0), 0, "awards no bonus at target time")
	_assert_eq(StageRulesScript.stage_clear_time_bonus(220.0), 0, "does not penalize slow clears")

func _test_gate_lanes() -> void:
	var straight: Array[Dictionary] = StageRulesScript.gate_lanes(0, 4, 16)
	_assert_eq(straight.size(), 5, "builds contiguous gate lanes")
	_assert_eq(straight[0], {"lane": 0, "kind": "gate_post"}, "first gate lane is a post")
	_assert_eq(straight[1], {"lane": 1, "kind": "gate_field"}, "middle gate lane is a field")
	_assert_eq(straight[4], {"lane": 4, "kind": "gate_post"}, "last gate lane is a post")

	var wrapped: Array[Dictionary] = StageRulesScript.gate_lanes(14, 1, 16)
	_assert_eq(
		wrapped.map(func(part: Dictionary) -> int: return part["lane"]),
		[14, 15, 0, 1],
		"wraps gate lanes"
	)
	_assert_eq(
		wrapped.map(func(part: Dictionary) -> String: return part["kind"]),
		["gate_post", "gate_field", "gate_field", "gate_post"],
		"wraps gate part kinds"
	)

func _test_anchor_decay() -> void:
	_assert_float_eq(
		StageRulesScript.anchor_decay_amount(4.0, 1.0),
		0.0,
		"does not decay below threshold"
	)
	_assert_float_eq(
		StageRulesScript.anchor_decay_amount(22.0, 1.0),
		0.0,
		"does not decay at threshold"
	)
	_assert_float_eq(
		StageRulesScript.anchor_decay_amount(55.0, 3.5),
		1.0,
		"fully decays at max speed after fast decay time"
	)
	_assert_float_eq(
		StageRulesScript.anchor_decay_amount(100.0, 3.5),
		1.0,
		"caps decay above max speed"
	)

func _test_stage_hud() -> void:
	_assert_eq(
		StageHudScript.status_text(1, 675, 4, 1250, 3, 0, 5, 55, "READY"),
		"STAGE 1  DIST 0675  SPD 04  SCORE 1250  LIVES 3  ANCHOR 0  ACT 5  PROGRESS 55%  READY",
		"formats hud status text"
	)
	_assert_eq(
		StageHudScript.stage_clear_body(5750, "02:13.4", 1400, 2),
		"Score 5750\nStage Time 02:13.4\nTime Bonus 1400\nNext: Stage 2",
		"formats stage clear body"
	)

	var label: Label = Label.new()
	var hud: StageHud = StageHudScript.new()
	root.add_child(hud)
	hud.setup(label)
	hud.show_notice("CLEARANCE PULSE")
	hud.update_status(1, 1200, 15, 2500, 2, 1, 4, 38, "RUNNING")
	_assert_true(label.text.ends_with("CLEARANCE PULSE"), "notice overrides base hud status")
	hud.tick_notice(StageHudScript.NOTICE_TIME + 0.1)
	hud.update_status(1, 1200, 15, 2500, 2, 1, 4, 38, "RUNNING")
	_assert_true(label.text.ends_with("RUNNING"), "hud status resumes after notice expires")
	hud.free()
	label.free()

func _test_marker_factory() -> void:
	var enemy: Node3D = StageMarkerFactoryScript.build_enemy_marker("gate_post")
	_assert_eq(enemy.get_meta("kind"), "gate_post", "enemy marker records kind metadata")
	_assert_true(enemy.get_node_or_null("Pulse") != null, "gate post marker has a pulse node")
	_assert_true(_count_meshes(enemy) > 0, "enemy marker creates visible mesh parts")
	StageMarkerFactoryScript.animate_enemy_art(enemy, "gate_post")
	enemy.free()

	var pickup: Node3D = StageMarkerFactoryScript.build_pickup_marker("purge")
	_assert_true(pickup.get_node_or_null("Spin") != null, "purge pickup marker has a spin node")
	_assert_true(_count_meshes(pickup) > 0, "pickup marker creates visible mesh parts")
	StageMarkerFactoryScript.animate_pickup_art(pickup, "purge")
	pickup.free()

	var bullet: Node3D = StageMarkerFactoryScript.build_bullet_marker()
	_assert_true(_first_material(bullet).emission_enabled, "bullet marker uses emissive material")
	_assert_eq(
		_first_material(bullet).shading_mode,
		BaseMaterial3D.SHADING_MODE_UNSHADED,
		"bullet marker uses unshaded material"
	)
	bullet.free()

func _test_stage_definitions() -> void:
	var stage_one_hazards: Array[Dictionary] = StageOneDefinitionScript.hazards()
	var stage_one_pickups: Array[Dictionary] = StageOneDefinitionScript.pickups()
	_assert_eq(stage_one_hazards.size(), 24, "stage 1 hazard count is preserved")
	_assert_eq(stage_one_hazards[0], _hazard(720.0, 4, "flipper"), "stage 1 first hazard")
	_assert_eq(stage_one_hazards[-1], _hazard(3640.0, 2, "exploder"), "stage 1 final hazard")
	_assert_eq(
		stage_one_pickups,
		[_pickup(1360.0, 6, "purge"), _pickup(1450.0, 1, "life")],
		"stage 1 pickups"
	)
	_assert_true(StageOneDefinitionScript.guide_overdraw_enabled(), "stage 1 keeps guide overdraw")

	var stage_two_hazards: Array[Dictionary] = StageTwoDefinitionScript.hazards()
	var stage_two_pickups: Array[Dictionary] = StageTwoDefinitionScript.pickups()
	var stage_two_gates: Array[Dictionary] = StageTwoDefinitionScript.gate_pairs()
	_assert_eq(stage_two_hazards.size(), 14, "stage 2 hazard count is preserved")
	_assert_eq(stage_two_hazards[0], _hazard(650.0, 1, "flipper"), "stage 2 first hazard")
	_assert_eq(stage_two_gates[0], _gate_pair(3260.0, 0, 4, 1), "stage 2 first gate")
	_assert_eq(stage_two_gates[-1], _gate_pair(3620.0, 5, 10, 5), "stage 2 final gate")
	_assert_eq(
		stage_two_pickups,
		[_pickup(1340.0, 4, "purge"), _pickup(2350.0, 4, "life")],
		"stage 2 pickups"
	)
	_assert_true(
		not StageTwoDefinitionScript.guide_overdraw_enabled(),
		"stage 2 disables guide overdraw"
	)

func _test_player_fire_intent() -> void:
	var player: StormPlayer = StormPlayerScript.new()
	var fire_count: Array[int] = [0]
	player.fire_cooldown = 0.5
	player.fire_requested.connect(func() -> void: fire_count[0] += 1)

	player.tick_fire_input(1.0, true)
	_assert_eq(fire_count[0], 0, "player does not fire while disabled")

	player.set_fire_enabled(true)
	player.tick_fire_input(0.0, true)
	_assert_eq(fire_count[0], 1, "player fires immediately when enabled")

	player.tick_fire_input(0.2, true)
	_assert_eq(fire_count[0], 1, "player respects fire cooldown")

	player.tick_fire_input(0.3, true)
	_assert_eq(fire_count[0], 2, "player fires again after cooldown")

	player.set_fire_enabled(false)
	player.tick_fire_input(0.5, true)
	_assert_eq(fire_count[0], 2, "disabled player stops firing")
	player.free()

func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	_failures += 1
	push_error("%s: expected %s, got %s" % [label, var_to_str(expected), var_to_str(actual)])

func _assert_true(condition: bool, label: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("%s: condition was false" % label)

func _assert_float_eq(actual: float, expected: float, label: String) -> void:
	if is_equal_approx(actual, expected):
		return
	_failures += 1
	push_error("%s: expected %f, got %f" % [label, expected, actual])

func _count_meshes(node: Node) -> int:
	var count: int = 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += _count_meshes(child)
	return count

func _first_material(node: Node) -> StandardMaterial3D:
	if node is MeshInstance3D:
		return (node as MeshInstance3D).material_override as StandardMaterial3D
	for child in node.get_children():
		var material: StandardMaterial3D = _first_material(child)
		if material != null:
			return material
	return null

func _hazard(distance: float, lane: int, kind: String) -> Dictionary:
	return {"distance": distance, "lane": lane, "kind": kind}

func _pickup(distance: float, lane: int, kind: String) -> Dictionary:
	return {"distance": distance, "lane": lane, "kind": kind}

func _gate_pair(distance: float, start_lane: int, end_lane: int, gate_id: int) -> Dictionary:
	return {
		"distance": distance,
		"start_lane": start_lane,
		"end_lane": end_lane,
		"gate_id": gate_id,
	}
