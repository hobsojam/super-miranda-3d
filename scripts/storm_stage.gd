extends Node
class_name StormStage

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
var _hazards: Array[StageHazard] = []
var _pickups: Array[StagePickup] = []
var _bullets: Array[StageBullet] = []
var _enemy_bolts: Array[EnemyBolt] = []
var _active_markers: Dictionary = {}
var _pickup_markers: Dictionary = {}
var _rim_obstacles: Array[RimObstacle] = []
var _score: int = 0
var _stage: int = 1
var _game_over: bool = false
var _game_complete: bool = false
var _damage_invulnerability_timer: float = 0.0
var _stage_elapsed_time: float = 0.0
var _stage_transition_timer: float = 0.0
var _pending_stage: int = 0
var _last_stage_time_bonus: int = 0
var _run_active: bool = false

class StageHazard:
	var spawn_distance: float
	var lane: int
	var distance: float
	var kind: String
	var spawned: bool = false
	var cleared: bool = false
	var hit: bool = false
	var anchored: bool = false
	var skill_ready: bool = false
	var pulse_timer: float = 0.0
	var spike_drop_meter: float = 0.0
	var spiker_lane_timer: float = 0.0
	var spiker_lane_direction: int = 1
	var gate_id: int = -1

class StageBullet:
	var lane: int
	var distance: float
	var start_distance: float
	var marker: Node3D

class StagePickup:
	var spawn_distance: float
	var lane: int
	var distance: float
	var kind: String
	var spawned: bool = false
	var cleared: bool = false

class EnemyBolt:
	var lane: int
	var distance: float
	var marker: Node3D

class RimObstacle:
	var lane: int
	var kind: String
	var marker: Node3D
	var hop_timer: float = 0.0
	var fuse_timer: float = 0.0
	var stability: float = 1.0

func _ready() -> void:
	_storm = get_node(storm_path) as StormTube
	_runner = get_node(runner_path)
	_player = get_node(player_path) as StormPlayer
	_hud_label = get_node(hud_label_path) as Label
	_player.fire_requested.connect(_on_player_fire_requested)
	_setup_audio()
	_setup_hud()
	_build_stage_for(1)
	_runner.set_input_enabled(false)
	_player.set_fire_enabled(false)
	_hud.show_start_screen()
	_update_hud()

func _exit_tree() -> void:
	if _audio:
		_audio.stop_all()
	_clear_markers()
	_clear_pickup_markers()
	_clear_bullets()
	_clear_enemy_bolts()
	_clear_rim_obstacles()
	if _hud:
		_hud.queue_free()

func _process(delta: float) -> void:
	_update_music_intensity(delta)
	_damage_invulnerability_timer = maxf(_damage_invulnerability_timer - delta, 0.0)
	_hud.tick_notice(delta)

	if _stage_transition_timer > 0.0:
		_stage_transition_timer = maxf(_stage_transition_timer - delta, 0.0)
		if _stage_transition_timer <= 0.0:
			_continue_to_pending_stage()
		_update_hud()
		return

	if Input.is_key_pressed(KEY_R):
		restart_stage()
		return

	if not _run_active or _game_over:
		if Input.is_action_just_pressed("ui_accept"):
			_start_game()
		return

	_stage_elapsed_time += delta

	var player_distance: float = _runner.distance()
	var player_lane: int = _runner.lane_index()

	_update_hazards(delta)
	_update_pickups(player_distance, player_lane)
	_update_bullets(delta)
	_update_enemy_bolts(delta, player_distance, player_lane)
	_update_rim_obstacles(delta, player_lane)
	_check_rim_obstacle_collision(player_lane)

	for hazard in _hazards:
		if hazard.cleared:
			continue
		if not hazard.spawned:
			if player_distance >= hazard.spawn_distance:
				_activate_hazard(hazard)
			else:
				continue
		var relative: float = hazard.distance - player_distance
		if relative < -hit_window:
			_remove_marker(hazard)
			if _should_anchor_hazard(hazard):
				_anchor_rim_obstacle(hazard)
			else:
				hazard.cleared = true
			continue
		if relative < hazard_reveal_distance:
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

