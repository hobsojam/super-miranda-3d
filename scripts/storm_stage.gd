class_name StormStage
extends Node

const STAGE_TRANSITION_TIME := 1.85

@export var storm_path: NodePath
@export var runner_path: NodePath
@export var player_path: NodePath
@export var hud_label_path: NodePath
@export var hit_window: float = 4.2
@export var lives: int = 3
@export var bullet_speed: float = 140.0
@export var bullet_range: float = 220.0
@export var hazard_reveal_distance: float = 520.0
@export var hazard_closing_speed: float = 0.0
@export var low_intensity_obstacles: int = 0
@export var high_intensity_obstacles: int = 5
@export var music_crossfade_speed: float = 1.5
@export var flipper_hop_interval: float = 0.45
@export var spiker_retreat_speed: float = 7.0
@export var spiker_drop_spacing: float = 70.0
@export var spiker_lane_step_interval: float = 1.35
@export var pulsar_fire_interval: float = 2.0
@export var pulsar_bolt_speed: float = 95.0
@export var exploder_fuse_time: float = 0.7
@export var damage_invulnerability_time: float = 0.85

var _storm: StormTube
var _runner: Node
var _player: StormPlayer
var _hud_label: Label
var _hud: StageHud
var _audio: StageAudio
var _rim_obstacles: RimObstacleManager
var _hazards: StageHazardRuntime
var _pickups: StagePickupRuntime
var _projectiles: StageProjectileRuntime
var _enemy_skills: EnemySkillRuntime
var _flow: StageFlowRuntime
var _active_markers: Dictionary = {}
var _pickup_markers: Dictionary = {}
var _score: int = 0
var _damage_invulnerability_timer: float = 0.0

func _ready() -> void:
	_storm = get_node(storm_path) as StormTube
	_runner = get_node(runner_path)
	_player = get_node(player_path) as StormPlayer
	_hud_label = get_node(hud_label_path) as Label
	_player.fire_requested.connect(_on_player_fire_requested)
	_setup_audio()
	_setup_hud()
	_setup_hazards()
	_setup_pickups()
	_setup_projectiles()
	_setup_enemy_skills()
	_setup_rim_obstacles()
	_flow = StageFlowRuntime.new()
	_build_stage_for(1)
	_runner.set_input_enabled(false)
	_player.set_fire_enabled(false)
	_hud.show_start_screen()
	_update_hud()

func _exit_tree() -> void:
	if _audio:
		_audio.stop_all()
	_clear_active_state()
	if _hud:
		_hud.queue_free()

func _process(delta: float) -> void:
	_update_music_intensity(delta)
	_damage_invulnerability_timer = maxf(_damage_invulnerability_timer - delta, 0.0)
	_hud.tick_notice(delta)
	_hud.tick_pickup_banner(delta)

	if _flow.stage_transition_timer > 0.0:
		if _flow.tick_transition(delta):
			_continue_to_pending_stage()
		_update_hud()
		return

	if Input.is_key_pressed(KEY_R):
		restart_stage()
		return

	if _flow.is_run_blocked():
		if Input.is_action_just_pressed("ui_accept") and _hud.should_accept_shortcut_start():
			_start_game()
		return

	_flow.tick(delta)

	var player_distance: float = _runner.distance()
	var player_lane: int = _runner.lane_index()

	_update_hazards(delta)
	_update_pickups(player_distance, player_lane)
	_update_bullets(delta)
	_update_enemy_bolts(delta, player_distance, player_lane)
	_update_rim_obstacles(delta, player_lane)
	_check_rim_obstacle_collision(player_lane)

	for hazard in _hazards.all():
		if hazard.cleared:
			continue
		if not hazard.spawned:
			if _hazards.should_activate(hazard, player_distance):
				_activate_hazard(hazard)
			else:
				continue
		var relative: float = hazard.distance - player_distance
		if _hazards.has_passed_player(hazard, player_distance):
			_remove_marker(hazard)
			if RimObstacleManager.should_anchor_kind(hazard.kind):
				_anchor_rim_obstacle(hazard)
			else:
				hazard.cleared = true
			continue
		if _hazards.should_show(hazard, player_distance):
			_ensure_marker(hazard)
			_update_hazard_skill(hazard, delta, player_distance)
			if hazard.cleared:
				continue
			_update_marker_pose(hazard)
		if absf(relative) <= hit_window and hazard.lane == player_lane and _can_damage_player():
			_hit_player(hazard)

	if player_distance >= _stage_end_distance():
		_advance_stage()

	_update_hud()

