extends Node
class_name StormStage

const STAGE_MUSIC := {
	1: {
		"base_a": "res://audio/music/stage1_base_a.wav",
		"base_b": "res://audio/music/stage1_base_b.wav",
		"drums_high_a": "res://audio/music/stage1_drums_breakbeat_dnb.wav",
		"drums_high_b": "res://audio/music/stage1_drums_breakbeat_dnb.wav",
		"drums_low": "res://audio/music/stage1_drums_sparse.wav",
	},
	2: {
		"base_a": "res://audio/music/stage2_base_a.wav",
		"base_b": "res://audio/music/stage2_base_b.wav",
		"drums_high_a": "res://audio/music/stage2_drums_electro_a.wav",
		"drums_high_b": "res://audio/music/stage2_drums_electro_b.wav",
		"drums_low": "res://audio/music/stage2_drums_sparse.wav",
	},
}
const FIRE_SOUND := preload("res://audio/sfx/player_fire.wav")
const HIT_SOUND := preload("res://audio/sfx/player_hit.wav")
const KILL_SOUND := preload("res://audio/sfx/enemy_killed.wav")
const CLEAR_SOUND := preload("res://audio/sfx/stage_clear.wav")
const GAME_OVER_SOUND := preload("res://audio/sfx/game_over.wav")
const EXPLODER_SOUND := preload("res://audio/sfx/exploder_boom.wav")

@export var storm_path: NodePath
@export var runner_path: NodePath
@export var hud_label_path: NodePath
@export var hit_window: float = 4.2
@export var lives: int = 3
@export var bullet_speed: float = 140.0
@export var bullet_range: float = 220.0
@export var fire_cooldown: float = 0.18
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
var _hud_label: Label
var _hazards: Array[StageHazard] = []
var _bullets: Array[StageBullet] = []
var _enemy_bolts: Array[EnemyBolt] = []
var _active_markers: Dictionary = {}
var _rim_obstacles: Array[RimObstacle] = []
var _base_player: AudioStreamPlayer
var _drums_high_player: AudioStreamPlayer
var _drums_low_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _score: int = 0
var _stage: int = 1
var _game_over: bool = false
var _fire_timer: float = 0.0
var _base_passes: Array[AudioStream] = []
var _drums_high_passes: Array[AudioStream] = []
var _pass_index: int = 0
var _loaded_music_stage: int = 0
var _music_intensity: float = 0.0
var _damage_invulnerability_timer: float = 0.0

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

class StageBullet:
	var lane: int
	var distance: float
	var start_distance: float
	var marker: Node3D

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

func _ready() -> void:
	_storm = get_node(storm_path) as StormTube
	_runner = get_node(runner_path)
	_hud_label = get_node(hud_label_path) as Label
	_setup_audio()
	_build_stage_one()
	_update_hud()

func _exit_tree() -> void:
	if _base_player:
		_base_player.stop()
	if _drums_high_player:
		_drums_high_player.stop()
	if _drums_low_player:
		_drums_low_player.stop()
	if _sfx_player:
		_sfx_player.stop()
	_clear_markers()
	_clear_bullets()
	_clear_enemy_bolts()
	_clear_rim_obstacles()

func _process(delta: float) -> void:
	_update_music_intensity(delta)
	_damage_invulnerability_timer = maxf(_damage_invulnerability_timer - delta, 0.0)

	if Input.is_key_pressed(KEY_R):
		restart_stage()
		return

	if _game_over:
		return

	_fire_timer = maxf(_fire_timer - delta, 0.0)
	if Input.is_key_pressed(KEY_SPACE) and _fire_timer <= 0.0:
		_fire()
		_fire_timer = fire_cooldown

	var player_distance: float = _runner.distance()
	var player_lane: int = _runner.lane_index()

	_update_hazards(delta)
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
			_anchor_rim_obstacle(hazard)
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
	lives = 3
	_score = 0
	_stage = 1
	_game_over = false
	_fire_timer = 0.0
	_damage_invulnerability_timer = 0.0
	_runner.set_input_enabled(true)
	_runner.restart_run()
	_clear_markers()
	_clear_bullets()
	_clear_enemy_bolts()
	_clear_rim_obstacles()
	_build_stage_one()
	_storm.set_guide_overdraw_enabled(true)
	_load_music_stage(1)
	_update_hud()

