extends SceneTree

const StageRulesScript := preload("res://scripts/stage_rules.gd")
const StageAudioScript := preload("res://scripts/stage_audio.gd")
const StageHudScript := preload("res://scripts/stage_hud.gd")
const StageMarkerFactoryScript := preload("res://scripts/stage_marker_factory.gd")
const StageOneDefinitionScript := preload("res://scripts/stage_one_definition.gd")
const StageTwoDefinitionScript := preload("res://scripts/stage_two_definition.gd")
const StageThreeDefinitionScript := preload("res://scripts/stage_three_definition.gd")
const RimObstacleManagerScript := preload("res://scripts/rim_obstacle_manager.gd")
const StageHazardRuntimeScript := preload("res://scripts/stage_hazard_runtime.gd")
const StagePickupRuntimeScript := preload("res://scripts/stage_pickup_runtime.gd")
const StageProjectileRuntimeScript := preload("res://scripts/stage_projectile_runtime.gd")
const EnemySkillRuntimeScript := preload("res://scripts/enemy_skill_runtime.gd")
const StageFlowRuntimeScript := preload("res://scripts/stage_flow_runtime.gd")
const StormPlayerScript := preload("res://scripts/storm_player.gd")

var _failures: int = 0

func _initialize() -> void:
	_test_stage_time_formatting()
	_test_stage_time_bonus()
	_test_stage_audio()
	_test_gate_lanes()
	_test_anchor_decay()
	_test_stage_hud()
	_test_marker_factory()
	_test_stage_definitions()
	_test_rim_obstacle_rules()
	_test_hazard_runtime()
	_test_pickup_runtime()
	_test_projectile_runtime()
	_test_enemy_skill_runtime()
	_test_stage_flow_runtime()
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

