extends CanvasLayer
class_name UIManager

signal play_pressed
signal stop_pressed
signal load_requested
signal time_changed(new_time: float)
signal speed_changed(new_speed: float)
signal language_changed(lang: String)
signal show_labels_toggled(visible: bool)
signal simple_spheres_toggled(enabled: bool)

@export var play_pause_btn: Button
@export var time_slider: HSlider
@export var time_label: Label
@export var speed_spinbox: SpinBox
@export var load_btn: Button

var stats_btn: Button
var overlay: ColorRect
var file_loader: FileLoader

var current_language: String = "ru"
var show_node_labels: bool = true
var use_simple_spheres: bool = false

var translations: Dictionary = {
	"ru": {
		"play": "Воспр.",
		"pause": "Пауза",
		"stop": "Стоп",
		"load": "Загрузить лог",
		"stats": "Статистика",
		"settings": "Настройки",
		"time": "с",
		"speed": "Скорость",
		"stat_window_title": "📊 Статистика",
		"stat_success": "✅ Успешно: ",
		"stat_fail": "❌ Неудачно: ",
		"stat_total": "📋 Всего попыток: ",
		"stat_rate": "📈 Процент успеха: ",
		"close": "Закрыть",
		"help_title": "Инструкция",
		"help_text": "Управление:\n\n• Камера: зажмите ПКМ + двигайте мышь для вращения\n• Колёсико мыши – приближение/отдаление\n• Кнопка Play/Pause – воспроизведение/приостановка симуляции\n• Ползунок времени – перемотка (ЛКМ)\n• Скорость – изменение скорости воспроизведения\n• Загрузить лог – открыть окно загрузки нового файла лога\n• Настройки (⚙️) – показать/скрыть номера узлов, выбрать язык, режим отображения\n• Инструкция ( ? ) – открыть это окно\n• Статистика (📊) – открыть окно статистики\n\nПакеты отображаются цветными линиями:\n\n• Голубой – HELLO\n• Оранжевый – CHALLENGE\n• Синий – RESPONSE\n• Зеленый – PROVISIONAL_OK\n\nПри получении/отправке пакетов узлы мигают белым.\nПри успешной/неуспешной аутентификации показывается сообщение над узлом.\n\n",
		"settings_title": "Настройки",
		"show_labels": "Показывать номера узлов",
		"language": "Язык: Русский",
		"simple_spheres": "Упрощённые модели",
		"apply": "Применить",
		"cancel": "Отмена"
	},
	"en": {
		"play": "Play",
		"pause": "Pause",
		"stop": "Stop",
		"load": "Load log",
		"stats": "Statistics",
		"settings": "Settings",
		"time": "s",
		"speed": "Speed",
		"stat_window_title": "📊 Statistics",
		"stat_success": "✅ Successful: ",
		"stat_fail": "❌ Failed: ",
		"stat_total": "📋 Total attempts: ",
		"stat_rate": "📈 Success rate: ",
		"close": "Close",
		"settings_title": "Settings",
		"show_labels": "Show node IDs",
		"language": "Language: English",
		"simple_spheres": "Simple spheres (instead of models)",
		"apply": "Apply",
		"help_title": "Instructions",
		"help_text": "Controls:\n\n• Camera: hold RMB + move mouse to rotate\n• Mouse wheel – zoom in/out\n• Play/Pause button – start/pause visualisation\n• Time slider – seek (LMB drag)\n• Speed – change playback speed\n• Load log – open file dialog to load a new log\n• Settings (⚙️) – toggle node IDs, choose language, display mode\n• Help ( ? ) – open this window\n• Stats (📊) – open stats window\n\nPackets are shown as colored lines:\n\n• Cyan – HELLO\n• Orange – CHALLENGE\n• Blue – RESPONSE\n• Green – PROVISIONAL_OK\n\nWhen packets are sent/received, nodes flash white.\nOn successful/failed authentication, a message appears above the node.\n\n",
		"cancel": "Cancel"
	}
}

