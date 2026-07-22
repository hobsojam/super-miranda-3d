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
const HUD_NOTICE_TIME := 1.15
const STAGE_TRANSITION_TIME := 1.85
const STAGE_TARGET_TIME := 180.0
const STAGE_TIME_BONUS := 5000
const ANCHOR_DECAY_MIN_SPEED := 22.0
const ANCHOR_DECAY_MAX_SPEED := 55.0
const ANCHOR_DECAY_TIME_FAST := 3.5

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
var _pickups: Array[StagePickup] = []
var _bullets: Array[StageBullet] = []
var _enemy_bolts: Array[EnemyBolt] = []
var _active_markers: Dictionary = {}
var _pickup_markers: Dictionary = {}
var _rim_obstacles: Array[RimObstacle] = []
var _base_player: AudioStreamPlayer
var _drums_high_player: AudioStreamPlayer
var _drums_low_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _score: int = 0
var _stage: int = 1
var _game_over: bool = false
var _game_complete: bool = false
var _fire_timer: float = 0.0
var _base_passes: Array[AudioStream] = []
var _drums_high_passes: Array[AudioStream] = []
var _pass_index: int = 0
var _loaded_music_stage: int = 0
var _music_intensity: float = 0.0
var _damage_invulnerability_timer: float = 0.0
var _hud_notice: String = ""
var _hud_notice_timer: float = 0.0
var _stage_elapsed_time: float = 0.0
var _stage_transition_timer: float = 0.0
var _pending_stage: int = 0
var _last_stage_time_bonus: int = 0
var _run_active: bool = false
var _state_layer: CanvasLayer
var _state_panel: Control
var _state_title: Label
var _state_body: Label
var _stage_selector_row: Control
var _stage_selector: OptionButton
var _state_primary_button: Button
var _state_secondary_button: Button
var _selected_start_stage: int = 1

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
	_hud_label = get_node(hud_label_path) as Label
	_setup_audio()
	_setup_state_overlay()
	_build_stage_for(1)
	_runner.set_input_enabled(false)
	_show_start_screen()
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
	_clear_pickup_markers()
	_clear_bullets()
	_clear_enemy_bolts()
	_clear_rim_obstacles()

func _process(delta: float) -> void:
	_update_music_intensity(delta)
	_damage_invulnerability_timer = maxf(_damage_invulnerability_timer - delta, 0.0)
	_hud_notice_timer = maxf(_hud_notice_timer - delta, 0.0)

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
	_fire_timer = maxf(_fire_timer - delta, 0.0)
	if Input.is_key_pressed(KEY_SPACE) and _fire_timer <= 0.0:
		_fire()
		_fire_timer = fire_cooldown

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
	_start_stage(_selected_start_stage)

func _start_stage(stage: int) -> void:
	lives = 3
	_score = 0
	_stage = clampi(stage, 1, 2)
	_selected_start_stage = _stage
	_game_over = false
	_game_complete = false
	_run_active = true
	_fire_timer = 0.0
	_damage_invulnerability_timer = 0.0
	_hud_notice = ""
	_hud_notice_timer = 0.0
	_stage_elapsed_time = 0.0
	_stage_transition_timer = 0.0
	_pending_stage = 0
	_last_stage_time_bonus = 0
	_runner.set_input_enabled(true)
	_runner.restart_run()
	_clear_markers()
	_clear_pickup_markers()
	_clear_bullets()
	_clear_enemy_bolts()
	_clear_rim_obstacles()
	_build_stage_for(_stage)
	_storm.set_guide_overdraw_enabled(_stage == 1)
	_load_music_stage(_stage)
	_hide_state_overlay()
	_update_hud()

func _start_game() -> void:
	_start_stage(_selected_start_stage)

func _build_stage_for(stage: int) -> void:
	if stage == 2:
		_build_stage_two()
		return
	_build_stage_one()

