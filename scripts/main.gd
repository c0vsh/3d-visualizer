extends Node3D

@export var camera: CameraController
@export var ui: UIManager
@export var file_loader: FileLoader
@export var scene_manager: SceneManager
@export var animation_controller: AnimationController

var current_time: float = 0.0
var max_time: float = 0.0
var is_playing: bool = false
var playback_speed: float = 1.0
var animated_packets: Dictionary = {}

func _ready():
	# Связываем сигналы
	file_loader.log_loaded.connect(_on_log_loaded)
	file_loader.load_error.connect(_on_load_error)
	ui.play_pressed.connect(_toggle_play)
	ui.time_changed.connect(_on_time_slider_changed)
	ui.speed_changed.connect(_on_speed_changed)
	ui.load_requested.connect(_on_load_requested)
	ui.show_labels_toggled.connect(scene_manager.set_show_labels)
	ui.simple_spheres_toggled.connect(_on_simple_spheres_toggled)

	ui.set_file_loader(file_loader)

	animation_controller.position_updated.connect(scene_manager.set_node_position)
	animation_controller.rotation_updated.connect(scene_manager.set_node_rotation)

	# Загружаем настройки
	ui.load_settings()
	scene_manager.show_node_labels = ui.show_node_labels
	scene_manager.use_simple_spheres = ui.use_simple_spheres
	
	ui._show_help_dialog()
	

func _process(delta):
	if not is_playing:
		return
	var new_time = current_time + delta * playback_speed
	if new_time > max_time:
		new_time = max_time
		is_playing = false
		ui.set_playing_state(false)
		ui._show_statistics_dialog()
	_set_current_time(new_time)

func _toggle_play():
	if file_loader.nodes_keyframes.is_empty():
		return
	if ui.overlay.visible:
		return
	is_playing = not is_playing
	ui.set_playing_state(is_playing)
	if is_playing:
		animated_packets.clear()

func _on_time_slider_changed(value: float):
	if not is_playing:
		_set_current_time(value)

func _set_current_time(new_time: float):
	current_time = clamp(new_time, 0.0, max_time)
	ui.set_current_time(current_time)
	animation_controller.update_all_nodes(current_time)
	scene_manager.update_packet_lines(current_time, file_loader.packet_intervals, is_playing, animated_packets, _animate_drone)
	scene_manager.update_auth_ok_labels(current_time, file_loader.auth_ok_intervals)
	scene_manager.update_auth_fail_labels(current_time, file_loader.auth_fail_intervals)

func _animate_drone(node_id: int):
	scene_manager.animate_drone(node_id)

func _on_speed_changed(value: float):
	playback_speed = value

func _on_load_requested():
	file_loader.load_log_file()

func _on_log_loaded(data: Dictionary):
	max_time = data.max_time
	ui.set_max_time(max_time)
	animation_controller.set_keyframes(data.nodes_keyframes)
	scene_manager.build_scene(data.nodes_keyframes)
	var center = _calculate_center(data.nodes_keyframes)
	if center.length() > 0.01:
		camera.set_center(center)
	ui.enable_stats_button(true)
	_set_current_time(0.0)
	is_playing = false
	ui.set_playing_state(false)

func _calculate_center(keyframes: Dictionary) -> Vector3:
	var sum = Vector3.ZERO
	var count = 0
	for frames in keyframes.values():
		if frames.size() > 0:
			sum += frames[0].pos
			count += 1
	return sum / count if count > 0 else Vector3.ZERO

func _on_simple_spheres_toggled(enabled: bool):
	scene_manager.use_simple_spheres = enabled
	if not file_loader.current_log_path.is_empty():
		file_loader.load_log_file(file_loader.current_log_path)

func _on_load_error(error: String):
	print(error)