func _build_stage_one() -> void:
	_hazards.clear()
	var pattern: Array = [
		[720.0, 4, "flipper"], [820.0, 12, "flipper"], [930.0, 6, "flipper"],
		[1080.0, 2, "spiker"], [1080.0, 10, "spiker"],
		[1260.0, 5, "tanker"], [1260.0, 6, "tanker"], [1260.0, 7, "tanker"],
		[1510.0, 14, "flipper"], [1600.0, 13, "flipper"], [1690.0, 12, "flipper"],
		[1900.0, 3, "spiker"], [1900.0, 11, "spiker"],
		[2140.0, 7, "pulsar"], [2250.0, 8, "pulsar"], [2360.0, 9, "pulsar"],
		[2600.0, 0, "exploder"], [2600.0, 8, "exploder"], [2860.0, 15, "flipper"]
	]
	for entry in pattern:
		var hazard: StageHazard = StageHazard.new()
		hazard.distance = entry[0]
		hazard.spawn_distance = maxf(hazard.distance - hazard_reveal_distance, 0.0)
		hazard.lane = wrapi(entry[1], 0, _storm.lane_count)
		hazard.kind = entry[2]
		_init_hazard_skill(hazard)
		_hazards.append(hazard)

func _build_stage_two() -> void:
	_hazards.clear()
	var pattern: Array = [
		[650.0, 1, "flipper"], [780.0, 5, "flipper"], [910.0, 9, "flipper"], [1040.0, 13, "flipper"],
		[1240.0, 3, "tanker"], [1240.0, 4, "tanker"], [1440.0, 11, "spiker"],
		[1660.0, 6, "pulsar"], [1810.0, 7, "pulsar"], [1960.0, 8, "pulsar"],
		[2220.0, 2, "exploder"], [2220.0, 10, "exploder"], [2520.0, 15, "flipper"],
		[2820.0, 0, "tanker"]
	]
	for entry in pattern:
		var hazard: StageHazard = StageHazard.new()
		hazard.distance = entry[0]
		hazard.spawn_distance = maxf(hazard.distance - hazard_reveal_distance, 0.0)
		hazard.lane = wrapi(entry[1], 0, _storm.lane_count)
		hazard.kind = entry[2]
		_init_hazard_skill(hazard)
		_hazards.append(hazard)

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

func _advance_stage() -> void:
	_play_sfx(CLEAR_SOUND)
	_damage_invulnerability_timer = 0.0
	_clear_markers()
	_clear_bullets()
	_clear_enemy_bolts()
	_burst_rim_obstacles()
	_clear_rim_obstacles()
	_stage += 1
	_runner.restart_run()
	for hazard in _hazards:
		hazard.cleared = true
	if _stage == 2:
		_storm.set_guide_overdraw_enabled(false)
		_load_music_stage(2)
		_build_stage_two()
		_update_hud()
		return
	_runner.set_input_enabled(false)
	_game_over = true
	_update_hud()

func _ensure_marker(hazard: StageHazard) -> void:
	if _active_markers.has(hazard):
		return
	var marker: Node3D = Node3D.new()
	var body: MeshInstance3D = MeshInstance3D.new()
	body.mesh = _mesh_for_kind(hazard.kind)
	body.material_override = _material_for_kind(hazard.kind)
	marker.add_child(body)
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

func _hit_player(hazard: StageHazard) -> void:
	hazard.hit = true
	hazard.cleared = true
	_remove_marker(hazard)
	_damage_player(EXPLODER_SOUND if hazard.kind == "exploder" else HIT_SOUND)

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