func _build_stage_one() -> void:
	_hazards.clear()
	_pickups.clear()
	var pattern: Array = [
		[720.0, 4, "flipper"], [820.0, 12, "flipper"], [930.0, 6, "flipper"],
		[1080.0, 2, "spiker"], [1080.0, 10, "spiker"],
		[1260.0, 5, "splitter"], [1260.0, 6, "splitter"], [1260.0, 7, "splitter"],
		[1510.0, 14, "flipper"], [1600.0, 13, "flipper"], [1690.0, 12, "flipper"],
		[1900.0, 3, "spiker"], [1900.0, 11, "spiker"],
		[2140.0, 7, "pulsar"], [2250.0, 8, "pulsar"], [2360.0, 9, "pulsar"],
		[2600.0, 0, "exploder"], [2600.0, 8, "exploder"], [2860.0, 15, "flipper"],
		[3080.0, 4, "flipper"], [3180.0, 12, "flipper"],
		[3360.0, 6, "splitter"], [3540.0, 10, "pulsar"],
		[3640.0, 2, "exploder"]
	]
	for entry in pattern:
		_add_stage_hazard(entry[0], entry[1], entry[2])
	_add_pickup(1360.0, 6, "purge")
	_add_pickup(1450.0, 1, "life")

func _build_stage_two() -> void:
	_hazards.clear()
	_pickups.clear()
	var pattern: Array = [
		[650.0, 1, "flipper"], [780.0, 5, "flipper"], [910.0, 9, "flipper"], [1040.0, 13, "flipper"],
		[1240.0, 3, "splitter"], [1240.0, 4, "splitter"], [1440.0, 11, "spiker"],
		[1660.0, 6, "pulsar"], [1810.0, 7, "pulsar"], [1960.0, 8, "pulsar"],
		[2220.0, 2, "exploder"], [2220.0, 10, "exploder"], [2520.0, 15, "flipper"],
		[2820.0, 0, "splitter"]
	]
	for entry in pattern:
		_add_stage_hazard(entry[0], entry[1], entry[2])
	_add_gate_pair(3260.0, 0, 4, 1)
	_add_gate_pair(3260.0, 8, 12, 2)
	_add_gate_pair(3500.0, 2, 6, 3)
	_add_gate_pair(3500.0, 10, 14, 4)
	_add_gate_pair(3620.0, 5, 10, 5)
	_add_pickup(1340.0, 4, "purge")
	_add_pickup(2350.0, 4, "life")

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
	var count: int = _storm.lane_count
	var lane: int = wrapi(start_lane, 0, count)
	var end: int = wrapi(end_lane, 0, count)
	_add_stage_hazard(distance, lane, "gate_post", gate_id)
	while lane != end:
		lane = wrapi(lane + 1, 0, count)
		_add_stage_hazard(distance, lane, "gate_post" if lane == end else "gate_field", gate_id)

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

func _setup_state_overlay() -> void:
	_state_layer = CanvasLayer.new()
	_state_layer.layer = 20
	_state_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_state_layer)

	var dim: ColorRect = ColorRect.new()
	dim.name = "StateDim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.52)
	_state_layer.add_child(dim)
	_state_panel = dim

	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -210.0
	panel.offset_top = -130.0
	panel.offset_right = 210.0
	panel.offset_bottom = 130.0
	panel.add_theme_stylebox_override("panel", _state_panel_style())
	dim.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)

	_state_title = Label.new()
	_state_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_state_title.add_theme_color_override("font_color", Color(0.3, 1.0, 1.0))
	_state_title.add_theme_font_size_override("font_size", 34)
	box.add_child(_state_title)

	_state_body = Label.new()
	_state_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_state_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_state_body.add_theme_color_override("font_color", Color(0.78, 0.92, 1.0))
	_state_body.add_theme_font_size_override("font_size", 16)
	box.add_child(_state_body)

	var selector_row: HBoxContainer = HBoxContainer.new()
	_stage_selector_row = selector_row
	selector_row.add_theme_constant_override("separation", 12)
	box.add_child(selector_row)

	var selector_label: Label = Label.new()
	selector_label.custom_minimum_size = Vector2(86.0, 0.0)
	selector_label.add_theme_color_override("font_color", Color(0.78, 0.92, 1.0))
	selector_label.text = "Stage"
	selector_row.add_child(selector_label)

	_stage_selector = OptionButton.new()
	_stage_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage_selector.add_item("Stage 1", 1)
	_stage_selector.add_item("Stage 2", 2)
	_stage_selector.item_selected.connect(_on_stage_selected)
	selector_row.add_child(_stage_selector)

	_state_primary_button = Button.new()
	_state_primary_button.custom_minimum_size = Vector2(0.0, 40.0)
	_state_primary_button.pressed.connect(_start_game)
	box.add_child(_state_primary_button)

	_state_secondary_button = Button.new()
	_state_secondary_button.custom_minimum_size = Vector2(0.0, 34.0)
	_state_secondary_button.text = "Exit"
	_state_secondary_button.pressed.connect(_on_state_exit_pressed)
	box.add_child(_state_secondary_button)