func restart_stage() -> void:
	_start_stage(_hud.selected_start_stage)

func is_menu_screen_active() -> bool:
	return _hud != null and _hud.is_state_overlay_visible()

func _start_stage(stage: int) -> void:
	lives = 3
	_score = 0
	_damage_invulnerability_timer = 0.0
	_flow.start_stage(stage)
	_hud.selected_start_stage = _flow.stage
	_hud.clear_notice()
	_hud.clear_pickup_banner()
	_runner.set_input_enabled(true)
	_player.set_fire_enabled(true)
	_player.reset_fire_cooldown()
	_runner.restart_run()
	_clear_active_state()
	_build_stage_for(_flow.stage)
	_storm.set_guide_overdraw_enabled(_stage_guide_overdraw_enabled(_flow.stage))
	_audio.load_music_stage(_flow.stage)
	_hud.hide_state_overlay()
	_update_hud()

func _start_game() -> void:
	_start_stage(_hud.selected_start_stage)

func _on_player_fire_requested() -> void:
	if _flow.is_run_blocked():
		return
	_fire()

func _build_stage_for(stage: int) -> void:
	_hazards.clear()
	_pickups.clear()
	var definition: Dictionary = _stage_definition(stage)
	for entry in definition["hazards"]:
		_add_stage_hazard(entry["distance"], entry["lane"], entry["kind"])
	for gate_pair in definition["gate_pairs"]:
		_add_gate_pair(
			gate_pair["distance"],
			gate_pair["start_lane"],
			gate_pair["end_lane"],
			gate_pair["gate_id"]
		)
	for pickup in definition["pickups"]:
		_add_pickup(pickup["distance"], pickup["lane"], pickup["kind"])

func _stage_definition(stage: int) -> Dictionary:
	if stage == 2:
		return {
			"hazards": StageTwoDefinition.hazards(),
			"pickups": StageTwoDefinition.pickups(),
			"gate_pairs": StageTwoDefinition.gate_pairs(),
		}
	return {
		"hazards": StageOneDefinition.hazards(),
		"pickups": StageOneDefinition.pickups(),
		"gate_pairs": StageOneDefinition.gate_pairs(),
	}

func _stage_guide_overdraw_enabled(stage: int) -> bool:
	if stage == 2:
		return StageTwoDefinition.guide_overdraw_enabled()
	return StageOneDefinition.guide_overdraw_enabled()

func _add_stage_hazard(
	distance: float,
	lane: int,
	kind: String,
	gate_id: int = -1
) -> StageHazardRuntime.Hazard:
	return _hazards.add_hazard(distance, lane, kind, gate_id)

func _add_gate_pair(distance: float, start_lane: int, end_lane: int, gate_id: int) -> void:
	_hazards.add_gate_pair(distance, start_lane, end_lane, gate_id)

func _add_pickup(distance: float, lane: int, kind: String) -> void:
	_pickups.add_pickup(distance, lane, kind)

func _activate_hazard(hazard: StageHazardRuntime.Hazard) -> void:
	hazard.spawned = true
	_ensure_marker(hazard)
	_update_marker_pose(hazard)

func _update_hazards(delta: float) -> void:
	_hazards.update_closing(delta, hazard_closing_speed)

func _update_pickups(player_distance: float, player_lane: int) -> void:
	for pickup in _pickups.all():
		if pickup.cleared:
			continue
		if not pickup.spawned:
			if _pickups.should_activate(pickup, player_distance):
				_activate_pickup(pickup)
			else:
				continue
		if _pickups.has_passed_player(pickup, player_distance):
			_remove_pickup_marker(pickup)
			_pickups.clear_pickup(pickup)
			continue
		if _pickups.should_show(pickup, player_distance):
			_ensure_pickup_marker(pickup)
			_update_pickup_marker_pose(pickup)
		if _pickups.can_collect(pickup, player_distance, player_lane):
			_collect_pickup(pickup)