func _ready():
	# Настройка UI
	time_slider.drag_started.connect(_on_slider_drag_start)
	time_slider.value_changed.connect(_on_time_slider_changed)
	play_pause_btn.pressed.connect(_on_play_pressed)
	speed_spinbox.value_changed.connect(_on_speed_changed)
	load_btn.pressed.connect(func(): load_requested.emit())
	speed_spinbox.min_value = 0.1
	speed_spinbox.max_value = 10.0
	speed_spinbox.step = 0.1
	speed_spinbox.value = 1.0

	# Загрузка настроек
	load_settings()

	# Создание
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.2, 0.2, 0.7)
	btn_style.set_corner_radius_all(8)
	var top_panel = HBoxContainer.new()
	top_panel.anchor_left = 1.0
	top_panel.anchor_right = 1.0
	top_panel.offset_left = -150
	top_panel.offset_top = 10
	top_panel.offset_right = -10
	top_panel.add_theme_constant_override("separation", 10)
	add_child(top_panel)

	stats_btn = _create_icon_button("📊", btn_style)
	stats_btn.disabled = true
	stats_btn.pressed.connect(_show_statistics_dialog)
	top_panel.add_child(stats_btn)

	var help_btn = _create_icon_button("?", btn_style)
	help_btn.pressed.connect(_show_help_dialog)
	top_panel.add_child(help_btn)

	var settings_btn = _create_icon_button("⚙️", btn_style)
	settings_btn.pressed.connect(_open_settings_dialog)
	top_panel.add_child(settings_btn)

	# Затемняющий слой
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 10
	overlay.visible = false
	add_child(overlay)
	update_language_ui()

func _create_icon_button(icon: String, style: StyleBoxFlat) -> Button:
	var btn = Button.new()
	btn.text = icon
	btn.flat = false
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.custom_minimum_size = Vector2(40, 40)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_color_override("font_color", Color.WHITE)
	return btn

# ---------- Внешние интерфейсы ----------
func set_file_loader(loader: FileLoader):
	file_loader = loader

func set_playing_state(is_playing: bool):
	if is_playing:
		play_pause_btn.material.set_shader_parameter("tint_color", Color(0.392, 0.392, 0.392))
	else:
		play_pause_btn.material.set_shader_parameter("tint_color", Color(0.678, 0.678, 0.678))

func set_max_time(max_time: float):
	time_slider.max_value = max_time

func set_current_time(time: float):
	time_slider.value = time
	time_label.text = str(time).pad_decimals(2) + " s"

func enable_stats_button(enabled: bool):
	stats_btn.disabled = not enabled

func update_language_ui():
	var tr = translations[current_language]
	load_btn.text = tr["load"]
	#stats_btn.tooltip_text = tr["stats"]

func show_overlay():
	overlay.visible = true
	time_slider.editable = false

func hide_overlay():
	overlay.visible = false
	time_slider.editable = true

# ---------- Обработчики UI ----------
func _on_play_pressed():
	play_pressed.emit()

func _on_slider_drag_start():
	if not get_parent().is_playing:
		return
	play_pressed.emit() 

func _on_time_slider_changed(value: float):
	time_changed.emit(value)

func _on_speed_changed(value: float):
	speed_changed.emit(value)