func _state_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.006, 0.014, 0.05, 0.92)
	style.border_color = Color(0.0, 0.9, 1.0, 0.85)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style

func _show_start_screen() -> void:
	_run_active = false
	_state_title.text = "MIRANDA"
	_state_body.text = "Choose starting stage"
	_stage_selector_row.visible = true
	_state_primary_button.text = "Start"
	_state_primary_button.visible = true
	_state_secondary_button.visible = true
	_sync_stage_selector()
	_state_panel.visible = true
	_state_primary_button.grab_focus()

func _show_game_over_screen() -> void:
	_selected_start_stage = _stage
	_state_title.text = "GAME OVER"
	_state_body.text = "Score %04d    Stage %d" % [_score, _stage]
	_stage_selector_row.visible = true
	_state_primary_button.text = "Restart"
	_state_primary_button.visible = true
	_state_secondary_button.visible = true
	_sync_stage_selector()
	_state_panel.visible = true
	_state_primary_button.grab_focus()

func _show_complete_screen() -> void:
	_selected_start_stage = 1
	_state_title.text = "STORM CLEAR"
	_state_body.text = "Score %04d" % _score
	_stage_selector_row.visible = true
	_state_primary_button.text = "Restart"
	_state_primary_button.visible = true
	_state_secondary_button.visible = true
	_sync_stage_selector()
	_state_panel.visible = true
	_state_primary_button.grab_focus()

func _show_stage_clear_screen(completed_stage: int, next_stage: int) -> void:
	_state_title.text = "STAGE %d CLEAR" % completed_stage
	_state_body.text = "Score %04d\nStage Time %s\nTime Bonus %04d\nNext: Stage %d" % [_score, _format_stage_time(_stage_elapsed_time), _last_stage_time_bonus, next_stage]
	_stage_selector_row.visible = false
	_state_primary_button.visible = false
	_state_secondary_button.visible = false
	_state_panel.visible = true

func _hide_state_overlay() -> void:
	if _state_panel:
		_state_panel.visible = false

func _on_state_exit_pressed() -> void:
	get_tree().quit()

func _on_stage_selected(index: int) -> void:
	_selected_start_stage = _stage_selector.get_item_id(index)
	if not _run_active:
		_stage = _selected_start_stage
		_storm.set_guide_overdraw_enabled(_stage == 1)
		_load_music_stage(_stage)
		_build_stage_for(_stage)
		_update_hud()

func _sync_stage_selector() -> void:
	if _stage_selector == null:
		return
	for index in range(_stage_selector.item_count):
		if _stage_selector.get_item_id(index) == _selected_start_stage:
			_stage_selector.select(index)
			return

func _advance_stage() -> void:
	_play_sfx(CLEAR_SOUND)
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
		_show_stage_clear_screen(completed_stage, next_stage)
		_update_hud()
		return
	_runner.set_input_enabled(false)
	_game_over = true
	_game_complete = true
	_run_active = false
	_show_complete_screen()
	_update_hud()

func _continue_to_pending_stage() -> void:
	if _pending_stage <= 0:
		return
	_stage = _pending_stage
	_pending_stage = 0
	_stage_elapsed_time = 0.0
	_fire_timer = 0.0
	_damage_invulnerability_timer = 0.0
	_hud_notice = ""
	_hud_notice_timer = 0.0
	_runner.restart_run()
	_runner.set_input_enabled(true)
	_run_active = true
	_storm.set_guide_overdraw_enabled(_stage == 1)
	_load_music_stage(_stage)
	_build_stage_for(_stage)
	_hide_state_overlay()

func _format_stage_time(seconds: float) -> String:
	var total_tenths: int = int(roundf(seconds * 10.0))
	var minutes: int = int(float(total_tenths) / 600.0)
	var seconds_part: int = int(float(total_tenths - minutes * 600) / 10.0)
	var tenths: int = total_tenths % 10
	return "%02d:%02d.%d" % [minutes, seconds_part, tenths]

