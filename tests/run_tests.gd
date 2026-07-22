extends SceneTree

const StageRulesScript := preload("res://scripts/stage_rules.gd")
const StageMarkerFactoryScript := preload("res://scripts/stage_marker_factory.gd")

var _failures: int = 0

func _initialize() -> void:
	_test_stage_time_formatting()
	_test_stage_time_bonus()
	_test_gate_lanes()
	_test_anchor_decay()
	_test_marker_factory()

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
