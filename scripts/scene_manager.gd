extends Node3D
class_name SceneManager

@export var drones_container: Node3D
@export var drone_model_path: String = "res://models/drone.glb"
@export var model_offset: Vector3 = Vector3(-3.5, 0, 3.5)

var drone_scene: PackedScene
var nodes_data: Dictionary = {}  # node_id -> {mesh, label, meshes, default_materials}
var active_lines: Array = []
var active_auth_labels: Array = []
var active_auth_ok_labels: Array = []

var white_material: StandardMaterial3D

var use_simple_spheres: bool = false
var show_node_labels: bool = true

const PACKET_VISUAL_DURATION = 0.2
const AUTH_VISUAL_DURATION = 0.5

func _ready():
	drone_scene = load(drone_model_path)
	if not drone_scene:
		print("Warning: drone model not found, using spheres")
	white_material = StandardMaterial3D.new()
	white_material.albedo_color = Color.WHITE
	white_material.emission_enabled = true
	white_material.emission = Color.WHITE
	white_material.emission_energy_multiplier = 2.0

func build_scene(keyframes: Dictionary):
	_clear_scene()
	for node_id in keyframes:
		nodes_data[node_id] = {}
	_create_drone_meshes()

func _clear_scene():
	for child in drones_container.get_children():
		child.queue_free()
	nodes_data.clear()
	_clear_active_lines()
	_clear_auth_labels(active_auth_labels)
	_clear_auth_labels(active_auth_ok_labels)

func _create_drone_meshes():
	var use_model = (drone_scene != null) and not use_simple_spheres
	var total = nodes_data.size()
	for node_id in nodes_data:
		var root = Node3D.new()
		var meshes: Array[MeshInstance3D] = []
		var default_mats: Array = []
		if use_model:
			var model = drone_scene.instantiate()
			model.position = model_offset
			model.scale = Vector3(0.1, 0.1, 0.1)
			root.add_child(model)
			_collect_meshes_and_materials(model, meshes, default_mats)
			var color = Color.from_hsv(float(node_id) / total, 0.8, 0.8)
			for mesh in meshes:
				var colored_mat = StandardMaterial3D.new()
				colored_mat.albedo_color = color
				mesh.material_override = colored_mat
				default_mats[meshes.find(mesh)] = colored_mat
		else:
			var sphere = MeshInstance3D.new()
			sphere.mesh = SphereMesh.new()
			sphere.mesh.radius = 0.8
			sphere.mesh.height = 1.6
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.2, 0.6, 1.0)
			sphere.material_override = mat
			root.add_child(sphere)
			meshes = [sphere]
			default_mats = [mat]
		var label = Label3D.new()
		label.text = str(node_id)
		label.pixel_size = 0.07
		label.billboard = true
		label.position = Vector3(0, 1.2 + model_offset.y, 0)
		label.visible = show_node_labels
		label.no_depth_test = true
		root.add_child(label)
		drones_container.add_child(root)
		nodes_data[node_id].mesh = root
		nodes_data[node_id].label = label
		nodes_data[node_id].meshes = meshes
		nodes_data[node_id].default_materials = default_mats

func _collect_meshes_and_materials(node: Node, meshes: Array, materials: Array):
	for child in node.get_children():
		if child is MeshInstance3D:
			meshes.append(child)
			materials.append(child.material_override)
		else:
			_collect_meshes_and_materials(child, meshes, materials)

# ---- Методы для обновления позиций и поворотов ----
func set_node_position(node_id: int, pos: Vector3):
	if nodes_data.has(node_id) and nodes_data[node_id].has("mesh"):
		nodes_data[node_id].mesh.global_position = pos

func set_node_rotation(node_id: int, rot: Vector3):
	if nodes_data.has(node_id) and nodes_data[node_id].has("mesh"):
		nodes_data[node_id].mesh.rotation = rot

# ---- Анимация дронов (мигание/увеличение) ----
func animate_drone(node_id: int):
	var data = nodes_data.get(node_id)
	if not data: return
	var drone = data.mesh
	var original_scale = drone.scale
	var target_scale = original_scale * 1.1
	target_scale = target_scale.clamp(Vector3.ONE, Vector3.ONE * 1.3)
	var tween = create_tween()
	tween.tween_property(drone, "scale", target_scale, 0.05)
	tween.tween_property(drone, "scale", Vector3.ONE, 0.1)
	_flash_white(data)