func _start_stage(stage: int) -> void:
	lives = 3
	_score = 0
	_stage = clampi(stage, 1, 2)
	_hud.selected_start_stage = _stage
	_game_over = false
	_game_complete = false
	_run_active = true
	_damage_invulnerability_timer = 0.0
	_hud.clear_notice()
	_stage_elapsed_time = 0.0
	_stage_transition_timer = 0.0
	_pending_stage = 0
	_last_stage_time_bonus = 0
	_runner.set_input_enabled(true)
	_player.set_fire_enabled(true)
	_player.reset_fire_cooldown()
	_runner.restart_run()
	_clear_markers()
	_clear_pickup_markers()
	_clear_bullets()
	_clear_enemy_bolts()
	_clear_rim_obstacles()
	_build_stage_for(_stage)
	_storm.set_guide_overdraw_enabled(_stage_guide_overdraw_enabled(_stage))
	_audio.load_music_stage(_stage)
	_hud.hide_state_overlay()
	_update_hud()

func _start_game() -> void:
	_start_stage(_hud.selected_start_stage)

func _on_player_fire_requested() -> void:
	if not _run_active or _game_over:
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

func _add_stage_hazard(distance: float, lane: int, kind: String, gate_id: int = -1) -> StageHazard:
	if distance >= _stage_end_distance() - hit_window:
		return null
	var hazard: StageHazard = StageHazard.new()
	hazard.distance = distance
	hazard.spawn_distance = maxf(hazard.distance - hazard_reveal_distance, 0.0)
	hazard.lane = wrapi(lane, 0, _storm.lane_count)
	hazard.kind = kind
	hazard.gate_id = gate_id
	_init_hazard_skill(hazard)
	_hazards.append(hazard)
	return hazard

func _add_gate_pair(distance: float, start_lane: int, end_lane: int, gate_id: int) -> void:
	for gate_part in StageRules.gate_lanes(start_lane, end_lane, _storm.lane_count):
		_add_stage_hazard(distance, gate_part["lane"], gate_part["kind"], gate_id)

func _add_pickup(distance: float, lane: int, kind: String) -> void:
	var pickup: StagePickup = StagePickup.new()
	pickup.distance = distance
	pickup.spawn_distance = maxf(pickup.distance - hazard_reveal_distance, 0.0)
	pickup.lane = wrapi(lane, 0, _storm.lane_count)
	pickup.kind = kind
	_pickups.append(pickup)

func _init_hazard_skill(hazard: StageHazard) -> void:
	hazard.skill_ready = false
	hazard.pulse_timer = pulsar_fire_interval
	hazard.spike_drop_meter = 0.0
	hazard.spiker_lane_timer = spiker_lane_step_interval
	hazard.spiker_lane_direction = 1 if hazard.lane % 2 == 0 else -1

func _activate_hazard(hazard: StageHazard) -> void:
	hazard.spawned = true
	_ensure_marker(hazard)
	_update_marker_pose(hazard)

func _update_hazards(delta: float) -> void:
	for hazard in _hazards:
		if not hazard.spawned or hazard.cleared:
			continue
		hazard.distance -= hazard_closing_speed * delta

func _update_pickups(player_distance: float, player_lane: int) -> void:
	for pickup in _pickups:
		if pickup.cleared:
			continue
		if not pickup.spawned:
			if player_distance >= pickup.spawn_distance:
				_activate_pickup(pickup)
			else:
				continue
		var relative: float = pickup.distance - player_distance
		if relative < -hit_window:
			_remove_pickup_marker(pickup)
			pickup.cleared = true
			continue
		if relative < hazard_reveal_distance:
			_ensure_pickup_marker(pickup)
			_update_pickup_marker_pose(pickup)
		if absf(relative) <= hit_window and pickup.lane == player_lane:
			_collect_pickup(pickup)

func _activate_pickup(pickup: StagePickup) -> void:
	pickup.spawned = true
	_ensure_pickup_marker(pickup)
	_update_pickup_marker_pose(pickup)

