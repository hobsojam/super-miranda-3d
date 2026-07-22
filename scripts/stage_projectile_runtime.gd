class_name StageProjectileRuntime
extends RefCounted

const BULLET_MUZZLE_OFFSET := 4.0
const ENEMY_BOLT_BEHIND_MARGIN := 40.0

class Bullet:
	var lane: int
	var distance: float
	var start_distance: float
	var marker: Node3D

class EnemyBolt:
	var lane: int
	var distance: float
	var marker: Node3D

var _bullet_speed: float = 140.0
var _bullet_range: float = 220.0
var _enemy_bolt_speed: float = 95.0
var _hit_window: float = 4.2
var _bullets: Array[Bullet] = []
var _enemy_bolts: Array[EnemyBolt] = []

func setup(
	bullet_speed: float,
	bullet_range: float,
	enemy_bolt_speed: float,
	hit_window: float
) -> void:
	_bullet_speed = bullet_speed
	_bullet_range = bullet_range
	_enemy_bolt_speed = enemy_bolt_speed
	_hit_window = hit_window

func bullets() -> Array[Bullet]:
	return _bullets

func enemy_bolts() -> Array[EnemyBolt]:
	return _enemy_bolts

func bullet_count() -> int:
	return _bullets.size()

func enemy_bolt_count() -> int:
	return _enemy_bolts.size()

func fire_bullet(lane: int, player_distance: float, marker: Node3D) -> Bullet:
	var bullet: Bullet = Bullet.new()
	bullet.lane = lane
	bullet.distance = player_distance + BULLET_MUZZLE_OFFSET
	bullet.start_distance = bullet.distance
	bullet.marker = marker
	_bullets.append(bullet)
	return bullet

func fire_enemy_bolt(lane: int, distance: float, marker: Node3D) -> EnemyBolt:
	var bolt: EnemyBolt = EnemyBolt.new()
	bolt.lane = lane
	bolt.distance = distance
	bolt.marker = marker
	_enemy_bolts.append(bolt)
	return bolt

func advance_bullet(bullet: Bullet, delta: float) -> float:
	var previous_distance: float = bullet.distance
	bullet.distance += _bullet_speed * delta
	return previous_distance

func advance_enemy_bolt(bolt: EnemyBolt, delta: float) -> float:
	var previous_distance: float = bolt.distance
	bolt.distance -= _enemy_bolt_speed * delta
	return previous_distance

func bullet_expired(bullet: Bullet, route_length: float) -> bool:
	return bullet.distance > minf(bullet.start_distance + _bullet_range, route_length)

func enemy_bolt_reached_player(bolt: EnemyBolt, player_distance: float) -> bool:
	return bolt.distance <= player_distance + _hit_window

func enemy_bolt_expired_behind(bolt: EnemyBolt, player_distance: float) -> bool:
	return bolt.distance < player_distance - ENEMY_BOLT_BEHIND_MARGIN

func remove_bullet(bullet: Bullet) -> void:
	_bullets.erase(bullet)

func remove_enemy_bolt(bolt: EnemyBolt) -> void:
	_enemy_bolts.erase(bolt)

func clear_bullets() -> void:
	_bullets.clear()

func clear_enemy_bolts() -> void:
	_enemy_bolts.clear()

func find_bullet_hazard_hit(
	bullet: Bullet,
	previous_distance: float,
	hazards: Array[StageHazardRuntime.Hazard]
) -> StageHazardRuntime.Hazard:
	var best: StageHazardRuntime.Hazard = null
	var best_distance: float = INF
	for hazard in hazards:
		if not hazard.spawned or hazard.cleared or hazard.lane != bullet.lane:
			continue
		if hazard.kind == "gate_field":
			continue
		if hazard.distance < previous_distance or hazard.distance > bullet.distance + _hit_window:
			continue
		if hazard.distance < best_distance:
			best = hazard
			best_distance = hazard.distance
	return best

func find_bullet_pickup_hit(
	bullet: Bullet,
	previous_distance: float,
	pickups: Array[StagePickupRuntime.Pickup]
) -> StagePickupRuntime.Pickup:
	var best: StagePickupRuntime.Pickup = null
	var best_distance: float = INF
	for pickup in pickups:
		if not pickup.spawned or pickup.cleared or pickup.lane != bullet.lane:
			continue
		if pickup.distance < previous_distance or pickup.distance > bullet.distance + _hit_window:
			continue
		if pickup.distance < best_distance:
			best = pickup
			best_distance = pickup.distance
	return best