func _stage_clear_time_bonus(seconds: float) -> int:
	var ratio: float = clampf((STAGE_TARGET_TIME - seconds) / STAGE_TARGET_TIME, 0.0, 1.0)
	return int(roundf(ratio * float(STAGE_TIME_BONUS) / 50.0)) * 50

func _ensure_marker(hazard: StageHazard) -> void:
	if _active_markers.has(hazard):
		return
	var marker: Node3D = _build_enemy_marker(hazard.kind)
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
	_animate_enemy_art(marker, hazard.kind)

func _hit_player(hazard: StageHazard) -> void:
	if hazard.kind == "gate_field":
		_damage_player(HIT_SOUND)
		return
	if hazard.kind == "gate_post":
		hazard.hit = true
		_damage_player(HIT_SOUND)
		_destroy_gate(hazard.gate_id, false)
		return
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

func _ensure_pickup_marker(pickup: StagePickup) -> void:
	if _pickup_markers.has(pickup):
		return
	var marker: Node3D = _build_pickup_marker(pickup.kind)
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
	_animate_pickup_art(marker, pickup.kind)

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
			_show_hud_notice("EXTRA LIFE")
			_play_sfx(CLEAR_SOUND, -8.0)
		"purge":
			_score += 750
			_purge_rim_obstacles()
			_show_hud_notice("CLEARANCE PULSE")
			_play_sfx(EXPLODER_SOUND, -8.0)

func _destroy_pickup(pickup: StagePickup) -> void:
	pickup.cleared = true
	_remove_pickup_marker(pickup)
	_play_sfx(KILL_SOUND, -12.0)

func _purge_rim_obstacles() -> void:
	for obstacle in _rim_obstacles:
		_spawn_burst(obstacle.marker.global_position)
		obstacle.marker.queue_free()
	_rim_obstacles.clear()

func _show_hud_notice(text: String) -> void:
	_hud_notice = text
	_hud_notice_timer = HUD_NOTICE_TIME

func _spawn_pickup_collect_effect(position: Vector3, kind: String) -> void:
	var effect: Node3D = Node3D.new()
	effect.global_position = position
	var material: StandardMaterial3D = _pickup_accent_material(kind)
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
	bullet.marker = _build_bullet_marker()
	_storm.add_child(bullet.marker)
	_bullets.append(bullet)
	_play_sfx(FIRE_SOUND, -7.0)

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
		_play_sfx(KILL_SOUND, -3.5)
		return
	_play_sfx(EXPLODER_SOUND if hazard.kind == "exploder" else KILL_SOUND, -4.0)

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
			_play_sfx(KILL_SOUND, -3.5)

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

func _should_anchor_hazard(hazard: StageHazard) -> bool:
	return hazard.kind != "gate_field" and hazard.kind != "gate_post"

func _build_obstacle_marker(kind: String) -> Node3D:
	var marker: Node3D = _build_enemy_marker(kind)
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
					_damage_player(EXPLODER_SOUND)
					if _game_over:
						return
					continue
		_update_rim_obstacle_pose(obstacle, _lane_stack_index(obstacle))

func _decay_anchor_obstacle(obstacle: RimObstacle, delta: float) -> bool:
	var speed_factor: float = clampf((_runner.speed() - ANCHOR_DECAY_MIN_SPEED) / (ANCHOR_DECAY_MAX_SPEED - ANCHOR_DECAY_MIN_SPEED), 0.0, 1.0)
	if speed_factor <= 0.0:
		return false
	obstacle.stability -= delta * speed_factor / ANCHOR_DECAY_TIME_FAST
	var pulse_scale: float = 1.0 + (1.0 - obstacle.stability) * 0.18
	obstacle.marker.scale = Vector3.ONE * 1.15 * pulse_scale
	if obstacle.stability > 0.0:
		return false
	_spawn_burst(obstacle.marker.global_position)
	obstacle.marker.queue_free()
	_play_sfx(KILL_SOUND, -8.0)
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
	_animate_enemy_art(obstacle.marker, obstacle.kind)

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
	_game_complete = false
	_run_active = false
	_runner.set_input_enabled(false)
	_clear_markers()
	_clear_pickup_markers()
	_clear_bullets()
	_clear_enemy_bolts()
	_clear_rim_obstacles()
	_play_sfx(GAME_OVER_SOUND, -2.0)
	_show_game_over_screen()

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