func _test_stage_audio() -> void:
	_assert_eq(StageAudioScript.music_stage_for(1), 1, "uses stage 1 music for stage 1")
	_assert_eq(StageAudioScript.music_stage_for(2), 2, "uses stage 2 music for stage 2")
	_assert_eq(StageAudioScript.music_stage_for(99), 2, "caps music lookup at stage 2")
	_assert_float_eq(StageAudioScript.target_intensity(0, 0, 5), 0.0, "low pressure is quiet")
	_assert_float_eq(StageAudioScript.target_intensity(3, 0, 6), 0.5, "middle pressure blends")
	_assert_float_eq(StageAudioScript.target_intensity(8, 0, 5), 1.0, "high pressure caps")
	_assert_float_eq(StageAudioScript.target_intensity(5, 5, 5), 0.0, "invalid span is quiet")
	_assert_float_eq(
		StageAudioScript.damage_sound_volume(StageAudioScript.EXPLODER_SOUND),
		-5.0,
		"exploder damage is louder"
	)
	_assert_float_eq(
		StageAudioScript.damage_sound_volume(StageAudioScript.HIT_SOUND),
		-7.0,
		"regular damage is quieter"
	)
	_assert_true(StageAudioScript.LIFE_PICKUP_SOUND != null, "life pickup sound is loaded")
	_assert_true(StageAudioScript.PURGE_PICKUP_SOUND != null, "purge pickup sound is loaded")
	_assert_true(
		StageAudioScript.LIFE_PICKUP_SOUND != StageAudioScript.CLEAR_SOUND,
		"life pickup has a distinct sound"
	)
	_assert_true(
		StageAudioScript.PURGE_PICKUP_SOUND != StageAudioScript.EXPLODER_SOUND,
		"purge pickup has a distinct sound"
	)

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

	_assert_float_eq(
		StageHudScript.pickup_banner_alpha(1.3), 1.0, "banner holds full alpha before fade window"
	)
	_assert_float_eq(
		StageHudScript.pickup_banner_alpha(0.2), 0.5, "banner fades linearly near expiry"
	)
	_assert_float_eq(
		StageHudScript.pickup_banner_alpha(0.0), 0.0, "banner is transparent once expired"
	)

	var banner: Label = hud.find_child("PickupBanner", true, false) as Label
	hud.flash_pickup("CLEARANCE PULSE", Color(0.3, 1.0, 1.0))
	_assert_true(banner.visible, "pickup banner becomes visible on flash")
	_assert_eq(banner.text, "CLEARANCE PULSE", "pickup banner shows the collected pickup text")
	hud.tick_pickup_banner(StageHudScript.PICKUP_BANNER_TIME + 0.1)
	_assert_true(not banner.visible, "pickup banner hides after it fully expires")

	var stage_selector: OptionButton = hud.find_child("StageSelector", true, false) as OptionButton
	_assert_true(
		hud.has_state_control_focus_owner(stage_selector),
		"stage selector focus belongs to menu modal"
	)
	_assert_true(
		not hud.should_accept_shortcut_start_for_focus(stage_selector),
		"menu focus blocks global accept start shortcut"
	)
	hud.hide_state_overlay()
	_assert_true(
		hud.should_accept_shortcut_start_for_focus(stage_selector),
		"hidden menu allows global accept start shortcut"
	)
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
	_assert_eq(stage_one_hazards.size(), 31, "stage 1 hazard count is preserved")
	_assert_eq(stage_one_hazards[0], _hazard(680.0, 4, "flipper"), "stage 1 first hazard")
	_assert_eq(stage_one_hazards[-1], _hazard(3620.0, 7, "pulsar"), "stage 1 final hazard")
	_assert_eq(
		stage_one_pickups,
		[_pickup(1300.0, 6, "purge"), _pickup(2900.0, 1, "life")],
		"stage 1 pickups"
	)
	var stage_one_gates: Array[Dictionary] = StageOneDefinitionScript.gate_pairs()
	_assert_eq(
		stage_one_gates,
		[_gate_pair(3680.0, 6, 10, 1)],
		"stage 1 has a single capstone gate"
	)
	_assert_true(StageOneDefinitionScript.guide_overdraw_enabled(), "stage 1 keeps guide overdraw")

	var stage_two_hazards: Array[Dictionary] = StageTwoDefinitionScript.hazards()
	var stage_two_pickups: Array[Dictionary] = StageTwoDefinitionScript.pickups()
	var stage_two_gates: Array[Dictionary] = StageTwoDefinitionScript.gate_pairs()
	_assert_eq(stage_two_hazards.size(), 17, "stage 2 hazard count is preserved")
	_assert_eq(stage_two_hazards[0], _hazard(640.0, 1, "flipper"), "stage 2 first hazard")
	_assert_eq(stage_two_gates[0], _gate_pair(4400.0, 0, 4, 1), "stage 2 first gate")
	_assert_eq(stage_two_gates[-1], _gate_pair(4750.0, 5, 10, 5), "stage 2 final gate")
	_assert_eq(
		stage_two_pickups,
		[_pickup(1150.0, 4, "purge"), _pickup(1900.0, 4, "life")],
		"stage 2 pickups"
	)
	_assert_true(
		not StageTwoDefinitionScript.guide_overdraw_enabled(),
		"stage 2 disables guide overdraw"
	)

	var stage_three_hazards: Array[Dictionary] = StageThreeDefinitionScript.hazards()
	var stage_three_pickups: Array[Dictionary] = StageThreeDefinitionScript.pickups()
	var stage_three_gates: Array[Dictionary] = StageThreeDefinitionScript.gate_pairs()
	_assert_eq(stage_three_hazards.size(), 20, "stage 3 hazard count is preserved")
	_assert_eq(stage_three_hazards[0], _hazard(790.0, 2, "flipper"), "stage 3 first hazard")
	_assert_eq(stage_three_gates[0], _gate_pair(4920.0, 0, 4, 1), "stage 3 first gate")
	_assert_eq(stage_three_gates[-1], _gate_pair(5250.0, 5, 10, 5), "stage 3 final gate")
	_assert_eq(
		stage_three_pickups,
		[_pickup(3200.0, 4, "life"), _pickup(4800.0, 4, "purge")],
		"stage 3 pickups"
	)
	_assert_true(
		not StageThreeDefinitionScript.guide_overdraw_enabled(),
		"stage 3 disables guide overdraw"
	)