func _activate_pickup(pickup: StagePickupRuntime.Pickup) -> void:
	_pickups.activate(pickup)
	_ensure_pickup_marker(pickup)
	_update_pickup_marker_pose(pickup)

func _update_hazard_skill(
	hazard: StageHazardRuntime.Hazard,
	delta: float,
	player_distance: float
) -> void:
	var event: Dictionary = _enemy_skills.update(hazard, delta, player_distance, _stage_end_distance())
	if event.is_empty():
		return
	match event["type"]:
		"cleared":
			_remove_marker(hazard)
		"spike_drop":
			_spawn_hazard(event["distance"], event["lane"], "spike")
		"fire_bolt":
			_fire_enemy_bolt(event["lane"], event["distance"])

func _spawn_hazard(distance: float, lane: int, kind: String) -> StageHazardRuntime.Hazard:
	return _hazards.spawn_hazard(distance, lane, kind)

func _stage_end_distance() -> float:
	return maxf(_storm.route_length, 1.0)

func _setup_hud() -> void:
	_hud = StageHud.new()
	add_child(_hud)
	_hud.setup(_hud_label)
	_hud.start_pressed.connect(_start_game)
	_hud.exit_pressed.connect(_on_hud_exit_pressed)
	_hud.stage_selected.connect(_on_hud_stage_selected)

func _setup_hazards() -> void:
	_hazards = StageHazardRuntime.new()
	_hazards.setup(
		_storm.lane_count,
		_stage_end_distance(),
		hit_window,
		hazard_reveal_distance,
		pulsar_fire_interval,
		spiker_lane_step_interval
	)

func _setup_pickups() -> void:
	_pickups = StagePickupRuntime.new()
	_pickups.setup(_storm.lane_count, hit_window, hazard_reveal_distance)

func _setup_projectiles() -> void:
	_projectiles = StageProjectileRuntime.new()
	_projectiles.setup(bullet_speed, bullet_range, pulsar_bolt_speed, hit_window)

func _setup_enemy_skills() -> void:
	_enemy_skills = EnemySkillRuntime.new()
	_enemy_skills.setup(
		_storm.lane_count,
		hit_window,
		spiker_retreat_speed,
		spiker_drop_spacing,
		spiker_lane_step_interval,
		pulsar_fire_interval
	)

func _setup_rim_obstacles() -> void:
	_rim_obstacles = RimObstacleManager.new()
	_rim_obstacles.setup(_storm, _runner, flipper_hop_interval, exploder_fuse_time)

func _on_hud_exit_pressed() -> void:
	get_tree().quit()

func _on_hud_stage_selected(stage: int) -> void:
	if _flow.run_active:
		return
	_flow.stage = stage
	_storm.set_guide_overdraw_enabled(_stage_guide_overdraw_enabled(_flow.stage))
	_audio.load_music_stage(_flow.stage)
	_build_stage_for(_flow.stage)
	_update_hud()

func _advance_stage() -> void:
	_play_sfx(StageAudio.CLEAR_SOUND)
	_damage_invulnerability_timer = 0.0
	var completed_stage: int = _flow.stage
	var next_stage: int = completed_stage + 1
	_clear_markers()
	_clear_pickup_markers()
	_clear_bullets()
	_clear_enemy_bolts()
	_burst_rim_obstacles()
	_clear_rim_obstacles()
	for hazard in _hazards.all():
		hazard.cleared = true
	if next_stage == 2:
		_flow.begin_stage_clear_transition(next_stage, STAGE_TRANSITION_TIME)
		_score += _flow.last_stage_time_bonus
		_runner.set_input_enabled(false)
		_player.set_fire_enabled(false)
		_hud.show_stage_clear_screen(
			completed_stage,
			_score,
			_format_stage_time(_flow.stage_elapsed_time),
			_flow.last_stage_time_bonus,
			next_stage
		)
		_update_hud()
		return
	_flow.complete_run()
	_score += _flow.last_stage_time_bonus
	_runner.set_input_enabled(false)
	_player.set_fire_enabled(false)
	_hud.show_complete_screen(_score)
	_update_hud()