# ---------- Диалог статистики ----------
func _show_statistics_dialog():
	if not file_loader:
		print("FileLoader not set")
		return
	show_overlay()
	var tr = translations[current_language]

	var panel = Panel.new()
	panel.z_index = 20
	panel.size = Vector2(420, 320)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -210
	panel.offset_top = -160
	panel.offset_right = 210
	panel.offset_bottom = 160

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.25, 0.25)
	style.set_corner_radius_all(12)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color.DIM_GRAY
	panel.add_theme_stylebox_override("panel", style)

	var title = Label.new()
	title.text = tr["stat_window_title"]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.position = Vector2(0, 15)
	title.size = Vector2(panel.size.x, 40)
	panel.add_child(title)

	var sep = HSeparator.new()
	sep.position = Vector2(20, 60)
	sep.size = Vector2(panel.size.x - 40, 5)
	panel.add_child(sep)

	var y_offset = 80
	var line_height = 35

	var success_label = Label.new()
	success_label.text = tr["stat_success"] + str(file_loader.auth_success_count)
	success_label.position = Vector2(30, y_offset)
	success_label.size = Vector2(panel.size.x - 60, 30)
	success_label.add_theme_font_size_override("font_size", 16)
	success_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	panel.add_child(success_label)
	y_offset += line_height

	var fail_label = Label.new()
	fail_label.text = tr["stat_fail"] + str(file_loader.auth_fail_count)
	fail_label.position = Vector2(30, y_offset)
	fail_label.size = Vector2(panel.size.x - 60, 30)
	fail_label.add_theme_font_size_override("font_size", 16)
	fail_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	panel.add_child(fail_label)
	y_offset += line_height

	var total = file_loader.auth_success_count + file_loader.auth_fail_count
	var total_label = Label.new()
	total_label.text = tr["stat_total"] + str(total)
	total_label.position = Vector2(30, y_offset)
	total_label.size = Vector2(panel.size.x - 60, 30)
	total_label.add_theme_font_size_override("font_size", 16)
	total_label.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(total_label)
	y_offset += line_height

	var success_rate = 0.0
	if total > 0:
		success_rate = float(file_loader.auth_success_count) / total * 100.0
	var rate_label = Label.new()
	rate_label.text = tr["stat_rate"] + "%.1f%%" % success_rate
	rate_label.position = Vector2(30, y_offset)
	rate_label.size = Vector2(panel.size.x - 60, 30)
	rate_label.add_theme_font_size_override("font_size", 16)
	rate_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	panel.add_child(rate_label)
	y_offset += 30

	var progress_bar = ProgressBar.new()
	progress_bar.position = Vector2(30, y_offset)
	progress_bar.size = Vector2(panel.size.x - 60, 20)
	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.value = success_rate

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.2, 0.25)
	bg_style.set_corner_radius_all(8)
	progress_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style = StyleBoxFlat.new()
	if success_rate >= 70:
		fill_style.bg_color = Color(0.2, 0.8, 0.2)
	elif success_rate >= 30:
		fill_style.bg_color = Color(0.9, 0.7, 0.1)
	else:
		fill_style.bg_color = Color(0.8, 0.2, 0.2)
	fill_style.set_corner_radius_all(8)
	progress_bar.add_theme_stylebox_override("fill", fill_style)
	panel.add_child(progress_bar)

	var close_btn = Button.new()
	close_btn.text = tr["close"]
	close_btn.position = Vector2(panel.size.x / 2 - 40, panel.size.y - 55)
	close_btn.size = Vector2(80, 30)
	panel.add_child(close_btn)
	close_btn.pressed.connect(func():
		panel.queue_free()
		hide_overlay()
	)

	panel.modulate = Color.TRANSPARENT
	add_child(panel)
	var tween = create_tween()
	tween.tween_property(panel, "modulate", Color.WHITE, 0.25)