func _update_hazard_skill(hazard: StageHazard, delta: float, player_distance: float) -> void:
	match hazard.kind:
		"spiker":
			_update_spiker(hazard, delta, player_distance)
		"pulsar":
			_update_pulsar(hazard, delta)

func _update_spiker(hazard: StageHazard, delta: float, player_distance: float) -> void:
	var travel: float = spiker_retreat_speed * delta
	hazard.distance += travel
	if hazard.distance >= _stage_end_distance() - hit_window:
		hazard.cleared = true
		_remove_marker(hazard)
		return
	hazard.spike_drop_meter += travel
	hazard.spiker_lane_timer -= delta
	if hazard.spiker_lane_timer <= 0.0:
		hazard.spiker_lane_timer = spiker_lane_step_interval
		hazard.lane = wrapi(hazard.lane + hazard.spiker_lane_direction, 0, _storm.lane_count)
		hazard.spiker_lane_direction *= -1
	if hazard.spike_drop_meter >= spiker_drop_spacing:
		hazard.spike_drop_meter -= spiker_drop_spacing
		var drop_distance: float = hazard.distance - spiker_drop_spacing
		if drop_distance > player_distance + hit_window:
			_spawn_hazard(drop_distance, hazard.lane, "spike")

func _update_pulsar(hazard: StageHazard, delta: float) -> void:
	hazard.pulse_timer -= delta
	if hazard.pulse_timer > 0.0:
		return
	hazard.pulse_timer = pulsar_fire_interval
	_fire_enemy_bolt(hazard.lane, hazard.distance)

func _spawn_hazard(distance: float, lane: int, kind: String) -> StageHazard:
	if distance >= _stage_end_distance() - hit_window:
		return null
	var hazard: StageHazard = StageHazard.new()
	hazard.distance = distance
	hazard.spawn_distance = maxf(hazard.distance - hazard_reveal_distance, 0.0)
	hazard.lane = wrapi(lane, 0, _storm.lane_count)
	hazard.kind = kind
	hazard.spawned = true
	_init_hazard_skill(hazard)
	_hazards.append(hazard)
	return hazard

func _stage_end_distance() -> float:
	return maxf(_storm.route_length, 1.0)

func _setup_hud() -> void:
	_hud = StageHud.new()
	add_child(_hud)
	_hud.setup(_hud_label)
	_hud.start_pressed.connect(_start_game)
	_hud.exit_pressed.connect(_on_hud_exit_pressed)
	_hud.stage_selected.connect(_on_hud_stage_selected)

func _on_hud_exit_pressed() -> void:
	get_tree().quit()

func _on_hud_stage_selected(stage: int) -> void:
	if not _run_active:
		_stage = stage
		_storm.set_guide_overdraw_enabled(_stage_guide_overdraw_enabled(_stage))
		_audio.load_music_stage(_stage)
		_build_stage_for(_stage)
		_update_hud()

func _advance_stage() -> void:
	_play_sfx(StageAudio.CLEAR_SOUND)
	_damage_invulnerability_timer = 0.0
	var completed_stage: int = _stage
	var next_stage: int = _stage + 1
	_last_stage_time_bonus = _stage_clear_time_bonus(_stage_elapsed_time)
	_score += _last_stage_time_bonus
	_clear_markers()
	_clear_pickup_markers()
	_clear_bullets()
	_clear_enemy_bolts()
	_burst_rim_obstacles()
	_clear_rim_obstacles()
	for hazard in _hazards:
		hazard.cleared = true
	if next_stage == 2:
		_pending_stage = next_stage
		_stage_transition_timer = STAGE_TRANSITION_TIME
		_run_active = false
		_runner.set_input_enabled(false)
		_player.set_fire_enabled(false)
		_hud.show_stage_clear_screen(
			completed_stage,
			_score,
			_format_stage_time(_stage_elapsed_time),
			_last_stage_time_bonus,
			next_stage
		)
		_update_hud()
		return
	_runner.set_input_enabled(false)
	_player.set_fire_enabled(false)
	_game_over = true
	_game_complete = true
	_run_active = false
	_hud.show_complete_screen(_score)
	_update_hud()

