extends Node
class_name FileLoader

signal log_loaded(data: Dictionary)
signal load_error(error: String)

var nodes_keyframes: Dictionary = {}   # node_id -> Array[{time, pos}]
var packet_intervals: Array = []       # {send_time, recv_time, from_node, to_node, type}
var auth_ok_intervals: Array = []      # {time, node1, node2}
var auth_fail_intervals: Array = []    # {time, node1, node2}
var auth_success_count: int = 0
var auth_fail_count: int = 0
var max_time: float = 0.0

var current_log_path: String = ""

var re_pos := RegEx.new()
var re_sid := RegEx.new()
var re_peer := RegEx.new()
var re_from := RegEx.new()

func _ready():
	re_pos.compile("^(\\d+(?:\\.\\d+)?)s\\s+(\\d+)\\s+pos=\\(([^,]+),([^,]+),([^)]+)\\)")
	re_sid.compile("sid=(\\d+)")
	re_peer.compile("peer=(\\d+)")
	re_from.compile("from\\s+(\\d+)")

func load_log_file(path: String = ""):
	get_parent().ui.show_overlay()
	
	if path == "":
		_open_native_dialog()
		return
	_clear_data()
	var success = _parse_file(path)
	if success:
		current_log_path = path
		max_time = _compute_max_time()
		log_loaded.emit({
			"nodes_keyframes": nodes_keyframes,
			"packet_intervals": packet_intervals,
			"auth_ok_intervals": auth_ok_intervals,
			"auth_fail_intervals": auth_fail_intervals,
			"auth_success_count": auth_success_count,
			"auth_fail_count": auth_fail_count,
			"max_time": max_time,
			"log_path": current_log_path
		})
	else:
		load_error.emit("Failed to parse file")
	
	get_parent().ui.hide_overlay()

func _open_native_dialog():
	var filters = PackedStringArray(["*.txt", "*.log"])
	DisplayServer.file_dialog_show(
		"Select log file",
		OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS),
		"",
		false,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
		filters,
		_on_file_dialog_callback
	)

func _on_file_dialog_callback(selected: bool, paths: PackedStringArray, _filter_id: int):
	if selected and paths.size() > 0:
		load_log_file(paths[0])
	get_parent().ui.hide_overlay()