func _continue_to_pending_stage() -> void:
	if not _flow.continue_to_pending():
		return
	_damage_invulnerability_timer = 0.0
	_hud.clear_notice()
	_hud.clear_pickup_banner()
	_runner.restart_run()
	_runner.set_input_enabled(true)
	_player.set_fire_enabled(true)
	_player.reset_fire_cooldown()
	_storm.set_guide_overdraw_enabled(_stage_guide_overdraw_enabled(_flow.stage))
	_audio.load_music_stage(_flow.stage)
	_build_stage_for(_flow.stage)
	_hud.hide_state_overlay()

func _clear_active_state() -> void:
	_clear_markers()
	_clear_pickup_markers()
	_clear_bullets()
	_clear_enemy_bolts()
	_clear_rim_obstacles()

func _format_stage_time(seconds: float) -> String:
	return StageRules.format_stage_time(seconds)

func _ensure_marker(hazard: StageHazardRuntime.Hazard) -> void:
	if _active_markers.has(hazard):
		return
	var marker: Node3D = StageMarkerFactory.build_enemy_marker(hazard.kind)
	_storm.add_child(marker)
	_active_markers[hazard] = marker

func _update_marker_pose(hazard: StageHazardRuntime.Hazard) -> void:
	var marker: Node3D = _active_markers[hazard] as Node3D
	if marker == null:
		return
	var sample: StormTube.RouteSample = _storm.sample_at_distance(hazard.distance)
	var lane_angle: float = _runner.lane_angle_for_index(hazard.lane)
	var radial: Vector3 = sample.right * cos(lane_angle) + sample.up * sin(lane_angle)
	var forward: Vector3 = sample.tangent.normalized()
	var side: Vector3 = radial.cross(forward).normalized()
	marker.global_position = sample.position + radial * (_storm.radius * 0.84)
	marker.global_basis = Basis(side, radial, -forward).orthonormalized()
	StageMarkerFactory.animate_enemy_art(marker, hazard.kind)

func _hit_player(hazard: StageHazardRuntime.Hazard) -> void:
	if hazard.kind == "gate_field":
		_damage_player(StageAudio.HIT_SOUND)
		return
	if hazard.kind == "gate_post":
		hazard.hit = true
		_damage_player(StageAudio.HIT_SOUND)
		_destroy_gate(hazard.gate_id, false)
		return
	hazard.hit = true
	hazard.cleared = true
	_remove_marker(hazard)
	_damage_player(
		StageAudio.EXPLODER_SOUND if hazard.kind == "exploder" else StageAudio.HIT_SOUND
	)

func _remove_marker(hazard: StageHazardRuntime.Hazard) -> void:
	if not _active_markers.has(hazard):
		return
	var marker: Node3D = _active_markers[hazard] as Node3D
	_active_markers.erase(hazard)
	marker.queue_free()

func _clear_markers() -> void:
	for marker in _active_markers.values():
		(marker as Node3D).queue_free()
	_active_markers.clear()

func _ensure_pickup_marker(pickup: StagePickupRuntime.Pickup) -> void:
	if _pickup_markers.has(pickup):
		return
	var marker: Node3D = StageMarkerFactory.build_pickup_marker(pickup.kind)
	_storm.add_child(marker)
	_pickup_markers[pickup] = marker

func _update_pickup_marker_pose(pickup: StagePickupRuntime.Pickup) -> void:
	var marker: Node3D = _pickup_markers[pickup] as Node3D
	if marker == null:
		return
	var sample: StormTube.RouteSample = _storm.sample_at_distance(pickup.distance)
	var lane_angle: float = _runner.lane_angle_for_index(pickup.lane)
	var radial: Vector3 = sample.right * cos(lane_angle) + sample.up * sin(lane_angle)
	var forward: Vector3 = sample.tangent.normalized()
	var side: Vector3 = radial.cross(forward).normalized()
	marker.global_position = sample.position + radial * (_storm.radius * 0.78)
	marker.global_basis = Basis(side, radial, -forward).orthonormalized()
	StageMarkerFactory.animate_pickup_art(marker, pickup.kind)