func _fire() -> void:
	var bullet: StageBullet = StageBullet.new()
	bullet.lane = _runner.lane_index()
	bullet.distance = _runner.distance() + 4.0
	bullet.start_distance = bullet.distance
	bullet.marker = _build_bullet_marker()
	_storm.add_child(bullet.marker)
	_bullets.append(bullet)
	_play_sfx(FIRE_SOUND, -7.0)

func _update_bullets(delta: float) -> void:
	for i in range(_bullets.size() - 1, -1, -1):
		var bullet: StageBullet = _bullets[i]
		var previous_distance: float = bullet.distance
		bullet.distance += bullet_speed * delta
		var hit_hazard: StageHazard = _find_bullet_hit(bullet, previous_distance)
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
		if hazard.distance < previous_distance or hazard.distance > bullet.distance + hit_window:
			continue
		if hazard.distance < best_distance:
			best = hazard
			best_distance = hazard.distance
	return best

func _destroy_hazard(hazard: StageHazard) -> void:
	hazard.cleared = true
	_score += 250
	_remove_marker(hazard)
	if hazard.kind == "tanker":
		_spawn_hazard(hazard.distance + 8.0, hazard.lane - 1, "flipper")
		_spawn_hazard(hazard.distance + 8.0, hazard.lane + 1, "flipper")
		_play_sfx(KILL_SOUND, -3.5)
		return
	_play_sfx(EXPLODER_SOUND if hazard.kind == "exploder" else KILL_SOUND, -4.0)

func _build_bullet_marker() -> Node3D:
	var marker: Node3D = Node3D.new()
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = 0.16
	mesh.height = 2.8
	mesh_instance.mesh = mesh
	mesh_instance.rotation_degrees.x = 90.0
	mesh_instance.material_override = _bullet_material()
	marker.add_child(mesh_instance)
	return marker

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
	bolt.marker = _build_enemy_bolt_marker()
	_storm.add_child(bolt.marker)
	_enemy_bolts.append(bolt)
	_update_enemy_bolt_pose(bolt)

func _update_enemy_bolts(delta: float, player_distance: float, player_lane: int) -> void:
	for i in range(_enemy_bolts.size() - 1, -1, -1):
		var bolt: EnemyBolt = _enemy_bolts[i]
		bolt.distance -= pulsar_bolt_speed * delta
		if bolt.distance <= player_distance + hit_window:
			if bolt.lane == player_lane:
				_damage_player(HIT_SOUND)
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

func _build_enemy_bolt_marker() -> Node3D:
	var marker: Node3D = Node3D.new()
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = 0.18
	mesh.height = 2.1
	mesh_instance.mesh = mesh
	mesh_instance.rotation_degrees.x = 90.0
	mesh_instance.material_override = _enemy_bolt_material()
	marker.add_child(mesh_instance)
	return marker

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

func _build_obstacle_marker(kind: String) -> Node3D:
	var marker: Node3D = Node3D.new()
	var body: MeshInstance3D = MeshInstance3D.new()
	body.mesh = _mesh_for_kind(kind)
	body.material_override = _material_for_kind(kind)
	body.scale = Vector3.ONE * 1.15
	marker.add_child(body)
	return marker

func _update_rim_obstacles(delta: float, player_lane: int) -> void:
	for i in range(_rim_obstacles.size() - 1, -1, -1):
		var obstacle: RimObstacle = _rim_obstacles[i]
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
					_damage_player(EXPLODER_SOUND)
					if _game_over:
						return
					continue
		_update_rim_obstacle_pose(obstacle, _lane_stack_index(obstacle))

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
		_damage_player(EXPLODER_SOUND if obstacle.kind == "exploder" else HIT_SOUND)
		return

func _damage_player(sound: AudioStream) -> void:
	if not _can_damage_player():
		return
	lives = maxi(lives - 1, 0)
	_damage_invulnerability_timer = damage_invulnerability_time
	if _runner.has_method("play_damage_feedback"):
		_runner.play_damage_feedback(damage_invulnerability_time)
	_play_sfx(sound, _damage_sound_volume(sound))
	if lives == 0:
		_trigger_game_over()

func _can_damage_player() -> bool:
	return not _game_over and _damage_invulnerability_timer <= 0.0