func _build_enemy_marker(kind: String) -> Node3D:
	var marker: Node3D = Node3D.new()
	marker.set_meta("kind", kind)
	var material: StandardMaterial3D = _material_for_kind(kind)
	var accent: StandardMaterial3D = _accent_material_for_kind(kind)
	match kind:
		"splitter":
			_add_sphere_part(marker, 0.62, Vector3.ZERO, material)
			_add_prism_part(marker, Vector3(0.72, 0.48, 1.35), Vector3(-0.82, 0.0, 0.12), Vector3(0.0, 0.0, 0.65), accent)
			_add_prism_part(marker, Vector3(0.72, 0.48, 1.35), Vector3(0.82, 0.0, 0.12), Vector3(0.0, 0.0, -0.65), accent)
			_add_box_part(marker, Vector3(2.05, 0.12, 0.18), Vector3(0.0, 0.0, -0.2), Vector3.ZERO, accent)
			_add_sphere_part(marker, 0.24, Vector3(-0.58, 0.36, -0.42), accent)
			_add_sphere_part(marker, 0.24, Vector3(0.58, -0.36, -0.42), accent)
		"spiker":
			_add_prism_part(marker, Vector3(0.62, 0.62, 2.75), Vector3.ZERO, Vector3.ZERO, material)
			_add_box_part(marker, Vector3(1.65, 0.08, 0.18), Vector3(0.0, 0.0, -0.35), Vector3(0.0, 0.0, 0.35), accent)
			_add_box_part(marker, Vector3(1.15, 0.08, 0.16), Vector3(0.0, 0.0, 0.45), Vector3(0.0, 0.0, -0.45), accent)
			_add_prism_part(marker, Vector3(0.28, 0.28, 0.9), Vector3(-0.48, 0.16, 0.82), Vector3(0.0, 0.0, 0.35), accent)
			_add_prism_part(marker, Vector3(0.28, 0.28, 0.9), Vector3(0.48, -0.16, 0.82), Vector3(0.0, 0.0, -0.35), accent)
		"pulsar":
			var spin: Node3D = Node3D.new()
			spin.name = "Spin"
			marker.add_child(spin)
			_add_sphere_part(spin, 0.58, Vector3.ZERO, material)
			_add_box_part(spin, Vector3(2.05, 0.08, 0.08), Vector3.ZERO, Vector3.ZERO, accent)
			_add_box_part(spin, Vector3(0.08, 2.05, 0.08), Vector3.ZERO, Vector3.ZERO, accent)
			_add_box_part(spin, Vector3(0.08, 0.08, 1.45), Vector3.ZERO, Vector3.ZERO, accent)
		"exploder":
			var pulse: Node3D = Node3D.new()
			pulse.name = "Pulse"
			marker.add_child(pulse)
			_add_sphere_part(pulse, 0.74, Vector3.ZERO, material)
			_add_box_part(pulse, Vector3(2.0, 0.07, 0.07), Vector3.ZERO, Vector3(0.0, 0.0, 0.55), accent)
			_add_box_part(pulse, Vector3(0.07, 2.0, 0.07), Vector3.ZERO, Vector3(0.0, 0.0, -0.55), accent)
			_add_box_part(pulse, Vector3(0.07, 0.07, 2.0), Vector3.ZERO, Vector3(0.55, 0.0, 0.0), accent)
		"gate_post":
			var pulse: Node3D = Node3D.new()
			pulse.name = "Pulse"
			marker.add_child(pulse)
			_add_box_part(pulse, Vector3(0.22, 1.85, 0.22), Vector3.ZERO, Vector3.ZERO, material)
			_add_box_part(pulse, Vector3(0.54, 0.16, 0.34), Vector3(0.0, 0.84, 0.0), Vector3.ZERO, accent)
			_add_box_part(pulse, Vector3(0.54, 0.16, 0.34), Vector3(0.0, -0.84, 0.0), Vector3.ZERO, accent)
			_add_box_part(pulse, Vector3(0.08, 1.55, 0.42), Vector3(-0.22, 0.0, 0.0), Vector3.ZERO, accent)
			_add_box_part(pulse, Vector3(0.08, 1.55, 0.42), Vector3(0.22, 0.0, 0.0), Vector3.ZERO, accent)
			_add_sphere_part(pulse, 0.24, Vector3.ZERO, accent)
		"gate_field":
			var pulse: Node3D = Node3D.new()
			pulse.name = "Pulse"
			marker.add_child(pulse)
			_add_box_part(pulse, Vector3(1.72, 0.12, 0.12), Vector3(0.0, 0.0, 0.0), Vector3.ZERO, material)
			_add_box_part(pulse, Vector3(1.34, 0.06, 0.08), Vector3(0.0, 0.18, 0.0), Vector3.ZERO, accent)
			_add_box_part(pulse, Vector3(1.34, 0.06, 0.08), Vector3(0.0, -0.18, 0.0), Vector3.ZERO, accent)
		"spike":
			_add_prism_part(marker, Vector3(0.42, 0.42, 1.45), Vector3.ZERO, Vector3.ZERO, material)
			_add_prism_part(marker, Vector3(0.32, 0.32, 1.05), Vector3(-0.36, 0.0, 0.12), Vector3(0.0, 0.85, 0.0), accent)
			_add_prism_part(marker, Vector3(0.32, 0.32, 1.05), Vector3(0.36, 0.0, 0.12), Vector3(0.0, -0.85, 0.0), accent)
		_:
			_add_prism_part(marker, Vector3(0.82, 0.52, 2.05), Vector3.ZERO, Vector3.ZERO, material)
			_add_box_part(marker, Vector3(1.45, 0.08, 0.34), Vector3(0.0, 0.0, 0.35), Vector3(0.0, 0.0, -0.45), accent)
			_add_box_part(marker, Vector3(0.78, 0.08, 0.28), Vector3(-0.48, 0.0, -0.32), Vector3(0.0, 0.0, 0.62), accent)
			_add_box_part(marker, Vector3(0.78, 0.08, 0.28), Vector3(0.48, 0.0, -0.32), Vector3(0.0, 0.0, -0.62), accent)
	return marker