func _continue_to_pending_stage() -> void:
	if _pending_stage <= 0:
		return
	_stage = _pending_stage
	_pending_stage = 0
	_stage_elapsed_time = 0.0
	_damage_invulnerability_timer = 0.0
	_hud.clear_notice()
	_runner.restart_run()
	_runner.set_input_enabled(true)
	_player.set_fire_enabled(true)
	_player.reset_fire_cooldown()
	_run_active = true
	_storm.set_guide_overdraw_enabled(_stage_guide_overdraw_enabled(_stage))
	_audio.load_music_stage(_stage)
	_build_stage_for(_stage)
	_hud.hide_state_overlay()

func _format_stage_time(seconds: float) -> String:
	return StageRules.format_stage_time(seconds)

func _stage_clear_time_bonus(seconds: float) -> int:
	return StageRules.stage_clear_time_bonus(seconds)

func _ensure_marker(hazard: StageHazard) -> void:
	if _active_markers.has(hazard):
		return
	var marker: Node3D = StageMarkerFactory.build_enemy_marker(hazard.kind)
	_storm.add_child(marker)
	_active_markers[hazard] = marker

func _update_marker_pose(hazard: StageHazard) -> void:
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

func _hit_player(hazard: StageHazard) -> void:
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

func _remove_marker(hazard: StageHazard) -> void:
	if not _active_markers.has(hazard):
		return
	var marker: Node3D = _active_markers[hazard] as Node3D
	_active_markers.erase(hazard)
	marker.queue_free()

func _clear_markers() -> void:
	for marker in _active_markers.values():
		(marker as Node3D).queue_free()
	_active_markers.clear()

func _ensure_pickup_marker(pickup: StagePickup) -> void:
	if _pickup_markers.has(pickup):
		return
	var marker: Node3D = StageMarkerFactory.build_pickup_marker(pickup.kind)
	_storm.add_child(marker)
	_pickup_markers[pickup] = marker

func _update_pickup_marker_pose(pickup: StagePickup) -> void:
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

func _remove_pickup_marker(pickup: StagePickup) -> void:
	if not _pickup_markers.has(pickup):
		return
	var marker: Node3D = _pickup_markers[pickup] as Node3D
	_pickup_markers.erase(pickup)
	marker.queue_free()

func _clear_pickup_markers() -> void:
	for marker in _pickup_markers.values():
		(marker as Node3D).queue_free()
	_pickup_markers.clear()

func _collect_pickup(pickup: StagePickup) -> void:
	pickup.cleared = true
	var collect_position: Vector3 = (_pickup_markers[pickup] as Node3D).global_position if _pickup_markers.has(pickup) else _runner.global_position
	_remove_pickup_marker(pickup)
	_spawn_pickup_collect_effect(collect_position, pickup.kind)
	match pickup.kind:
		"life":
			lives += 1
			_score += 500
			_hud.show_notice("EXTRA LIFE")
			_play_sfx(StageAudio.CLEAR_SOUND, -8.0)
		"purge":
			_score += 750
			_purge_rim_obstacles()
			_hud.show_notice("CLEARANCE PULSE")
			_play_sfx(StageAudio.EXPLODER_SOUND, -8.0)

func _destroy_pickup(pickup: StagePickup) -> void:
	pickup.cleared = true
	_remove_pickup_marker(pickup)
	_play_sfx(StageAudio.KILL_SOUND, -12.0)

func _purge_rim_obstacles() -> void:
	for obstacle in _rim_obstacles:
		_spawn_burst(obstacle.marker.global_position)
		obstacle.marker.queue_free()
	_rim_obstacles.clear()

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
	var bullet: StageBullet = StageBullet.new()
	bullet.lane = _runner.lane_index()
	bullet.distance = _runner.distance() + 4.0
	bullet.start_distance = bullet.distance
	bullet.marker = StageMarkerFactory.build_bullet_marker()
	_storm.add_child(bullet.marker)
	_bullets.append(bullet)
	_play_sfx(StageAudio.FIRE_SOUND, -7.0)