# ---------- Диалог настроек ----------
func _open_settings_dialog():
	show_overlay()
	var dialog = Window.new()
	dialog.title = translations[current_language]["settings_title"]
	dialog.size = Vector2(350, 220)
	dialog.position = (get_viewport().size - dialog.size) / 2
	dialog.exclusive = true
	dialog.transient = true
	dialog.unresizable = true
	add_child(dialog)

	var vbox = VBoxContainer.new()
	vbox.anchor_right = 1
	vbox.anchor_bottom = 1
	vbox.offset_top = 10
	vbox.offset_left = 10
	vbox.offset_right = -10
	vbox.offset_bottom = -50
	dialog.add_child(vbox)

	var label_check = CheckBox.new()
	label_check.text = translations[current_language]["show_labels"]
	label_check.button_pressed = show_node_labels
	vbox.add_child(label_check)

	var spheres_check = CheckBox.new()
	spheres_check.text = translations[current_language]["simple_spheres"]
	spheres_check.button_pressed = use_simple_spheres
	vbox.add_child(spheres_check)
	
	var cancel_btn = Button.new()
	var apply_btn = Button.new()
	var lang_btn = Button.new()
	lang_btn.text = translations[current_language]["language"]
	lang_btn.flat = true
	lang_btn.pressed.connect(func():
		if current_language == "ru":
			current_language = "en"
		else:
			current_language = "ru"
		lang_btn.text = translations[current_language]["language"]
		label_check.text = translations[current_language]["show_labels"]
		spheres_check.text = translations[current_language]["simple_spheres"]
		dialog.title = translations[current_language]["settings_title"]
		cancel_btn.text = translations[current_language]["cancel"]
		apply_btn.text = translations[current_language]["apply"]
	)
	vbox.add_child(lang_btn)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 15)
	vbox.add_child(spacer)

	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)

	
	cancel_btn.text = translations[current_language]["cancel"]
	hbox.add_child(cancel_btn)

	
	apply_btn.text = translations[current_language]["apply"]
	hbox.add_child(apply_btn)

	cancel_btn.pressed.connect(func():
		dialog.queue_free()
		hide_overlay()
	)

	apply_btn.pressed.connect(func():
		var old_spheres = use_simple_spheres
		show_node_labels = label_check.button_pressed
		use_simple_spheres = spheres_check.button_pressed
		save_settings()
		update_language_ui()
		show_labels_toggled.emit(show_node_labels)
		if old_spheres != use_simple_spheres:
			# Перезагрузка лога
			if not get_parent().scene_manager.nodes_data.is_empty():
				simple_spheres_toggled.emit(use_simple_spheres)
		dialog.queue_free()
		hide_overlay()
	)

# ---------- Диалог справки ----------
func _show_help_dialog():
	show_overlay()
	var window = Window.new()
	var tr = translations[current_language]
	window.title = tr["help_title"]
	window.size = Vector2(650, 650)
	window.position = (get_viewport().size - window.size) / 2
	window.exclusive = true
	window.transient = true
	window.unresizable = true
	add_child(window)

	var vbox = VBoxContainer.new()
	vbox.anchor_right = 1
	vbox.anchor_bottom = 1
	vbox.offset_top = 10
	vbox.offset_left = 10
	vbox.offset_right = -10
	vbox.offset_bottom = -50
	window.add_child(vbox)

	var rich_text = RichTextLabel.new()
	rich_text.bbcode_enabled = true
	rich_text.fit_content = true
	rich_text.size_flags_vertical = Control.SIZE_EXPAND
	rich_text.append_text("[b]" + tr["help_title"] + "[/b]\n\n")
	rich_text.append_text(tr["help_text"])
	vbox.add_child(rich_text)

	var close_btn = Button.new()
	close_btn.text = tr["close"]
	close_btn.size = Vector2(80, 30)
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(close_btn)
	vbox.add_child(hbox)

	close_btn.pressed.connect(func():
		window.queue_free()
		hide_overlay()
	)

# ---------- Загрузка/сохранение настроек ----------
func load_settings():
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		show_node_labels = config.get_value("display", "show_labels", true)
		current_language = config.get_value("ui", "language", "ru")
		use_simple_spheres = config.get_value("display", "simple_spheres", false)
	else:
		pass

func save_settings():
	var config = ConfigFile.new()
	config.set_value("display", "show_labels", show_node_labels)
	config.set_value("ui", "language", current_language)
	config.set_value("display", "simple_spheres", use_simple_spheres)
	config.save("user://settings.cfg")
