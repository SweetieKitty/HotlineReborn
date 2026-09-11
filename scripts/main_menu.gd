extends Control

@export var game_scene_path: String = "res://tscn/mainworld.tscn"
@export var character_select_scene: PackedScene = preload("res://tscn/character_select.tscn")

var title_label: Label
var settings_title: Label
var time_elapsed: float = 0.0
var main_container: VBoxContainer
var settings_container: VBoxContainer
var start_button: Button
var settings_button: Button
var exit_button: Button
var impact_font: Font

# Шлях до файлу збереження
var config_path = "user://audio_settings.cfg"
var config = ConfigFile.new()

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	impact_font = load("res://fonts/Impact.ttf")
	_load_audio_settings() # 🔥 Завантажуємо налаштування ПЕРЕД створенням меню
	_remove_all_hud()
	_create_menu()

func _process(delta: float) -> void:
	time_elapsed += delta
	_animate_title()

# 🔥 ЗАВАНТАЖЕННЯ ЗВУКУ
func _load_audio_settings() -> void:
	if config.load(config_path) == OK:
		for bus_name in ["Master", "Music", "SFX", "UI"]:
			var bus_idx = AudioServer.get_bus_index(bus_name)
			if bus_idx != -1:
				var vol = config.get_value("Audio", bus_name, 0.0)
				AudioServer.set_bus_volume_db(bus_idx, vol)
				AudioServer.set_bus_mute(bus_idx, vol <= -40.0)

# 🔥 ЗБЕРЕЖЕННЯ ЗВУКУ
func _save_audio_settings() -> void:
	for bus_name in ["Master", "Music", "SFX", "UI"]:
		var bus_idx = AudioServer.get_bus_index(bus_name)
		if bus_idx != -1:
			config.set_value("Audio", bus_name, AudioServer.get_bus_volume_db(bus_idx))
	config.save(config_path)
	print("💾 Налаштування звуку збережено!")

func _play_ui_sound(sound_name: String) -> void:
	var p = AudioStreamPlayer.new()
	var paths = ["res://assets/sounds/" + sound_name + ".mp3", "res://assets/sounds/" + sound_name + ".wav", "res://assets/sounds/" + sound_name + ".ogg"]
	for path in paths:
		if ResourceLoader.exists(path):
			p.stream = load(path)
			break
	if p.stream:
		p.bus = "UI" # 🔥 ВІДПРАВЛЯЄМО В ШИНУ ІНТЕРФЕЙСУ
		if sound_name == "ui_click":
			p.volume_db = -18.0
		elif sound_name == "ui_hover":
			p.volume_db = -22.0
		else:
			p.volume_db = -15.0
			
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.add_child(p)
		p.play()
		p.finished.connect(func(): p.queue_free())

