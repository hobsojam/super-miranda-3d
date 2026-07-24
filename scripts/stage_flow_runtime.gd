class_name StageFlowRuntime
extends RefCounted

var run_active: bool = false
var game_over: bool = false
var game_complete: bool = false
var stage: int = 1
var stage_elapsed_time: float = 0.0
var stage_transition_timer: float = 0.0
var pending_stage: int = 0
var last_stage_time_bonus: int = 0

func is_run_blocked() -> bool:
	return not run_active or game_over

func status_label() -> String:
	if game_over:
		return "CLEAR" if game_complete else "GAME OVER"
	if stage_transition_timer > 0.0:
		return "STAGE CLEAR"
	if not run_active:
		return "READY"
	return ""

func start_stage(stage_to_start: int) -> void:
	stage = clampi(stage_to_start, 1, 3)
	game_over = false
	game_complete = false
	run_active = true
	stage_elapsed_time = 0.0
	stage_transition_timer = 0.0
	pending_stage = 0
	last_stage_time_bonus = 0

func tick(delta: float) -> void:
	stage_elapsed_time += delta

func tick_transition(delta: float) -> bool:
	if stage_transition_timer <= 0.0:
		return false
	stage_transition_timer = maxf(stage_transition_timer - delta, 0.0)
	return stage_transition_timer <= 0.0

func begin_stage_clear_transition(next_stage: int, transition_time: float) -> void:
	last_stage_time_bonus = StageRules.stage_clear_time_bonus(stage_elapsed_time)
	pending_stage = next_stage
	stage_transition_timer = transition_time
	run_active = false

func complete_run() -> void:
	last_stage_time_bonus = StageRules.stage_clear_time_bonus(stage_elapsed_time)
	game_over = true
	game_complete = true
	run_active = false

func continue_to_pending() -> bool:
	if pending_stage <= 0:
		return false
	stage = pending_stage
	pending_stage = 0
	stage_elapsed_time = 0.0
	run_active = true
	return true

func trigger_game_over() -> bool:
	if game_over:
		return false
	game_over = true
	game_complete = false
	run_active = false
	return true