func _remove_pickup_marker(pickup: StagePickupRuntime.Pickup) -> void:
	if not _pickup_markers.has(pickup):
		return
	var marker: Node3D = _pickup_markers[pickup] as Node3D
	_pickup_markers.erase(pickup)
	marker.queue_free()

func _clear_pickup_markers() -> void:
	for marker in _pickup_markers.values():
		(marker as Node3D).queue_free()
	_pickup_markers.clear()

func _collect_pickup(pickup: StagePickupRuntime.Pickup) -> void:
	_pickups.clear_pickup(pickup)
	var collect_position: Vector3 = (
		(_pickup_markers[pickup] as Node3D).global_position
		if _pickup_markers.has(pickup)
		else _runner.global_position
	)
	_remove_pickup_marker(pickup)
	_spawn_pickup_collect_effect(collect_position, pickup.kind)
	match pickup.kind:
		"life":
			lives += 1
			_score += 500
			_hud.show_notice("EXTRA LIFE")
			_hud.flash_pickup("EXTRA LIFE", Color(0.45, 1.0, 0.55))
			_play_sfx(StageAudio.CLEAR_SOUND, -8.0)
		"purge":
			_score += 750
			_purge_rim_obstacles()
			_hud.show_notice("CLEARANCE PULSE")
			_hud.flash_pickup("CLEARANCE PULSE", Color(0.3, 1.0, 1.0))
			_play_sfx(StageAudio.EXPLODER_SOUND, -8.0)

func _destroy_pickup(pickup: StagePickupRuntime.Pickup) -> void:
	_pickups.clear_pickup(pickup)
	_remove_pickup_marker(pickup)
	_play_sfx(StageAudio.KILL_SOUND, -12.0)

func _purge_rim_obstacles() -> void:
	for position in _rim_obstacles.purge():
		_spawn_burst(position)

func _spawn_pickup_collect_effect(position: Vector3, kind: String) -> void:
	var effect: Node3D = Node3D.new()
	effect.global_position = position
	var material: StandardMaterial3D = StageMarkerFactory.pickup_accent_material(kind)
	for i in 12:
		var shard: MeshInstance3D = MeshInstance3D.new()
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(0.09, 0.09, 0.55)
		shard.mesh = mesh
		var angle: float = TAU * float(i) / 12.0
		shard.position = Vector3(cos(angle), sin(angle), 0.0) * 0.42
		shard.rotation = Vector3(0.0, 0.0, angle)
		shard.material_override = material
		effect.add_child(shard)
	_storm.add_child(effect)
	var tween: Tween = create_tween()
	tween.tween_property(effect, "scale", Vector3.ONE * 3.1, 0.28)
	tween.parallel().tween_property(effect, "rotation", Vector3(0.0, 0.0, TAU * 0.18), 0.28)
	tween.tween_callback(effect.queue_free)

func _fire() -> void:
	var bullet_marker: Node3D = StageMarkerFactory.build_bullet_marker()
	var bullet: StageProjectileRuntime.Bullet = _projectiles.fire_bullet(
		_runner.lane_index(),
		_runner.distance(),
		bullet_marker
	)
	_storm.add_child(bullet.marker)
	_play_sfx(StageAudio.FIRE_SOUND, -7.0)

func _update_bullets(delta: float) -> void:
	for i in range(_projectiles.bullet_count() - 1, -1, -1):
		var bullet: StageProjectileRuntime.Bullet = _projectiles.bullets()[i]
		var previous_distance: float = _projectiles.advance_bullet(bullet, delta)
		var hit_pickup: StagePickupRuntime.Pickup = _projectiles.find_bullet_pickup_hit(
			bullet,
			previous_distance,
			_pickups.all()
		)
		var hit_hazard: StageHazardRuntime.Hazard = _projectiles.find_bullet_hazard_hit(
			bullet,
			previous_distance,
			_hazards.all()
		)
		if hit_pickup != null and (hit_hazard == null or hit_pickup.distance <= hit_hazard.distance):
			_destroy_pickup(hit_pickup)
			bullet.marker.queue_free()
			_projectiles.remove_bullet(bullet)
			continue
		if hit_hazard != null:
			_destroy_hazard(hit_hazard)
			bullet.marker.queue_free()
			_projectiles.remove_bullet(bullet)
			continue
		if _projectiles.bullet_expired(bullet, _storm.route_length):
			bullet.marker.queue_free()
			_projectiles.remove_bullet(bullet)
			continue
		_update_bullet_pose(bullet)