func _test_rim_obstacle_rules() -> void:
	_assert_true(RimObstacleManagerScript.should_anchor_kind("flipper"), "flippers anchor")
	_assert_true(not RimObstacleManagerScript.should_anchor_kind("gate_field"), "fields do not anchor")
	_assert_true(not RimObstacleManagerScript.should_anchor_kind("gate_post"), "posts do not anchor")

	_assert_float_eq(RimObstacleManagerScript.stack_offset(0), 0.0, "first stack is centered")
	_assert_float_eq(RimObstacleManagerScript.stack_offset(1), 0.62, "second stack offsets right")
	_assert_float_eq(RimObstacleManagerScript.stack_offset(2), -0.62, "third stack offsets left")
	_assert_float_eq(RimObstacleManagerScript.stack_offset(3), 1.24, "fourth stack offsets farther")

	_assert_eq(RimObstacleManagerScript.step_lane_toward(2, 5, 16), 3, "steps clockwise")
	_assert_eq(RimObstacleManagerScript.step_lane_toward(5, 2, 16), 4, "steps anticlockwise")
	_assert_eq(RimObstacleManagerScript.step_lane_toward(15, 1, 16), 0, "wraps forward")
	_assert_eq(RimObstacleManagerScript.step_lane_toward(1, 15, 16), 0, "wraps backward")
	_assert_eq(RimObstacleManagerScript.step_lane_toward(4, 4, 16), 4, "stays on target")

func _test_hazard_runtime() -> void:
	_assert_float_eq(
		StageHazardRuntimeScript.spawn_distance_for(720.0, 520.0),
		200.0,
		"spawn distance uses reveal distance"
	)
	_assert_float_eq(
		StageHazardRuntimeScript.spawn_distance_for(120.0, 520.0),
		0.0,
		"spawn distance clamps to stage start"
	)
	_assert_true(
		StageHazardRuntimeScript.should_reject_spawn(996.0, 1000.0, 4.2),
		"rejects hazards inside end hit window"
	)
	_assert_true(
		not StageHazardRuntimeScript.should_reject_spawn(990.0, 1000.0, 4.2),
		"accepts hazards before end hit window"
	)

	var runtime: StageHazardRuntime = StageHazardRuntimeScript.new()
	runtime.setup(16, 1000.0, 4.2, 520.0, 2.0, 1.35)
	var hazard: StageHazardRuntime.Hazard = runtime.add_hazard(720.0, -1, "flipper")
	_assert_eq(runtime.count(), 1, "adds accepted hazard")
	_assert_eq(hazard.lane, 15, "wraps hazard lane")
	_assert_eq(hazard.spawn_distance, 200.0, "records hazard spawn distance")
	_assert_true(runtime.should_activate(hazard, 200.0), "activates at spawn distance")
	_assert_true(runtime.should_show(hazard, 201.0), "shows inside reveal distance")
	_assert_true(runtime.has_passed_player(hazard, 725.0), "detects passed hazard")
	_assert_eq(runtime.spawn_hazard(998.0, 1, "spike"), null, "rejects spawned hazard near end")