func _build_pickup_marker(kind: String) -> Node3D:
	var marker: Node3D = Node3D.new()
	var material: StandardMaterial3D = _pickup_material(kind)
	var accent: StandardMaterial3D = _pickup_accent_material(kind)
	match kind:
		"purge":
			var spin: Node3D = Node3D.new()
			spin.name = "Spin"
			marker.add_child(spin)
			_add_sphere_part(spin, 0.4, Vector3.ZERO, material)
			_add_box_part(spin, Vector3(1.55, 0.12, 0.08), Vector3(0.0, 0.44, 0.0), Vector3(0.0, 0.0, 0.18), accent)
			_add_box_part(spin, Vector3(1.55, 0.12, 0.08), Vector3(0.0, -0.44, 0.0), Vector3(0.0, 0.0, -0.18), accent)
			_add_box_part(spin, Vector3(0.16, 1.28, 0.08), Vector3(-0.52, 0.0, 0.0), Vector3(0.0, 0.0, -0.22), accent)
			_add_box_part(spin, Vector3(0.16, 1.28, 0.08), Vector3(0.52, 0.0, 0.0), Vector3(0.0, 0.0, 0.22), accent)
			_add_sphere_part(spin, 0.13, Vector3(-0.78, 0.42, 0.0), accent)
			_add_sphere_part(spin, 0.13, Vector3(0.78, -0.42, 0.0), accent)
		_:
			var spin: Node3D = Node3D.new()
			spin.name = "Spin"
			marker.add_child(spin)
			_add_sphere_part(spin, 0.36, Vector3.ZERO, material)
			_add_box_part(spin, Vector3(1.32, 0.2, 0.2), Vector3.ZERO, Vector3.ZERO, accent)
			_add_box_part(spin, Vector3(0.2, 1.32, 0.2), Vector3.ZERO, Vector3.ZERO, accent)
	return marker

