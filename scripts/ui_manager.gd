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
@export var top_right_panel: HBoxContainer
@export var stats_btn: Button
@export var help_btn: Button
@export var settings_btn: Button
@export var overlay: ColorRect

# Диалоги
@onready var stats_dialog: Panel = $StatisticsDialog
@onready var stats_title: Label = $StatisticsDialog/VBoxContainer/TitleLabel
@onready var stats_success: Label = $StatisticsDialog/VBoxContainer/SuccessLabel
@onready var stats_fail: Label = $StatisticsDialog/VBoxContainer/FailLabel
@onready var stats_total: Label = $StatisticsDialog/VBoxContainer/TotalLabel
@onready var stats_rate: Label = $StatisticsDialog/VBoxContainer/RateLabel
@onready var stats_progress: ProgressBar = $StatisticsDialog/VBoxContainer/ProgressBar
@onready var stats_close_btn: Button = $StatisticsDialog/VBoxContainer/CloseButton

@onready var settings_dialog: Window = $SettingsDialog
@onready var labels_check: CheckBox = $SettingsDialog/VBoxContainer/LabelsCheck
@onready var spheres_check: CheckBox = $SettingsDialog/VBoxContainer/SpheresCheck
@onready var lang_btn: Button = $SettingsDialog/VBoxContainer/LanguageButton
@onready var settings_cancel: Button = $SettingsDialog/VBoxContainer/HBoxContainer/CancelButton
@onready var settings_apply: Button = $SettingsDialog/VBoxContainer/HBoxContainer/ApplyButton

@onready var help_dialog: Window = $HelpDialog
@onready var help_text: RichTextLabel = $HelpDialog/VBoxContainer/HelpText
@onready var help_close_btn: Button = $HelpDialog/VBoxContainer/HBoxContainer/CloseButton


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
	time_slider.drag_started.connect(_on_slider_drag_start)
	time_slider.value_changed.connect(_on_time_slider_changed)
	play_pause_btn.pressed.connect(_on_play_pressed)
	speed_spinbox.value_changed.connect(_on_speed_changed)
	load_btn.pressed.connect(func(): load_requested.emit())
	stats_btn.pressed.connect(_show_statistics_dialog)
	help_btn.pressed.connect(_show_help_dialog)
	settings_btn.pressed.connect(_open_settings_dialog)
	
	load_settings()
	
	stats_close_btn.pressed.connect(_close_stats_dialog)
	settings_cancel.pressed.connect(_close_settings_dialog)
	settings_apply.pressed.connect(_apply_settings)
	help_close_btn.pressed.connect(_close_help_dialog)
	lang_btn.pressed.connect(_toggle_language_in_settings)
	
	update_language_ui()


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

func show_overlay():
	overlay.visible = true
	time_slider.editable = false
	if get_parent().is_playing:
		get_parent()._toggle_play()

func hide_overlay():
	overlay.visible = false
	time_slider.editable = true

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

func _show_statistics_dialog():
	if not file_loader:
		print("FileLoader not set")
		return
	show_overlay()
	var tr = translations[current_language]
	stats_dialog.visible = true
	stats_title.text = tr["stat_window_title"]
	stats_success.text = tr["stat_success"] + str(file_loader.auth_success_count)
	stats_fail.text = tr["stat_fail"] + str(file_loader.auth_fail_count)
	
	var total = file_loader.auth_success_count + file_loader.auth_fail_count
	stats_total.text = tr["stat_total"] + str(total)

	var rate = 0.0
	if total > 0:
		rate = float(file_loader.auth_success_count) / total * 100.0
	stats_rate.text = tr["stat_rate"] + "%.1f%%" % rate

	stats_progress.value = rate

	var fill_style = StyleBoxFlat.new()
	if rate >= 70:
		fill_style.bg_color = Color(0.2, 0.8, 0.2)
	elif rate >= 30:
		fill_style.bg_color = Color(0.9, 0.7, 0.1)
	else:
		fill_style.bg_color = Color(0.8, 0.2, 0.2)
	fill_style.set_corner_radius_all(8)
	stats_progress.add_theme_stylebox_override("fill", fill_style)

func _open_settings_dialog():
	if settings_dialog.visible:
		return
	show_overlay()
	settings_dialog.visible = true
	labels_check.text = translations[current_language]["show_labels"]
	spheres_check.text = translations[current_language]["simple_spheres"]
	labels_check.button_pressed = show_node_labels
	spheres_check.button_pressed = use_simple_spheres
	lang_btn.text = translations[current_language]["language"]
	settings_cancel.text = translations[current_language]["cancel"]
	settings_apply.text = translations[current_language]["apply"]
	settings_dialog.title = translations[current_language]["settings_title"]

func _show_help_dialog():
	if help_dialog.visible:
		return
	show_overlay()
	help_dialog.visible = true
	var tr = translations[current_language]
	help_text.clear()
	help_text.append_text("[b]" + tr["help_title"] + "[/b]\n\n")
	help_text.append_text(tr["help_text"])
	help_close_btn.text = tr["close"]

func _close_stats_dialog():
	stats_dialog.visible = false
	hide_overlay()

func _close_settings_dialog():
	settings_dialog.visible = false
	hide_overlay()

func _apply_settings():
	var old_spheres = use_simple_spheres
	show_node_labels = labels_check.button_pressed
	use_simple_spheres = spheres_check.button_pressed
	save_settings()
	update_language_ui()
	show_labels_toggled.emit(show_node_labels)
	simple_spheres_toggled.emit(use_simple_spheres)
	if old_spheres != use_simple_spheres:
		if not get_parent().scene_manager.nodes_data.is_empty():
			simple_spheres_toggled.emit(use_simple_spheres)
	_close_settings_dialog()

func _close_help_dialog():
	help_dialog.visible = false
	hide_overlay()

func _toggle_language_in_settings():
	if current_language == "ru":
		current_language = "en"
	else:
		current_language = "ru"
	lang_btn.text = translations[current_language]["language"]
	labels_check.text = translations[current_language]["show_labels"]
	spheres_check.text = translations[current_language]["simple_spheres"]
	settings_cancel.text = translations[current_language]["cancel"]
	settings_apply.text = translations[current_language]["apply"]
	settings_dialog.title = translations[current_language]["settings_title"]

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