func _create_menu() -> void:
	var background = ColorRect.new()
	background.color = Color(0.05, 0.05, 0.08)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	
	_create_stars()
	
	var center_container = Control.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center_container)
	
	main_container = VBoxContainer.new()
	main_container.position = Vector2(0, 380)
	main_container.size = Vector2(get_viewport_rect().size.x, 0)
	main_container.alignment = BoxContainer.ALIGNMENT_CENTER
	main_container.add_theme_constant_override("separation", 15)
	center_container.add_child(main_container)
	
	title_label = Label.new()
	title_label.text = "HOTLINE REBORN"
	title_label.add_theme_font_size_override("font_size", 80) 
	title_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title_label.add_theme_constant_override("outline_size", 6) 
	if impact_font != null:
		title_label.add_theme_font_override("font", impact_font)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_child(title_label)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 5)
	main_container.add_child(spacer)
	
	var button_container = VBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 20)
	button_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_child(button_container)
	
	var purple_style = StyleBoxFlat.new()
	purple_style.bg_color = Color(0.08, 0.06, 0.15, 0.9)
	purple_style.border_color = Color(0.4, 0.3, 0.6, 0.5)
	purple_style.border_width_left = 2
	purple_style.border_width_right = 2
	purple_style.border_width_top = 2
	purple_style.border_width_bottom = 2
	purple_style.corner_radius_top_left = 16
	purple_style.corner_radius_top_right = 16
	purple_style.corner_radius_bottom_left = 16
	purple_style.corner_radius_bottom_right = 16
	purple_style.shadow_size = 6
	purple_style.shadow_color = Color(0.2, 0.1, 0.3, 0.4)
	purple_style.shadow_offset = Vector2(0, 3)
	
	var purple_hover_style = StyleBoxFlat.new()
	purple_hover_style.bg_color = Color(0.1, 0.06, 0.2, 0.95)
	purple_hover_style.border_color = Color(0.6, 0.3, 0.9, 0.8)
	purple_hover_style.border_width_left = 2
	purple_hover_style.border_width_right = 2
	purple_hover_style.border_width_top = 2
	purple_hover_style.border_width_bottom = 2
	purple_hover_style.corner_radius_top_left = 16
	purple_hover_style.corner_radius_top_right = 16
	purple_hover_style.corner_radius_bottom_left = 16
	purple_hover_style.corner_radius_bottom_right = 16
	purple_hover_style.shadow_size = 12
	purple_hover_style.shadow_color = Color(0.5, 0.2, 0.8, 0.6)
	purple_hover_style.shadow_offset = Vector2(0, 4)

	start_button = Button.new()
	start_button.text = "▶  ПОЧАТИ ГРУ"
	start_button.add_theme_font_size_override("font_size", 32)
	start_button.custom_minimum_size = Vector2(400, 80)
	start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_button.pressed.connect(_on_start_pressed)
	start_button.mouse_entered.connect(func(): _play_ui_sound("ui_hover")) 
	if impact_font != null:
		start_button.add_theme_font_override("font", impact_font)
	start_button.add_theme_stylebox_override("normal", purple_style)
	start_button.add_theme_stylebox_override("hover", purple_hover_style)
	start_button.add_theme_stylebox_override("pressed", purple_hover_style)
	button_container.add_child(start_button)
	
	settings_button = Button.new()
	settings_button.text = "⚙  НАЛАШТУВАННЯ"
	settings_button.add_theme_font_size_override("font_size", 32)
	settings_button.custom_minimum_size = Vector2(400, 80)
	settings_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	settings_button.pressed.connect(_on_settings_pressed)
	settings_button.mouse_entered.connect(func(): _play_ui_sound("ui_hover")) 
	if impact_font != null:
		settings_button.add_theme_font_override("font", impact_font)
	settings_button.add_theme_stylebox_override("normal", purple_style)
	settings_button.add_theme_stylebox_override("hover", purple_hover_style)
	settings_button.add_theme_stylebox_override("pressed", purple_hover_style)
	button_container.add_child(settings_button)
	
	exit_button = Button.new()
	exit_button.text = "✖  ВИЙТИ З ГРИ"
	exit_button.add_theme_font_size_override("font_size", 32)
	exit_button.custom_minimum_size = Vector2(400, 80)
	exit_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	exit_button.pressed.connect(_on_exit_pressed)
	exit_button.mouse_entered.connect(func(): _play_ui_sound("ui_hover")) 
	if impact_font != null:
		exit_button.add_theme_font_override("font", impact_font)
	
	var exit_style = StyleBoxFlat.new()
	exit_style.bg_color = Color(0.08, 0.06, 0.15, 0.9)
	exit_style.border_color = Color(0.4, 0.3, 0.6, 0.5)
	exit_style.border_width_left = 2
	exit_style.border_width_right = 2
	exit_style.border_width_top = 2
	exit_style.border_width_bottom = 2
	exit_style.corner_radius_top_left = 16
	exit_style.corner_radius_top_right = 16
	exit_style.corner_radius_bottom_left = 16
	exit_style.corner_radius_bottom_right = 16
	exit_style.shadow_size = 6
	exit_style.shadow_color = Color(0.2, 0.1, 0.3, 0.4)
	exit_style.shadow_offset = Vector2(0, 3)
	
	var exit_hover_style = StyleBoxFlat.new()
	exit_hover_style.bg_color = Color(0.2, 0.05, 0.05, 0.95)
	exit_hover_style.border_color = Color(0.9, 0.2, 0.2, 0.8)
	exit_hover_style.border_width_left = 2
	exit_hover_style.border_width_right = 2
	exit_hover_style.border_width_top = 2
	exit_hover_style.border_width_bottom = 2
	exit_hover_style.corner_radius_top_left = 16
	exit_hover_style.corner_radius_top_right = 16
	exit_hover_style.corner_radius_bottom_left = 16
	exit_hover_style.corner_radius_bottom_right = 16
	exit_hover_style.shadow_size = 12
	exit_hover_style.shadow_color = Color(0.8, 0.1, 0.1, 0.6)
	exit_hover_style.shadow_offset = Vector2(0, 4)
	
	exit_button.add_theme_stylebox_override("normal", exit_style)
	exit_button.add_theme_stylebox_override("hover", exit_hover_style)
	exit_button.add_theme_stylebox_override("pressed", exit_hover_style)
	button_container.add_child(exit_button)
	
	# === МЕНЮ НАЛАШТУВАНЬ ===
	settings_container = VBoxContainer.new()
	settings_container.position = Vector2(0, 220)
	settings_container.size = Vector2(get_viewport_rect().size.x, 0)
	settings_container.alignment = BoxContainer.ALIGNMENT_CENTER
	settings_container.add_theme_constant_override("separation", 10)
	settings_container.hide()
	center_container.add_child(settings_container)
	
	settings_title = Label.new()
	settings_title.text = "НАЛАШТУВАННЯ"
	settings_title.add_theme_font_size_override("font_size", 60)
	settings_title.add_theme_color_override("font_color", Color(0.8, 0.3, 1.0))
	settings_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	settings_title.add_theme_constant_override("outline_size", 4)
	settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if impact_font: settings_title.add_theme_font_override("font", impact_font)
	settings_container.add_child(settings_title)
	
	_add_slider(settings_container, "ЗАГАЛЬНА ГУЧНІСТЬ", "Master")
	_add_slider(settings_container, "МУЗИКА", "Music")
	_add_slider(settings_container, "ЗВУКИ ГРИ (SFX)", "SFX")
	_add_slider(settings_container, "ІНТЕРФЕЙС (UI)", "UI")
	
	var spacer_set = Control.new()
	spacer_set.custom_minimum_size = Vector2(0, 15)
	settings_container.add_child(spacer_set)
	
	var back_btn = Button.new()
	back_btn.text = "◀  НАЗАД"
	back_btn.add_theme_font_size_override("font_size", 28)
	back_btn.custom_minimum_size = Vector2(300, 60)
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if impact_font: back_btn.add_theme_font_override("font", impact_font)
	back_btn.add_theme_stylebox_override("normal", purple_style)
	back_btn.add_theme_stylebox_override("hover", purple_hover_style)
	back_btn.add_theme_stylebox_override("pressed", purple_hover_style)
	back_btn.pressed.connect(_on_settings_back_pressed)
	back_btn.mouse_entered.connect(func(): _play_ui_sound("ui_hover"))
	settings_container.add_child(back_btn)

	var version_label = Label.new()
	version_label.text = "v0.0.1  |  Демо-версія"
	version_label.add_theme_font_size_override("font_size", 18)
	version_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	version_label.position = Vector2(-300, -50)
	version_label.custom_minimum_size = Vector2(600, 30)
	add_child(version_label)