func _test_pickup_runtime() -> void:
	_assert_float_eq(
		StagePickupRuntimeScript.spawn_distance_for(1360.0, 520.0),
		840.0,
		"pickup spawn distance uses reveal distance"
	)
	_assert_float_eq(
		StagePickupRuntimeScript.spawn_distance_for(120.0, 520.0),
		0.0,
		"pickup spawn distance clamps to stage start"
	)

	var runtime: StagePickupRuntime = StagePickupRuntimeScript.new()
	runtime.setup(16, 4.2, 520.0)
	var pickup: StagePickupRuntime.Pickup = runtime.add_pickup(1360.0, -1, "purge")
	_assert_eq(runtime.count(), 1, "adds pickup")
	_assert_eq(pickup.lane, 15, "wraps pickup lane")
	_assert_eq(pickup.spawn_distance, 840.0, "records pickup spawn distance")
	_assert_true(runtime.should_activate(pickup, 840.0), "activates at spawn distance")
	_assert_true(runtime.should_show(pickup, 900.0), "shows inside reveal distance")
	_assert_true(runtime.has_passed_player(pickup, 1365.0), "detects passed pickup")
	_assert_true(runtime.can_collect(pickup, 1362.0, 15), "collects matching lane in window")
	_assert_true(
		not runtime.can_collect(pickup, 1362.0, 14),
		"does not collect from another lane"
	)
	runtime.clear_pickup(pickup)
	_assert_true(pickup.cleared, "clears pickup")
	runtime.clear()
	_assert_eq(runtime.count(), 0, "clears all pickups")

func _test_projectile_runtime() -> void:
	var runtime: StageProjectileRuntime = StageProjectileRuntimeScript.new()
	runtime.setup(140.0, 220.0, 95.0, 4.2)
	var bullet: StageProjectileRuntime.Bullet = runtime.fire_bullet(3, 100.0, null)
	_assert_eq(runtime.bullet_count(), 1, "adds player bullet")
	_assert_eq(bullet.lane, 3, "records bullet lane")
	_assert_float_eq(bullet.distance, 104.0, "starts bullet at muzzle offset")
	_assert_float_eq(bullet.start_distance, 104.0, "records bullet start distance")

	var previous_distance: float = runtime.advance_bullet(bullet, 0.5)
	_assert_float_eq(previous_distance, 104.0, "returns previous bullet distance")
	_assert_float_eq(bullet.distance, 174.0, "advances bullet by speed")
	_assert_true(
		not runtime.bullet_expired(bullet, 400.0),
		"keeps bullet inside range and route"
	)
	bullet.distance = 325.0
	_assert_true(runtime.bullet_expired(bullet, 400.0), "expires bullet after range")

	var hazards: StageHazardRuntime = StageHazardRuntimeScript.new()
	hazards.setup(16, 1000.0, 4.2, 520.0, 2.0, 1.35)
	var gate_field: StageHazardRuntime.Hazard = hazards.add_hazard(190.0, 3, "gate_field")
	var far_hazard: StageHazardRuntime.Hazard = hazards.add_hazard(202.0, 3, "flipper")
	var near_hazard: StageHazardRuntime.Hazard = hazards.add_hazard(184.0, 3, "spike")
	var wrong_lane: StageHazardRuntime.Hazard = hazards.add_hazard(176.0, 4, "flipper")
	gate_field.spawned = true
	far_hazard.spawned = true
	near_hazard.spawned = true
	wrong_lane.spawned = true
	bullet.distance = 200.0
	_assert_eq(
		runtime.find_bullet_hazard_hit(bullet, 170.0, hazards.all()),
		near_hazard,
		"finds nearest killable hazard hit"
	)

	var pickups: StagePickupRuntime = StagePickupRuntimeScript.new()
	pickups.setup(16, 4.2, 520.0)
	var far_pickup: StagePickupRuntime.Pickup = pickups.add_pickup(199.0, 3, "life")
	var near_pickup: StagePickupRuntime.Pickup = pickups.add_pickup(181.0, 3, "purge")
	far_pickup.spawned = true
	near_pickup.spawned = true
	_assert_eq(
		runtime.find_bullet_pickup_hit(bullet, 170.0, pickups.all()),
		near_pickup,
		"finds nearest pickup hit"
	)

	var bolt: StageProjectileRuntime.EnemyBolt = runtime.fire_enemy_bolt(2, 250.0, null)
	_assert_eq(runtime.enemy_bolt_count(), 1, "adds enemy bolt")
	previous_distance = runtime.advance_enemy_bolt(bolt, 1.0)
	_assert_float_eq(previous_distance, 250.0, "returns previous enemy bolt distance")
	_assert_float_eq(bolt.distance, 155.0, "moves enemy bolt toward player")
	_assert_true(runtime.enemy_bolt_reached_player(bolt, 152.0), "detects enemy bolt hit window")
	_assert_true(runtime.enemy_bolt_expired_behind(bolt, 200.0), "expires bolt behind player")
	runtime.remove_bullet(bullet)
	runtime.remove_enemy_bolt(bolt)
	_assert_eq(runtime.bullet_count(), 0, "removes player bullet")
	_assert_eq(runtime.enemy_bolt_count(), 0, "removes enemy bolt")