func _update_bullets(delta: float) -> void:
	for i in range(_bullets.size() - 1, -1, -1):
		var bullet: StageBullet = _bullets[i]
		var previous_distance: float = bullet.distance
		bullet.distance += bullet_speed * delta
		var hit_pickup: StagePickup = _find_bullet_pickup(bullet, previous_distance)
		var hit_hazard: StageHazard = _find_bullet_hit(bullet, previous_distance)
		if hit_pickup != null and (hit_hazard == null or hit_pickup.distance <= hit_hazard.distance):
			_destroy_pickup(hit_pickup)
			bullet.marker.queue_free()
			_bullets.remove_at(i)
			continue
		if hit_hazard != null:
			_destroy_hazard(hit_hazard)
			bullet.marker.queue_free()
			_bullets.remove_at(i)
			continue
		if bullet.distance > minf(bullet.start_distance + bullet_range, _storm.route_length):
			bullet.marker.queue_free()
			_bullets.remove_at(i)
			continue
		_update_bullet_pose(bullet)

func _find_bullet_hit(bullet: StageBullet, previous_distance: float) -> StageHazard:
	var best: StageHazard = null
	var best_distance: float = INF
	for hazard in _hazards:
		if not hazard.spawned or hazard.cleared or hazard.lane != bullet.lane:
			continue
		if hazard.kind == "gate_field":
			continue
		if hazard.distance < previous_distance or hazard.distance > bullet.distance + hit_window:
			continue
		if hazard.distance < best_distance:
			best = hazard
			best_distance = hazard.distance
	return best

func _find_bullet_pickup(bullet: StageBullet, previous_distance: float) -> StagePickup:
	var best: StagePickup = null
	var best_distance: float = INF
	for pickup in _pickups:
		if not pickup.spawned or pickup.cleared or pickup.lane != bullet.lane:
			continue
		if pickup.distance < previous_distance or pickup.distance > bullet.distance + hit_window:
			continue
		if pickup.distance < best_distance:
			best = pickup
			best_distance = pickup.distance
	return best

func _destroy_hazard(hazard: StageHazard) -> void:
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
	for hazard in _hazards:
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

func _update_bullet_pose(bullet: StageBullet) -> void:
	var sample: StormTube.RouteSample = _storm.sample_at_distance(bullet.distance)
	var lane_angle: float = _runner.lane_angle_for_index(bullet.lane)
	var radial: Vector3 = sample.right * cos(lane_angle) + sample.up * sin(lane_angle)
	var forward: Vector3 = sample.tangent.normalized()
	var side: Vector3 = radial.cross(forward).normalized()
	bullet.marker.global_position = sample.position + radial * (_storm.radius * 0.78)
	bullet.marker.global_basis = Basis(side, radial, -forward).orthonormalized()

func _clear_bullets() -> void:
	for bullet in _bullets:
		bullet.marker.queue_free()
	_bullets.clear()

func _fire_enemy_bolt(lane: int, distance: float) -> void:
	var bolt: EnemyBolt = EnemyBolt.new()
	bolt.lane = lane
	bolt.distance = distance
	bolt.marker = StageMarkerFactory.build_enemy_bolt_marker()
	_storm.add_child(bolt.marker)
	_enemy_bolts.append(bolt)
	_update_enemy_bolt_pose(bolt)

func _update_enemy_bolts(delta: float, player_distance: float, player_lane: int) -> void:
	for i in range(_enemy_bolts.size() - 1, -1, -1):
		var bolt: EnemyBolt = _enemy_bolts[i]
		bolt.distance -= pulsar_bolt_speed * delta
		if bolt.distance <= player_distance + hit_window:
			if bolt.lane == player_lane:
				_damage_player(StageAudio.HIT_SOUND)
				if _game_over:
					return
			bolt.marker.queue_free()
			_enemy_bolts.remove_at(i)
			continue
		if bolt.distance < player_distance - 40.0:
			bolt.marker.queue_free()
			_enemy_bolts.remove_at(i)
			continue
		_update_enemy_bolt_pose(bolt)

