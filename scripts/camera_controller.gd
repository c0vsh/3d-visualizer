extends Camera3D
class_name CameraController

@export var sensitivity := 0.01
@export var zoom_speed := 1.0
@export var min_distance := 5.0
@export var max_distance := 200.0
@export var initial_distance := 50.0

var target_center := Vector3.ZERO + Vector3(0,30,0)
var current_distance := initial_distance
var yaw := 0.0
var pitch := 0.0
var is_dragging := false

func _ready():
	current_distance = initial_distance
	update_camera_position()

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_dragging = event.pressed
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if is_dragging else Input.MOUSE_MODE_VISIBLE)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			current_distance -= zoom_speed
			current_distance = clamp(current_distance, min_distance, max_distance)
			update_camera_position()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			current_distance += zoom_speed
			current_distance = clamp(current_distance, min_distance, max_distance)
			update_camera_position()
	elif event is InputEventMouseMotion and is_dragging:
		yaw -= event.relative.x * sensitivity
		pitch -= event.relative.y * sensitivity
		pitch = clamp(pitch, -1.4, 1.4)
		update_camera_position()

func update_camera_position():
	var x = current_distance * cos(pitch) * sin(yaw)
	var z = current_distance * cos(pitch) * cos(yaw)
	var y = current_distance * sin(pitch)
	var cam_pos = target_center + Vector3(x, y, z)
	global_transform.origin = cam_pos
	look_at(target_center, Vector3.UP)

func set_center(new_center: Vector3):
	target_center = new_center
	update_camera_position()