func _damage_sound_volume(sound: AudioStream) -> float:
	if sound == EXPLODER_SOUND:
		return -5.0
	return -7.0

func _trigger_game_over() -> void:
	if _game_over:
		return
	_game_over = true
	_runner.set_input_enabled(false)
	_clear_markers()
	_clear_bullets()
	_clear_enemy_bolts()
	_clear_rim_obstacles()
	_play_sfx(GAME_OVER_SOUND, -2.0)

func _burst_rim_obstacles() -> void:
	for obstacle in _rim_obstacles:
		_spawn_burst(obstacle.marker.global_position)
	if not _rim_obstacles.is_empty():
		_play_sfx(EXPLODER_SOUND, -5.0)

func _spawn_burst(position: Vector3) -> void:
	var burst: Node3D = Node3D.new()
	burst.global_position = position
	for i in 8:
		var shard: MeshInstance3D = MeshInstance3D.new()
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(0.08, 0.08, 0.9)
		shard.mesh = mesh
		var angle: float = TAU * float(i) / 8.0
		shard.position = Vector3(cos(angle), sin(angle), 0.0) * 0.65
		shard.rotation = Vector3(0.0, 0.0, angle)
		shard.material_override = _burst_material()
		burst.add_child(shard)
	_storm.add_child(burst)
	var tween: Tween = create_tween()
	tween.tween_property(burst, "scale", Vector3.ONE * 2.4, 0.24)
	tween.tween_callback(burst.queue_free)

func _clear_rim_obstacles() -> void:
	for obstacle in _rim_obstacles:
		obstacle.marker.queue_free()
	_rim_obstacles.clear()

func _mesh_for_kind(kind: String) -> Mesh:
	match kind:
		"tanker":
			var mesh: BoxMesh = BoxMesh.new()
			mesh.size = Vector3(2.6, 1.1, 1.4)
			return mesh
		"spiker":
			var mesh: PrismMesh = PrismMesh.new()
			mesh.size = Vector3(1.5, 1.2, 2.3)
			return mesh
		"pulsar":
			var mesh: SphereMesh = SphereMesh.new()
			mesh.radius = 0.78
			mesh.height = 1.55
			return mesh
		"exploder":
			var mesh: SphereMesh = SphereMesh.new()
			mesh.radius = 1.0
			mesh.height = 2.0
			return mesh
		"spike":
			var mesh: PrismMesh = PrismMesh.new()
			mesh.size = Vector3(0.9, 0.9, 1.5)
			return mesh
	var mesh: PrismMesh = PrismMesh.new()
	mesh.size = Vector3(1.1, 0.9, 2.0)
	return mesh

func _material_for_kind(kind: String) -> StandardMaterial3D:
	var color: Color = Color(1.0, 0.25, 0.25)
	var emission: Color = Color(1.0, 0.08, 0.08)
	match kind:
		"tanker":
			color = Color(1.0, 0.55, 0.08)
			emission = Color(1.0, 0.28, 0.02)
		"spiker":
			color = Color(0.95, 0.25, 0.95)
			emission = Color(0.9, 0.06, 1.0)
		"pulsar":
			color = Color(1.0, 0.95, 0.18)
			emission = Color(1.0, 0.78, 0.05)
		"exploder":
			color = Color(1.0, 0.92, 0.72)
			emission = Color(1.0, 0.16, 0.08)
		"spike":
			color = Color(0.75, 0.15, 0.95)
			emission = Color(0.9, 0.05, 1.0)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = 2.2
	return material

func _bullet_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.4, 1.0, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.0, 0.95, 1.0)
	material.emission_energy_multiplier = 3.2
	return material

func _enemy_bolt_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.86, 0.20)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.7, 0.05)
	material.emission_energy_multiplier = 3.4
	return material

func _burst_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.15, 1.0, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.0, 0.95, 1.0)
	material.emission_energy_multiplier = 3.8
	return material