func _flash_white(data: Dictionary):
	var meshes = data.meshes
	var default_mats = data.default_materials
	if meshes.is_empty(): return
	for mesh in meshes:
		mesh.material_override = white_material
	await get_tree().create_timer(0.15).timeout
	for i in range(meshes.size()):
		meshes[i].material_override = default_mats[i]

# ---- Линии пакетов ----
func update_packet_lines(time: float, packet_intervals: Array, is_playing: bool, animated_packets: Dictionary, on_animate: Callable):
	_clear_active_lines()
	for pkt in packet_intervals:
		if pkt.send_time <= time and time <= pkt.send_time + PACKET_VISUAL_DURATION:
			var key = str(pkt.send_time) + "_" + str(pkt.from_node) + "_" + str(pkt.to_node) + "_" + pkt.type
			if is_playing and not animated_packets.has(key):
				animated_packets[key] = true
				on_animate.call(pkt.from_node)
				on_animate.call(pkt.to_node)
			var from_node = nodes_data.get(pkt.from_node)
			var to_node = nodes_data.get(pkt.to_node)
			if from_node and to_node:
				var line = _add_packet_line(
					from_node.mesh.global_position,
					to_node.mesh.global_position,
					_color_packet_type(pkt.type)
				)
				if line:
					active_lines.append(line)

func _clear_active_lines():
	for line in active_lines:
		if is_instance_valid(line):
			line.queue_free()
	active_lines.clear()

func _color_packet_type(pkt_type: String) -> Color:
	match pkt_type:
		"HELLO": return Color.CYAN
		"CHALLENGE": return Color.ORANGE
		"RESPONSE": return Color.BLUE
		"PROVISIONAL_OK": return Color.GREEN
		_: return Color.YELLOW

# ---- Метки аутентификации ----
func update_auth_ok_labels(time: float, intervals: Array):
	_clear_auth_labels(active_auth_ok_labels)
	for ok in intervals:
		if ok.time <= time and time <= ok.time + AUTH_VISUAL_DURATION:
			var drone1 = nodes_data.get(ok.node1, {}).get("mesh")
			var drone2 = nodes_data.get(ok.node2, {}).get("mesh")
			if not drone1 or not drone2: continue
			var label1 = _create_auth_label("✓ AUTH OK", Color.GREEN)
			drone1.add_child(label1)
			active_auth_ok_labels.append(label1)
			var label2 = _create_auth_label("✓ AUTH OK", Color.GREEN)
			drone2.add_child(label2)
			active_auth_ok_labels.append(label2)

func update_auth_fail_labels(time: float, intervals: Array):
	_clear_auth_labels(active_auth_labels)
	for fail in intervals:
		if fail.time <= time and time <= fail.time + AUTH_VISUAL_DURATION:
			var drone1 = nodes_data.get(fail.node1, {}).get("mesh")
			var drone2 = nodes_data.get(fail.node2, {}).get("mesh")
			if not drone1 or not drone2: continue
			var label1 = _create_auth_label("✗ AUTH FAILED", Color.RED)
			drone1.add_child(label1)
			active_auth_labels.append(label1)
			var label2 = _create_auth_label("✗ AUTH FAILED", Color.RED)
			drone2.add_child(label2)
			active_auth_labels.append(label2)

func _create_auth_label(text: String, color: Color) -> Label3D:
	var label = Label3D.new()
	label.text = text
	label.modulate = color
	label.pixel_size = 0.06
	label.billboard = true
	label.no_depth_test = true
	label.position = Vector3(0, 1.5, 0)
	return label

func _clear_auth_labels(storage: Array):
	for label in storage:
		if is_instance_valid(label): label.queue_free()
	storage.clear()

# ---- Настройки отображения ----
func set_show_labels(visible: bool):
	show_node_labels = visible
	for node_id in nodes_data:
		if nodes_data[node_id].has("label"):
			nodes_data[node_id].label.visible = visible

func set_simple_spheres(enabled: bool):
	use_simple_spheres = enabled


func _add_packet_line(from: Vector3, to: Vector3, color: Color) -> MeshInstance3D:
	var direction = to - from
	var length = direction.length()
	if length < 0.01:
		return null
	
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.08
	cylinder.bottom_radius = 0.08
	cylinder.height = length
	
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	cylinder.material = material
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = cylinder
	
	mesh_instance.position = (from + to) / 2

	var dir = direction.normalized()
	var up = Vector3.UP
	var quat = Quaternion(up, dir)
	mesh_instance.quaternion = quat
	
	add_child(mesh_instance)
	return mesh_instance
