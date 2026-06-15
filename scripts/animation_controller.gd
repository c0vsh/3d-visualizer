extends Node
class_name AnimationController

signal position_updated(node_id: int, pos: Vector3)
signal rotation_updated(node_id: int, rot: Vector3)

var nodes_keyframes: Dictionary = {}  # node_id -> Array[{time, pos}]

func set_keyframes(keyframes: Dictionary):
	nodes_keyframes = keyframes

func get_interpolated_position(node_id: int, time: float) -> Vector3:
	var frames = nodes_keyframes.get(node_id, [])
	if frames.is_empty():
		return Vector3.ZERO
	if time <= frames[0].time:
		return frames[0].pos
	if time >= frames[-1].time:
		return frames[-1].pos
	var lo = 0
	var hi = frames.size() - 1
	while lo < hi:
		var mid = (lo + hi + 1) / 2
		if frames[mid].time <= time:
			lo = mid
		else:
			hi = mid - 1
	var t1 = frames[lo].time
	var t2 = frames[lo+1].time
	var p1 = frames[lo].pos
	var p2 = frames[lo+1].pos
	var f = (time - t1) / (t2 - t1)
	return p1.lerp(p2, f)

func get_velocity(node_id: int, time: float) -> Vector3:
	var frames = nodes_keyframes.get(node_id, [])
	if frames.size() < 2:
		return Vector3.ZERO
	var idx = _find_keyframe_index(frames, time)
	if idx < 0 or idx >= frames.size() - 1:
		return Vector3.ZERO
	var p1 = frames[idx].pos
	var p2 = frames[idx+1].pos
	var t1 = frames[idx].time
	var t2 = frames[idx+1].time
	return (p2 - p1) / (t2 - t1)

func get_rotation_from_velocity(vel: Vector3) -> Vector3:
	if vel.length() < 0.01:
		return Vector3.ZERO
	var yaw = atan2(vel.x, vel.z)
	var horizontal_speed = Vector2(vel.x, vel.z).length()
	var pitch = atan2(vel.y, horizontal_speed)
	pitch = clamp(pitch, -0.5, 0.5)
	return Vector3(pitch, yaw, 0.0)

func update_all_nodes(time: float):
	for node_id in nodes_keyframes:
		var pos = get_interpolated_position(node_id, time)
		if pos:
			position_updated.emit(node_id, pos)
			var vel = get_velocity(node_id, time)
			var rot = get_rotation_from_velocity(vel)
			rotation_updated.emit(node_id, rot)

func _find_keyframe_index(frames: Array, time: float) -> int:
	if frames.is_empty(): return -1
	if time <= frames[0].time: return 0
	if time >= frames[-1].time: return frames.size() - 2
	var lo = 0
	var hi = frames.size() - 1
	while lo < hi:
		var mid = (lo + hi + 1) / 2
		if frames[mid].time <= time:
			lo = mid
		else:
			hi = mid - 1
	return lo