func _setup_audio() -> void:
	_ensure_audio_bus("Music")
	_ensure_audio_bus("Sound")
	_base_player = _music_player_node("BasePlayer")
	_drums_high_player = _music_player_node("DrumsHighPlayer")
	_drums_low_player = _music_player_node("DrumsLowPlayer")
	_base_player.finished.connect(_on_music_pass_finished)
	_load_music_stage(1)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "Sound"
	add_child(_sfx_player)

func _music_player_node(node_name: String) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = node_name
	player.bus = "Music"
	add_child(player)
	return player

func _load_music_stage(stage: int) -> void:
	var resolved_stage: int = 2 if stage >= 2 else 1
	if _loaded_music_stage == resolved_stage:
		return
	_loaded_music_stage = resolved_stage
	var stems: Dictionary = STAGE_MUSIC[resolved_stage]
	_base_passes = [load(stems["base_a"]), load(stems["base_b"])]
	_drums_high_passes = [load(stems["drums_high_a"]), load(stems["drums_high_b"])]
	for stream in _base_passes:
		_set_loop(stream, AudioStreamWAV.LOOP_DISABLED)
	for stream in _drums_high_passes:
		_set_loop(stream, AudioStreamWAV.LOOP_DISABLED)
	var low_drums: AudioStream = load(stems["drums_low"])
	_set_loop(low_drums, AudioStreamWAV.LOOP_FORWARD)
	_drums_low_player.stream = low_drums
	_drums_low_player.volume_db = 0.0
	_drums_high_player.volume_db = -80.0
	_music_intensity = 0.0
	_pass_index = 0
	_play_current_music_pass()
	_drums_low_player.play()

func _set_loop(stream: AudioStream, mode: int) -> void:
	if stream is AudioStreamWAV:
		stream.loop_mode = mode

func _play_current_music_pass() -> void:
	_base_player.stream = _base_passes[_pass_index]
	_drums_high_player.stream = _drums_high_passes[_pass_index]
	_base_player.volume_db = -9.0
	_drums_high_player.play()
	_base_player.play()

func _on_music_pass_finished() -> void:
	_pass_index = (_pass_index + 1) % _base_passes.size()
	_play_current_music_pass()

func _update_music_intensity(delta: float) -> void:
	if _drums_high_player == null or _drums_low_player == null:
		return
	var active_pressure: int = _rim_obstacles.size()
	for hazard in _hazards:
		if hazard.spawned and not hazard.cleared and hazard.distance - _runner.distance() < hazard_reveal_distance:
			active_pressure += 1
	var target: float = 0.0
	if high_intensity_obstacles > low_intensity_obstacles:
		var span: float = float(high_intensity_obstacles - low_intensity_obstacles)
		target = clampf(float(active_pressure - low_intensity_obstacles) / span, 0.0, 1.0)
	_music_intensity = lerpf(_music_intensity, target, clampf(delta * music_crossfade_speed, 0.0, 1.0))
	_drums_high_player.volume_db = linear_to_db(clampf(_music_intensity, 0.001, 1.0))
	_drums_low_player.volume_db = linear_to_db(clampf(1.0 - _music_intensity, 0.001, 1.0))

func _play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	_sfx_player.stream = stream
	_sfx_player.volume_db = volume_db
	_sfx_player.play()

func _ensure_audio_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)

func _update_hud() -> void:
	var progress: int = int(clampf(_runner.distance() / _stage_end_distance(), 0.0, 1.0) * 100.0)
	var distance: int = int(_runner.distance())
	var speed: int = int(_runner.speed())
	var active_hazards: int = 0
	for hazard in _hazards:
		if hazard.spawned and not hazard.cleared:
			active_hazards += 1
	var status: String = ""
	if _game_over:
		status = "GAME OVER - R restart"
	_hud_label.text = "STAGE %d  DIST %04d  SPD %02d  SCORE %04d  LIVES %d  RIM %d  ACT %d  PROGRESS %d%%\nLeft/Right step lanes   Space fire   Up/Down speed   P pause   %s" % [_stage, distance, speed, _score, lives, _rim_obstacles.size(), active_hazards, progress, status]