func _test_enemy_skill_runtime() -> void:
	var hazards: StageHazardRuntime = StageHazardRuntimeScript.new()
	hazards.setup(16, 1000.0, 4.2, 520.0, 2.0, 1.35)
	var skills: EnemySkillRuntime = EnemySkillRuntimeScript.new()
	skills.setup(16, 4.2, 7.0, 70.0, 1.35, 2.0)

	var spiker: StageHazardRuntime.Hazard = hazards.add_hazard(500.0, 5, "spiker")
	spiker.spawned = true
	_assert_eq(spiker.spiker_lane_direction, -1, "odd lane starts stepping backward")

	var event: Dictionary = skills.update(spiker, 0.5, 100.0, 1000.0)
	_assert_true(event.is_empty(), "no event on partial spiker tick")
	_assert_float_eq(spiker.distance, 503.5, "spiker retreats toward player")
	_assert_float_eq(spiker.spiker_lane_timer, 0.85, "spiker lane timer counts down")
	_assert_eq(spiker.lane, 5, "spiker lane unchanged before step interval")

	event = skills.update(spiker, 0.9, 100.0, 1000.0)
	_assert_true(event.is_empty(), "no event on lane step tick")
	_assert_eq(spiker.lane, 4, "spiker steps lane after interval")
	_assert_eq(spiker.spiker_lane_direction, 1, "spiker alternates lane direction")

	spiker.spike_drop_meter = 65.0
	event = skills.update(spiker, 1.0, 100.0, 1000.0)
	_assert_eq(event["type"], "spike_drop", "drops a spike after crossing spacing threshold")
	_assert_eq(event["lane"], 4, "spike drop uses the spiker's current lane")
	_assert_float_eq(event["distance"], 446.8, "spike drop lands behind the spiker")
	_assert_float_eq(spiker.spike_drop_meter, 2.0, "spike drop meter resets after threshold")

	spiker.distance = 995.0
	event = skills.update(spiker, 1.0, 100.0, 1000.0)
	_assert_eq(event, {"type": "cleared"}, "spiker clears at stage end")
	_assert_true(spiker.cleared, "marks hazard cleared")

	var pulsar: StageHazardRuntime.Hazard = hazards.add_hazard(300.0, 2, "pulsar")
	pulsar.spawned = true
	event = skills.update(pulsar, 1.0, 100.0, 1000.0)
	_assert_true(event.is_empty(), "no bolt before pulsar interval elapses")
	event = skills.update(pulsar, 1.0, 100.0, 1000.0)
	_assert_eq(
		event, {"type": "fire_bolt", "lane": 2, "distance": 300.0}, "fires bolt at pulsar interval"
	)
	_assert_float_eq(pulsar.pulse_timer, 2.0, "pulsar timer resets after firing")

	var flipper: StageHazardRuntime.Hazard = hazards.add_hazard(50.0, 5, "flipper")
	_assert_true(
		skills.update(flipper, 1.0, 0.0, 1000.0).is_empty(),
		"non-skill hazards produce no event"
	)