func _update_enemy_bolt_pose(bolt: EnemyBolt) -> void:
	var sample: StormTube.RouteSample = _storm.sample_at_distance(bolt.distance)
	var lane_angle: float = _runner.lane_angle_for_index(bolt.lane)
	var radial: Vector3 = sample.right * cos(lane_angle) + sample.up * sin(lane_angle)
	var forward: Vector3 = sample.tangent.normalized()
	var side: Vector3 = radial.cross(forward).normalized()
	bolt.marker.global_position = sample.position + radial * (_storm.radius * 0.80)
	bolt.marker.global_basis = Basis(side, radial, forward).orthonormalized()

func _clear_enemy_bolts() -> void:
	for bolt in _enemy_bolts:
		bolt.marker.queue_free()
	_enemy_bolts.clear()

func _anchor_rim_obstacle(hazard: StageHazard) -> void:
	if hazard.anchored or hazard.hit:
		return
	hazard.anchored = true
	hazard.cleared = true
	var obstacle: RimObstacle = RimObstacle.new()
	obstacle.lane = hazard.lane
	obstacle.kind = hazard.kind
	obstacle.hop_timer = flipper_hop_interval
	obstacle.fuse_timer = exploder_fuse_time
	obstacle.marker = _build_obstacle_marker(hazard.kind)
	_storm.add_child(obstacle.marker)
	_rim_obstacles.append(obstacle)
	_update_rim_obstacle_pose(obstacle, _lane_stack_index(obstacle))

func _should_anchor_hazard(hazard: StageHazard) -> bool:
	return hazard.kind != "gate_field" and hazard.kind != "gate_post"

func _build_obstacle_marker(kind: String) -> Node3D:
	var marker: Node3D = StageMarkerFactory.build_enemy_marker(kind)
	marker.scale = Vector3.ONE * 1.15
	return marker

func _update_rim_obstacles(delta: float, player_lane: int) -> void:
	for i in range(_rim_obstacles.size() - 1, -1, -1):
		var obstacle: RimObstacle = _rim_obstacles[i]
		if _decay_anchor_obstacle(obstacle, delta):
			_rim_obstacles.remove_at(i)
			continue
		match obstacle.kind:
			"flipper":
				obstacle.hop_timer -= delta
				if obstacle.hop_timer <= 0.0:
					obstacle.hop_timer = flipper_hop_interval
					obstacle.lane = _step_lane_toward(obstacle.lane, player_lane)
			"exploder":
				obstacle.fuse_timer -= delta
				if obstacle.fuse_timer <= 0.0:
					_spawn_burst(obstacle.marker.global_position)
					obstacle.marker.queue_free()
					_rim_obstacles.remove_at(i)
					_damage_player(StageAudio.EXPLODER_SOUND)
					if _game_over:
						return
					continue
		_update_rim_obstacle_pose(obstacle, _lane_stack_index(obstacle))

func _decay_anchor_obstacle(obstacle: RimObstacle, delta: float) -> bool:
	var decay: float = StageRules.anchor_decay_amount(_runner.speed(), delta)
	if decay <= 0.0:
		return false
	obstacle.stability -= decay
	var pulse_scale: float = 1.0 + (1.0 - obstacle.stability) * 0.18
	obstacle.marker.scale = Vector3.ONE * 1.15 * pulse_scale
	if obstacle.stability > 0.0:
		return false
	_spawn_burst(obstacle.marker.global_position)
	obstacle.marker.queue_free()
	_play_sfx(StageAudio.KILL_SOUND, -8.0)
	return true

func _step_lane_toward(from_lane: int, target_lane: int) -> int:
	var count: int = _storm.lane_count
	var diff: int = target_lane - from_lane
	diff = ((diff % count) + count) % count
	if diff > count / 2:
		diff -= count
	if diff == 0:
		return from_lane
	var step: int = 1 if diff > 0 else -1
	return wrapi(from_lane + step, 0, count)