func _add_slider(parent: Control, title: String, bus_name: String) -> void:
	var lbl = Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if impact_font: lbl.add_theme_font_override("font", impact_font)
	parent.add_child(lbl)
	
	var slider = HSlider.new()
	slider.custom_minimum_size = Vector2(400, 25)
	slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slider.min_value = -40.0
	slider.max_value = 0.0 # 🔥 Тепер повзунок буде виглядати повним на дефолтній гучності
	
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		slider.value = AudioServer.get_bus_volume_db(bus_idx)
		slider.value_changed.connect(func(val):
			if val <= -40.0:
				AudioServer.set_bus_mute(bus_idx, true)
			else:
				AudioServer.set_bus_mute(bus_idx, false)
				AudioServer.set_bus_volume_db(bus_idx, val)
		)
	parent.add_child(slider)

func _animate_title() -> void:
	var offset = sin(time_elapsed * 2.0) * 5.0
	if title_label:
		title_label.position.y = offset
	if settings_title:
		settings_title.position.y = offset

func _create_stars() -> void:
	var viewport_size = get_viewport_rect().size
	for i in range(50):
		var star = ColorRect.new()
		var size = randf_range(2, 5)
		star.custom_minimum_size = Vector2(size, size)
		star.size = Vector2(size, size)
		star.position = Vector2(
			randf_range(0, viewport_size.x),
			randf_range(0, viewport_size.y)
		)
		star.color = Color(1, 1, 1, randf_range(0.2, 0.8))
		add_child(star)

func _remove_all_hud() -> void:
	for child in get_tree().root.get_children():
		if child is CanvasLayer and (child.name == "PlayerHUD" or child.name == "DeathMenuUI"):
			child.queue_free()

func _on_start_pressed() -> void:
	_play_ui_sound("ui_click") 
	_remove_all_hud()
	get_tree().change_scene_to_file("res://tscn/character_select.tscn")

func _on_settings_pressed() -> void:
	_play_ui_sound("ui_click") 
	main_container.hide()
	settings_container.show()

func _on_settings_back_pressed() -> void:
	_play_ui_sound("ui_click")
	_save_audio_settings() # 🔥 Зберігаємо у файл при виході з налаштувань
	settings_container.hide()
	main_container.show()

func _on_exit_pressed() -> void:
	_play_ui_sound("ui_click") 
	get_tree().create_timer(0.15).timeout.connect(func(): get_tree().quit())
