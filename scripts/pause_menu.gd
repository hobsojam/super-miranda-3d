extends CanvasLayer
class_name PauseMenu

@export var panel_path: NodePath
@export var music_slider_path: NodePath
@export var sound_slider_path: NodePath
@export var exit_button_path: NodePath

var _panel: Control
var _music_slider: HSlider
var _sound_slider: HSlider
var _exit_button: Button
var _paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = get_node(panel_path) as Control
	_music_slider = get_node(music_slider_path) as HSlider
	_sound_slider = get_node(sound_slider_path) as HSlider
	_exit_button = get_node(exit_button_path) as Button
	_panel.visible = false
	_ensure_audio_bus("Music")
	_ensure_audio_bus("Sound")
	_music_slider.value = 80.0
	_sound_slider.value = 80.0
	_music_slider.value_changed.connect(_on_music_changed)
	_sound_slider.value_changed.connect(_on_sound_changed)
	_exit_button.pressed.connect(_on_exit_pressed)
	_apply_bus_volume("Music", _music_slider.value)
	_apply_bus_volume("Sound", _sound_slider.value)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		_set_paused(not _paused)
		get_viewport().set_input_as_handled()

func _set_paused(paused: bool) -> void:
	_paused = paused
	get_tree().paused = paused
	_panel.visible = paused

func _on_music_changed(value: float) -> void:
	_apply_bus_volume("Music", value)

func _on_sound_changed(value: float) -> void:
	_apply_bus_volume("Sound", value)

func _on_exit_pressed() -> void:
	get_tree().quit()

func _ensure_audio_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)

func _apply_bus_volume(bus_name: String, value: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	var normalized: float = clampf(value / 100.0, 0.0, 1.0)
	AudioServer.set_bus_mute(index, normalized <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(normalized, 0.001)))