func _destroy_hazard(hazard: StageHazardRuntime.Hazard) -> void:
	if hazard.kind == "gate_post":
		_destroy_gate(hazard.gate_id)
		return
	hazard.cleared = true
	_score += 250
	_remove_marker(hazard)
	if hazard.kind == "splitter":
		_spawn_hazard(hazard.distance + 8.0, hazard.lane - 1, "flipper")
		_spawn_hazard(hazard.distance + 8.0, hazard.lane + 1, "flipper")
		_play_sfx(StageAudio.KILL_SOUND, -3.5)
		return
	_play_sfx(
		StageAudio.EXPLODER_SOUND if hazard.kind == "exploder" else StageAudio.KILL_SOUND,
		-4.0
	)

func _destroy_gate(gate_id: int, award_score: bool = true) -> void:
	if gate_id < 0:
		return
	var destroyed: bool = false
	for hazard in _hazards.all():
		if hazard.gate_id != gate_id or hazard.cleared:
			continue
		hazard.cleared = true
		destroyed = true
		if _active_markers.has(hazard):
			var marker: Node3D = _active_markers[hazard] as Node3D
			_spawn_burst(marker.global_position)
		_remove_marker(hazard)
	if destroyed:
		if award_score:
			_score += 750
			_play_sfx(StageAudio.KILL_SOUND, -3.5)

func _update_bullet_pose(bullet: StageProjectileRuntime.Bullet) -> void:
	var sample: StormTube.RouteSample = _storm.sample_at_distance(bullet.distance)
	var lane_angle: float = _runner.lane_angle_for_index(bullet.lane)
	var radial: Vector3 = sample.right * cos(lane_angle) + sample.up * sin(lane_angle)
	var forward: Vector3 = sample.tangent.normalized()
	var side: Vector3 = radial.cross(forward).normalized()
	bullet.marker.global_position = sample.position + radial * (_storm.radius * 0.78)
	bullet.marker.global_basis = Basis(side, radial, -forward).orthonormalized()

func _clear_bullets() -> void:
	for bullet in _projectiles.bullets():
		bullet.marker.queue_free()
	_projectiles.clear_bullets()

func _fire_enemy_bolt(lane: int, distance: float) -> void:
	var bolt_marker: Node3D = StageMarkerFactory.build_enemy_bolt_marker()
	var bolt: StageProjectileRuntime.EnemyBolt = _projectiles.fire_enemy_bolt(
		lane,
		distance,
		bolt_marker
	)
	_storm.add_child(bolt.marker)
	_update_enemy_bolt_pose(bolt)

func _update_enemy_bolts(delta: float, player_distance: float, player_lane: int) -> void:
	for i in range(_projectiles.enemy_bolt_count() - 1, -1, -1):
		var bolt: StageProjectileRuntime.EnemyBolt = _projectiles.enemy_bolts()[i]
		_projectiles.advance_enemy_bolt(bolt, delta)
		if _projectiles.enemy_bolt_reached_player(bolt, player_distance):
			if bolt.lane == player_lane:
				_damage_player(StageAudio.HIT_SOUND)
				if _flow.game_over:
					return
			bolt.marker.queue_free()
			_projectiles.remove_enemy_bolt(bolt)
			continue
		if _projectiles.enemy_bolt_expired_behind(bolt, player_distance):
			bolt.marker.queue_free()
			_projectiles.remove_enemy_bolt(bolt)
			continue
		_update_enemy_bolt_pose(bolt)

func _update_enemy_bolt_pose(bolt: StageProjectileRuntime.EnemyBolt) -> void:
	var sample: StormTube.RouteSample = _storm.sample_at_distance(bolt.distance)
	var lane_angle: float = _runner.lane_angle_for_index(bolt.lane)
	var radial: Vector3 = sample.right * cos(lane_angle) + sample.up * sin(lane_angle)
	var forward: Vector3 = sample.tangent.normalized()
	var side: Vector3 = radial.cross(forward).normalized()
	bolt.marker.global_position = sample.position + radial * (_storm.radius * 0.80)
	bolt.marker.global_basis = Basis(side, radial, forward).orthonormalized()