func _test_stage_flow_runtime() -> void:
	var flow: StageFlowRuntime = StageFlowRuntimeScript.new()

	flow.start_stage(5)
	_assert_eq(flow.stage, 3, "start_stage clamps to the max stage")
	_assert_true(flow.run_active, "start_stage activates the run")
	_assert_true(not flow.game_over, "start_stage clears game over")
	_assert_true(not flow.game_complete, "start_stage clears game complete")
	_assert_float_eq(flow.stage_elapsed_time, 0.0, "start_stage resets elapsed time")
	_assert_float_eq(flow.stage_transition_timer, 0.0, "start_stage resets transition timer")
	_assert_eq(flow.pending_stage, 0, "start_stage clears pending stage")
	_assert_eq(flow.last_stage_time_bonus, 0, "start_stage clears last time bonus")

	flow.start_stage(0)
	_assert_eq(flow.stage, 1, "start_stage clamps below the min stage")
	_assert_true(not flow.is_run_blocked(), "active run is not blocked")
	_assert_eq(flow.status_label(), "", "active run has no status override")

	flow.tick(0.5)
	_assert_float_eq(flow.stage_elapsed_time, 0.5, "tick accumulates elapsed time")

	flow.stage_elapsed_time = 90.0
	flow.begin_stage_clear_transition(2, 1.85)
	_assert_eq(flow.last_stage_time_bonus, 2500, "transition computes the stage clear bonus")
	_assert_eq(flow.pending_stage, 2, "transition records the pending stage")
	_assert_float_eq(flow.stage_transition_timer, 1.85, "transition starts the countdown")
	_assert_true(not flow.run_active, "transition deactivates the run")
	_assert_true(flow.is_run_blocked(), "blocked while transitioning")
	_assert_eq(flow.status_label(), "STAGE CLEAR", "status shows stage clear during transition")

	_assert_true(not flow.tick_transition(1.0), "transition has not finished yet")
	_assert_float_eq(flow.stage_transition_timer, 0.85, "transition timer counts down")
	_assert_true(flow.tick_transition(1.0), "transition reports completion")
	_assert_float_eq(flow.stage_transition_timer, 0.0, "transition timer floors at zero")

	_assert_true(flow.continue_to_pending(), "continues into the pending stage")
	_assert_eq(flow.stage, 2, "continuing moves to the pending stage")
	_assert_eq(flow.pending_stage, 0, "continuing clears the pending stage")
	_assert_float_eq(flow.stage_elapsed_time, 0.0, "continuing resets elapsed time")
	_assert_true(flow.run_active, "continuing reactivates the run")
	_assert_true(not flow.continue_to_pending(), "continuing again with no pending stage is a no-op")

	flow.stage_elapsed_time = 180.0
	flow.complete_run()
	_assert_eq(flow.last_stage_time_bonus, 0, "completing the run computes the final bonus")
	_assert_true(flow.game_over, "completing the run sets game over")
	_assert_true(flow.game_complete, "completing the run sets game complete")
	_assert_true(not flow.run_active, "completing the run deactivates it")
	_assert_eq(flow.status_label(), "CLEAR", "status shows clear on completion")

	var fresh: StageFlowRuntime = StageFlowRuntimeScript.new()
	_assert_eq(fresh.status_label(), "READY", "idle run before start shows ready")
	_assert_true(fresh.trigger_game_over(), "first game over trigger succeeds")
	_assert_true(not fresh.trigger_game_over(), "repeated game over trigger is a no-op")
	_assert_true(fresh.game_over, "game over sets the flag")
	_assert_true(not fresh.game_complete, "game over without completion is not a clear")
	_assert_true(not fresh.run_active, "game over deactivates the run")
	_assert_eq(fresh.status_label(), "GAME OVER", "status shows game over")

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