func _update_rim_obstacle_pose(obstacle: RimObstacle, stack_index: int) -> void:
	var sample: StormTube.RouteSample = _storm.sample_at_distance(_runner.distance() + 1.8)
	var lane_angle: float = _runner.lane_angle_for_index(obstacle.lane)
	var radial: Vector3 = sample.right * cos(lane_angle) + sample.up * sin(lane_angle)
	var forward: Vector3 = sample.tangent.normalized()
	var side: Vector3 = radial.cross(forward).normalized()
	var side_offset: float = _stack_offset(stack_index)
	obstacle.marker.global_position = sample.position + radial * (_storm.radius * 0.86) + side * side_offset
	obstacle.marker.global_basis = Basis(side, radial, -forward).orthonormalized()
	StageMarkerFactory.animate_enemy_art(obstacle.marker, obstacle.kind)

func _lane_stack_index(obstacle: RimObstacle) -> int:
	var index: int = 0
	for other in _rim_obstacles:
		if other == obstacle:
			return index
		if other.lane == obstacle.lane:
			index += 1
	return index

func _stack_offset(index: int) -> float:
	if index == 0:
		return 0.0
	var side: float = 1.0 if index % 2 == 1 else -1.0
	return side * ceil(float(index) / 2.0) * 0.62

func _check_rim_obstacle_collision(player_lane: int) -> void:
	if not _can_damage_player():
		return
	for i in range(_rim_obstacles.size() - 1, -1, -1):
		var obstacle: RimObstacle = _rim_obstacles[i]
		if obstacle.lane != player_lane:
			continue
		obstacle.marker.queue_free()
		_rim_obstacles.remove_at(i)
		_damage_player(
			StageAudio.EXPLODER_SOUND if obstacle.kind == "exploder" else StageAudio.HIT_SOUND
		)
		return

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
	return not _game_over and _damage_invulnerability_timer <= 0.0

func _trigger_game_over() -> void:
	if _game_over:
		return
	_game_over = true
	_game_complete = false
	_run_active = false
	_runner.set_input_enabled(false)
	_player.set_fire_enabled(false)
	_clear_markers()
	_clear_pickup_markers()
	_clear_bullets()
	_clear_enemy_bolts()
	_clear_rim_obstacles()
	_play_sfx(StageAudio.GAME_OVER_SOUND, -2.0)
	_hud.show_game_over_screen(_score, _stage)

func _burst_rim_obstacles() -> void:
	for obstacle in _rim_obstacles:
		_spawn_burst(obstacle.marker.global_position)
	if not _rim_obstacles.is_empty():
		_play_sfx(StageAudio.EXPLODER_SOUND, -5.0)

func _spawn_burst(position: Vector3) -> void:
	var burst: Node3D = StageMarkerFactory.build_burst_marker()
	burst.global_position = position
	_storm.add_child(burst)
	var tween: Tween = create_tween()
	tween.tween_property(burst, "scale", Vector3.ONE * 2.4, 0.24)
	tween.tween_callback(burst.queue_free)

func _clear_rim_obstacles() -> void:
	for obstacle in _rim_obstacles:
		obstacle.marker.queue_free()
	_rim_obstacles.clear()

func _setup_audio() -> void:
	_audio = StageAudio.new()
	add_child(_audio)
	_audio.setup(1)

func _update_music_intensity(delta: float) -> void:
	var active_pressure: int = _rim_obstacles.size()
	for hazard in _hazards:
		if hazard.spawned and not hazard.cleared and hazard.distance - _runner.distance() < hazard_reveal_distance:
			active_pressure += 1
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
	for hazard in _hazards:
		if hazard.spawned and not hazard.cleared:
			active_hazards += 1
	var status: String = ""
	if not _run_active and not _game_over:
		status = "READY"
	if _stage_transition_timer > 0.0:
		status = "STAGE CLEAR"
	if _game_over:
		status = "CLEAR" if _game_complete else "GAME OVER"
	_hud.update_status(
		_stage,
		distance,
		speed,
		_score,
		lives,
		_rim_obstacles.size(),
		active_hazards,
		progress,
		status
	)
