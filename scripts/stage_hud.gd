class_name StageHud
extends CanvasLayer

signal start_pressed
signal exit_pressed
signal stage_selected(stage: int)

const NOTICE_TIME := 1.15
const PICKUP_BANNER_TIME := 1.3
const PICKUP_BANNER_FADE_TIME := 0.4

var selected_start_stage: int = 1

var _hud_label: Label
var _state_panel: Control
var _state_title: Label
var _state_body: Label
var _stage_selector_row: Control
var _stage_selector: OptionButton
var _state_primary_button: Button
var _state_secondary_button: Button
var _notice: String = ""
var _notice_timer: float = 0.0
var _pickup_banner: Label
var _pickup_banner_timer: float = 0.0

static func pickup_banner_alpha(timer: float) -> float:
	return clampf(timer / PICKUP_BANNER_FADE_TIME, 0.0, 1.0)

static func status_text(
	stage: int,
	distance: int,
	speed: int,
	score: int,
	lives: int,
	anchor_count: int,
	active_count: int,
	progress: int,
	status: String
) -> String:
	return (
		"STAGE %d  DIST %04d  SPD %02d  SCORE %04d  "
		+ "LIVES %d  ANCHOR %d  ACT %d  PROGRESS %d%%  %s"
	) % [stage, distance, speed, score, lives, anchor_count, active_count, progress, status]

static func stage_clear_body(
	score: int,
	stage_time: String,
	time_bonus: int,
	next_stage: int
) -> String:
	return (
		"Score %04d\nStage Time %s\nTime Bonus %04d\nNext: Stage %d"
	) % [score, stage_time, time_bonus, next_stage]

func setup(hud_label: Label) -> void:
	_hud_label = hud_label
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_state_overlay()
	_build_pickup_banner()

func tick_notice(delta: float) -> void:
	_notice_timer = maxf(_notice_timer - delta, 0.0)

func clear_notice() -> void:
	_notice = ""
	_notice_timer = 0.0

func show_notice(text: String) -> void:
	_notice = text
	_notice_timer = NOTICE_TIME

func tick_pickup_banner(delta: float) -> void:
	_pickup_banner_timer = maxf(_pickup_banner_timer - delta, 0.0)
	if _pickup_banner:
		var alpha: float = pickup_banner_alpha(_pickup_banner_timer)
		_pickup_banner.modulate.a = alpha
		_pickup_banner.visible = alpha > 0.0

func clear_pickup_banner() -> void:
	_pickup_banner_timer = 0.0
	if _pickup_banner:
		_pickup_banner.visible = false

func flash_pickup(text: String, color: Color) -> void:
	_pickup_banner_timer = PICKUP_BANNER_TIME
	if _pickup_banner:
		_pickup_banner.text = text
		_pickup_banner.add_theme_color_override("font_color", color)
		_pickup_banner.modulate.a = 1.0
		_pickup_banner.visible = true

func show_start_screen() -> void:
	_state_title.text = "MIRANDA"
	_state_body.text = "Choose starting stage"
	_stage_selector_row.visible = true
	_state_primary_button.text = "Start"
	_state_primary_button.visible = true
	_state_secondary_button.visible = true
	_sync_stage_selector()
	_state_panel.visible = true
	_state_primary_button.grab_focus()

func show_game_over_screen(score: int, stage: int) -> void:
	selected_start_stage = stage
	_state_title.text = "GAME OVER"
	_state_body.text = "Score %04d    Stage %d" % [score, stage]
	_stage_selector_row.visible = true
	_state_primary_button.text = "Restart"
	_state_primary_button.visible = true
	_state_secondary_button.visible = true
	_sync_stage_selector()
	_state_panel.visible = true
	_state_primary_button.grab_focus()

func show_complete_screen(score: int) -> void:
	selected_start_stage = 1
	_state_title.text = "STORM CLEAR"
	_state_body.text = "Score %04d" % score
	_stage_selector_row.visible = true
	_state_primary_button.text = "Restart"
	_state_primary_button.visible = true
	_state_secondary_button.visible = true
	_sync_stage_selector()
	_state_panel.visible = true
	_state_primary_button.grab_focus()

func show_stage_clear_screen(
	completed_stage: int,
	score: int,
	stage_time: String,
	time_bonus: int,
	next_stage: int
) -> void:
	_state_title.text = "STAGE %d CLEAR" % completed_stage
	_state_body.text = stage_clear_body(score, stage_time, time_bonus, next_stage)
	_stage_selector_row.visible = false
	_state_primary_button.visible = false
	_state_secondary_button.visible = false
	_state_panel.visible = true

func hide_state_overlay() -> void:
	if _state_panel:
		_state_panel.visible = false

func is_state_overlay_visible() -> bool:
	return _state_panel != null and _state_panel.visible

func should_accept_shortcut_start() -> bool:
	return should_accept_shortcut_start_for_focus(_current_focus_owner())

func should_accept_shortcut_start_for_focus(focus_owner: Control) -> bool:
	return not has_state_control_focus_owner(focus_owner)

func has_state_control_focus() -> bool:
	return has_state_control_focus_owner(_current_focus_owner())

func has_state_control_focus_owner(focus_owner: Control) -> bool:
	if _state_panel == null or not _state_panel.visible:
		return false
	return focus_owner != null and _state_panel.is_ancestor_of(focus_owner)

func _current_focus_owner() -> Control:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return null
	return viewport.gui_get_focus_owner()

func update_status(
	stage: int,
	distance: int,
	speed: int,
	score: int,
	lives: int,
	anchor_count: int,
	active_count: int,
	progress: int,
	base_status: String
) -> void:
	var status: String = base_status
	if _notice_timer > 0.0:
		status = _notice
	_hud_label.text = status_text(
		stage,
		distance,
		speed,
		score,
		lives,
		anchor_count,
		active_count,
		progress,
		status
	)

func _build_state_overlay() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.name = "StateDim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.52)
	add_child(dim)
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
	_stage_selector.name = "StageSelector"
	_stage_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage_selector.add_item("Stage 1", 1)
	_stage_selector.add_item("Stage 2", 2)
	_stage_selector.add_item("Stage 3", 3)
	_stage_selector.item_selected.connect(_on_stage_selected)
	selector_row.add_child(_stage_selector)

	_state_primary_button = Button.new()
	_state_primary_button.name = "PrimaryButton"
	_state_primary_button.custom_minimum_size = Vector2(0.0, 40.0)
	_state_primary_button.pressed.connect(func() -> void: start_pressed.emit())
	box.add_child(_state_primary_button)

	_state_secondary_button = Button.new()
	_state_secondary_button.name = "ExitButton"
	_state_secondary_button.custom_minimum_size = Vector2(0.0, 34.0)
	_state_secondary_button.text = "Exit"
	_state_secondary_button.pressed.connect(func() -> void: exit_pressed.emit())
	box.add_child(_state_secondary_button)

func _build_pickup_banner() -> void:
	var banner: Label = Label.new()
	banner.name = "PickupBanner"
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.offset_top = 64.0
	banner.offset_left = -220.0
	banner.offset_right = 220.0
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 30)
	banner.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	banner.add_theme_constant_override("outline_size", 6)
	banner.visible = false
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner)
	_pickup_banner = banner

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

func _on_stage_selected(index: int) -> void:
	selected_start_stage = _stage_selector.get_item_id(index)
	stage_selected.emit(selected_start_stage)

func _sync_stage_selector() -> void:
	if _stage_selector == null:
		return
	for index in range(_stage_selector.item_count):
		if _stage_selector.get_item_id(index) == selected_start_stage:
			_stage_selector.select(index)
			return