func _clear_enemy_bolts() -> void:
	for bolt in _projectiles.enemy_bolts():
		bolt.marker.queue_free()
	_projectiles.clear_enemy_bolts()

func _anchor_rim_obstacle(hazard: StageHazardRuntime.Hazard) -> void:
	if hazard.anchored or hazard.hit:
		return
	hazard.anchored = true
	hazard.cleared = true
	_rim_obstacles.anchor(hazard.lane, hazard.kind)

func _update_rim_obstacles(delta: float, player_lane: int) -> void:
	for event in _rim_obstacles.update(delta, player_lane, _runner.speed()):
		_spawn_burst(event["position"])
		if event["type"] == "decayed":
			_play_sfx(StageAudio.KILL_SOUND, -8.0)
		elif event["type"] == "exploded":
			_damage_player(StageAudio.EXPLODER_SOUND)
			if _flow.game_over:
				return

func _check_rim_obstacle_collision(player_lane: int) -> void:
	if not _can_damage_player():
		return
	var collision: Dictionary = _rim_obstacles.take_collision(player_lane)
	if collision.is_empty():
		return
	_damage_player(
		StageAudio.EXPLODER_SOUND if collision["kind"] == "exploder" else StageAudio.HIT_SOUND
	)

func _damage_player(sound: AudioStream) -> void:
	if not _can_damage_player():
		return
	lives = maxi(lives - 1, 0)
	_damage_invulnerability_timer = damage_invulnerability_time
	if _runner.has_method("play_damage_feedback"):
		_runner.play_damage_feedback(damage_invulnerability_time)
	_play_sfx(sound, StageAudio.damage_sound_volume(sound))
	if lives == 0:
		_trigger_game_over()

func _can_damage_player() -> bool:
	return not _flow.game_over and _damage_invulnerability_timer <= 0.0

func _trigger_game_over() -> void:
	if not _flow.trigger_game_over():
		return
	_runner.set_input_enabled(false)
	_player.set_fire_enabled(false)
	_clear_active_state()
	_play_sfx(StageAudio.GAME_OVER_SOUND, -2.0)
	_hud.show_game_over_screen(_score, _flow.stage)

func _burst_rim_obstacles() -> void:
	for position in _rim_obstacles.positions():
		_spawn_burst(position)
	if _rim_obstacles.count() > 0:
		_play_sfx(StageAudio.EXPLODER_SOUND, -5.0)

func _spawn_burst(position: Vector3) -> void:
	var burst: Node3D = StageMarkerFactory.build_burst_marker()
	burst.global_position = position
	_storm.add_child(burst)
	var tween: Tween = create_tween()
	tween.tween_property(burst, "scale", Vector3.ONE * 2.4, 0.24)
	tween.tween_callback(burst.queue_free)

func _clear_rim_obstacles() -> void:
	_rim_obstacles.clear()

func _setup_audio() -> void:
	_audio = StageAudio.new()
	add_child(_audio)
	_audio.setup(1)

func _update_music_intensity(delta: float) -> void:
	var active_pressure: int = _rim_obstacles.count()
	active_pressure += _hazards.active_pressure(_runner.distance())
	_audio.update_music_intensity(
		delta,
		active_pressure,
		low_intensity_obstacles,
		high_intensity_obstacles,
		music_crossfade_speed
	)

func _play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	_audio.play_sfx(stream, volume_db)

func _update_hud() -> void:
	var progress: int = int(clampf(_runner.distance() / _stage_end_distance(), 0.0, 1.0) * 100.0)
	var distance: int = int(_runner.distance())
	var speed: int = int(_runner.speed())
	var active_hazards: int = 0
	for hazard in _hazards.all():
		if hazard.spawned and not hazard.cleared:
			active_hazards += 1
	_hud.update_status(
		_flow.stage,
		distance,
		speed,
		_score,
		lives,
		_rim_obstacles.count(),
		active_hazards,
		progress,
		_flow.status_label()
	)