func _parse_file(path: String) -> bool:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		printerr("Cannot open file: ", path)
		return false
	
	var lines = file.get_as_text().split("\n")
	var pending_sends = {}  # sid -> {time, from, to, type}
	var last_hello_send = {} # node_id -> time
	
	for line in lines:
		line = line.strip_edges()
		if line.is_empty():
			continue
		
		# ----- Позиция -----
		var pos_match = re_pos.search(line)
		if pos_match:
			var time = pos_match.strings[1].to_float()
			var node_id = pos_match.strings[2].to_int()
			var x = pos_match.strings[3].to_float()
			var y = pos_match.strings[4].to_float()
			var z = pos_match.strings[5].to_float()
			if not nodes_keyframes.has(node_id):
				nodes_keyframes[node_id] = []
			nodes_keyframes[node_id].append({time=time, pos=Vector3(x, y, z)})
			continue
		
		# ----- Статистика -----
		if "-> PROVISIONAL_OK" in line:
			auth_success_count += 1
		elif "auth failed with peer=" in line:
			auth_fail_count += 1
			var parts = line.split(" ")
			var time = parts[0].replace("s", "").to_float()
			var node1 = parts[1].to_int()
			var peer_match = re_peer.search(line)
			if peer_match:
				var node2 = peer_match.strings[1].to_int()
				auth_fail_intervals.append({time=time, node1=node1, node2=node2})
		
		# ----- HELLO отправка -----
		if " -> HELLO" in line:
			var parts = line.split(" ")
			var time = parts[0].replace("s", "").to_float()
			var from_node = parts[1].to_int()
			last_hello_send[from_node] = time
			continue
		
		# ----- Отправка CHALLENGE / RESPONSE / PROVISIONAL_OK -----
		if " -> CHALLENGE" in line or " -> RESPONSE" in line or " -> PROVISIONAL_OK" in line:
			var parts = line.split(" ")
			var time = parts[0].replace("s", "").to_float()
			var from_node = parts[1].to_int()
			var pkt_type = ""
			if "CHALLENGE" in line: pkt_type = "CHALLENGE"
			elif "RESPONSE" in line: pkt_type = "RESPONSE"
			elif "PROVISIONAL_OK" in line: pkt_type = "PROVISIONAL_OK"
			var sid_match = re_sid.search(line)
			if not sid_match: continue
			var sid = sid_match.strings[1].to_int()
			var to_node = -1
			var to_match = RegEx.create_from_string("to\\s+(\\d+)").search(line)
			if to_match: to_node = to_match.strings[1].to_int()
			pending_sends[sid] = {time=time, from=from_node, to=to_node, type=pkt_type}
			continue
		
		# ----- Получение CHALLENGE / RESPONSE / PROVISIONAL_OK -----
		if " <- CHALLENGE" in line or " <- RESPONSE" in line or " <- PROVISIONAL_OK" in line:
			var parts = line.split(" ")
			var recv_time = parts[0].replace("s", "").to_float()
			var to_node = parts[1].to_int()
			var from_match = re_from.search(line)
			if not from_match: continue
			var from_node = from_match.strings[1].to_int()
			var pkt_type = ""
			if "CHALLENGE" in line: pkt_type = "CHALLENGE"
			elif "RESPONSE" in line: pkt_type = "RESPONSE"
			elif "PROVISIONAL_OK" in line: pkt_type = "PROVISIONAL_OK"
			var sid_match = re_sid.search(line)
			if not sid_match: continue
			var sid = sid_match.strings[1].to_int()
			if pending_sends.has(sid):
				var send = pending_sends[sid]
				if send.type == pkt_type and send.from == from_node and send.to == to_node:
					packet_intervals.append({
						send_time = send.time,
						recv_time = recv_time,
						from_node = from_node,
						to_node = to_node,
						type = pkt_type
					})
					pending_sends.erase(sid)
					if pkt_type == "PROVISIONAL_OK":
						auth_ok_intervals.append({time=recv_time, node1=from_node, node2=to_node})
			continue
		
		# ----- Получение HELLO -----
		if " <- HELLO from" in line:
			var parts = line.split(" ")
			var recv_time = parts[0].replace("s", "").to_float()
			var to_node = parts[1].to_int()
			var from_match = re_from.search(line)
			if not from_match: continue
			var from_node = from_match.strings[1].to_int()
			if last_hello_send.has(from_node):
				var send_time = last_hello_send[from_node]
				if recv_time - send_time <= 1.0:
					packet_intervals.append({
						send_time = send_time,
						recv_time = recv_time,
						from_node = from_node,
						to_node = to_node,
						type = "HELLO"
					})
			continue
	
	file.close()
	
	# Сортировка ключевых кадров
	for node_id in nodes_keyframes:
		var frames = nodes_keyframes[node_id]
		frames.sort_custom(func(a,b): return a.time < b.time)
	
	packet_intervals.sort_custom(func(a,b): return a.send_time < b.send_time)
	auth_ok_intervals.sort_custom(func(a,b): return a.time < b.time)
	auth_fail_intervals.sort_custom(func(a,b): return a.time < b.time)
	return true

func _compute_max_time() -> float:
	var max_t = 0.0
	for frames in nodes_keyframes.values():
		if frames.size() > 0 and frames[-1].time > max_t:
			max_t = frames[-1].time
	for pkt in packet_intervals:
		if pkt.send_time > max_t: max_t = pkt.send_time
		if pkt.recv_time > max_t: max_t = pkt.recv_time
	for ok in auth_ok_intervals:
		if ok.time > max_t: max_t = ok.time
	for fail in auth_fail_intervals:
		if fail.time > max_t: max_t = fail.time
	return max_t

func _clear_data():
	nodes_keyframes.clear()
	packet_intervals.clear()
	auth_ok_intervals.clear()
	auth_fail_intervals.clear()
	auth_success_count = 0
	auth_fail_count = 0
	max_time = 0.0