func _add_box_part(parent: Node3D, size: Vector3, position: Vector3, rotation: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var part: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = position
	part.rotation = rotation
	part.material_override = material
	parent.add_child(part)
	return part

func _add_prism_part(parent: Node3D, size: Vector3, position: Vector3, rotation: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var part: MeshInstance3D = MeshInstance3D.new()
	var mesh: PrismMesh = PrismMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = position
	part.rotation = rotation
	part.material_override = material
	parent.add_child(part)
	return part

func _add_sphere_part(parent: Node3D, radius: float, position: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var part: MeshInstance3D = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	part.mesh = mesh
	part.position = position
	part.material_override = material
	parent.add_child(part)
	return part

func _animate_enemy_art(marker: Node3D, kind: String) -> void:
	var time: float = float(Time.get_ticks_msec()) * 0.001
	match kind:
		"pulsar":
			var spin: Node3D = marker.get_node_or_null("Spin") as Node3D
			if spin:
				spin.rotation = Vector3(time * 2.1, time * 1.2, time * 2.8)
		"exploder":
			var pulse: Node3D = marker.get_node_or_null("Pulse") as Node3D
			if pulse:
				var scale_amount: float = 1.0 + 0.13 * sin(time * 11.0)
				pulse.scale = Vector3.ONE * scale_amount
				pulse.rotation = Vector3(time * 1.4, time * 0.9, time * 1.8)
		"gate_post", "gate_field":
			var pulse: Node3D = marker.get_node_or_null("Pulse") as Node3D
			if pulse:
				var scale_y: float = 1.0 + 0.08 * sin(time * 8.0)
				pulse.scale = Vector3(1.0, scale_y if kind == "gate_post" else 1.0, 1.0)

func _animate_pickup_art(marker: Node3D, kind: String) -> void:
	var time: float = float(Time.get_ticks_msec()) * 0.001
	marker.scale = Vector3.ONE * (1.0 + 0.08 * sin(time * 6.5))
	match kind:
		"purge":
			var spin: Node3D = marker.get_node_or_null("Spin") as Node3D
			if spin:
				spin.rotation = Vector3(0.0, 0.0, time * 1.8)
		_:
			var spin: Node3D = marker.get_node_or_null("Spin") as Node3D
			if spin:
				spin.rotation.z = time * 1.6

func _material_for_kind(kind: String) -> StandardMaterial3D:
	var color: Color = Color(1.0, 0.25, 0.25)
	var emission: Color = Color(1.0, 0.08, 0.08)
	match kind:
		"splitter":
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
		"gate_post":
			color = Color(0.10, 0.58, 0.74)
			emission = Color(0.0, 0.82, 1.0)
		"gate_field":
			color = Color(0.02, 0.32, 0.44)
			emission = Color(0.0, 0.58, 0.78)
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

func _accent_material_for_kind(kind: String) -> StandardMaterial3D:
	var color: Color = Color(1.0, 0.55, 1.0)
	var emission: Color = Color(1.0, 0.15, 1.0)
	match kind:
		"splitter":
			color = Color(1.0, 0.86, 0.18)
			emission = Color(1.0, 0.62, 0.04)
		"spiker", "spike":
			color = Color(1.0, 0.18, 1.0)
			emission = Color(0.95, 0.0, 1.0)
		"pulsar":
			color = Color(1.0, 1.0, 0.58)
			emission = Color(1.0, 0.96, 0.12)
		"exploder":
			color = Color(1.0, 0.32, 0.18)
			emission = Color(1.0, 0.08, 0.0)
		"gate_post":
			color = Color(0.64, 1.0, 1.0)
			emission = Color(0.05, 1.0, 1.0)
		"gate_field":
			color = Color(0.22, 0.95, 1.0)
			emission = Color(0.0, 0.84, 1.0)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = 3.1
	return material

func _pickup_material(kind: String) -> StandardMaterial3D:
	var color: Color = Color(0.55, 1.0, 0.42)
	var emission: Color = Color(0.2, 1.0, 0.16)
	if kind == "purge":
		color = Color(0.3, 0.95, 1.0)
		emission = Color(0.0, 0.82, 1.0)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = 3.6
	return material

func _pickup_accent_material(kind: String) -> StandardMaterial3D:
	var color: Color = Color(0.92, 1.0, 0.72)
	var emission: Color = Color(0.74, 1.0, 0.28)
	if kind == "purge":
		color = Color(0.72, 1.0, 1.0)
		emission = Color(0.15, 1.0, 1.0)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = 4.2
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
	if not _run_active and not _game_over:
		status = "READY"
	if _stage_transition_timer > 0.0:
		status = "STAGE CLEAR"
	if _game_over:
		status = "CLEAR" if _game_complete else "GAME OVER"
	if _hud_notice_timer > 0.0:
		status = _hud_notice
	_hud_label.text = "STAGE %d  DIST %04d  SPD %02d  SCORE %04d  LIVES %d  ANCHOR %d  ACT %d  PROGRESS %d%%  %s" % [_stage, distance, speed, _score, lives, _rim_obstacles.size(), active_hazards, progress, status]
