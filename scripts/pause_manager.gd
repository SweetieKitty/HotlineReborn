extends CanvasLayer

var bg_rect: ColorRect
var center_container: CenterContainer
var vbox: VBoxContainer
var settings_container: VBoxContainer
var impact_font: Font

var config_path = "user://audio_settings.cfg"
var config = ConfigFile.new()
var sliders: Dictionary = {}

func _ready() -> void:
	layer = 120 
	process_mode = Node.PROCESS_MODE_ALWAYS 
	
	impact_font = load("res://fonts/Impact.ttf")
	
	var blur_shader = Shader.new()
	blur_shader.code = """
	shader_type canvas_item;
	uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
	uniform float blur : hint_range(0.0, 10.0) = 2.5;

	void fragment() {
		vec4 color = textureLod(screen_tex, SCREEN_UV, blur);
		COLOR = color * vec4(0.4, 0.4, 0.4, 1.0); 
	}
	"""
	
	var mat = ShaderMaterial.new()
	mat.shader = blur_shader
	
	bg_rect = ColorRect.new()
	bg_rect.material = mat
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg_rect)
	
	center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center_container)
	
	# === ГОЛОВНЕ МЕНЮ ПАУЗИ ===
	vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 25)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_container.add_child(vbox)
	
	var title = Label.new()
	title.text = "ПАУЗА"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("outline_size", 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if impact_font: title.add_theme_font_override("font", impact_font)
	vbox.add_child(title)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)
	
	var resume_btn = _create_custom_btn("Продовжити", impact_font, Color(0.2, 0.9, 0.3))
	resume_btn.pressed.connect(_resume)
	vbox.add_child(resume_btn)
	
	var settings_btn = _create_custom_btn("Налаштування", impact_font, Color(1.0, 0.85, 0.2))
	settings_btn.pressed.connect(_settings)
	vbox.add_child(settings_btn)
	
	var menu_btn = _create_custom_btn("Головне меню", impact_font, Color(0.9, 0.2, 0.2))
	menu_btn.pressed.connect(_main_menu)
	vbox.add_child(menu_btn)
	
	# === МЕНЮ НАЛАШТУВАНЬ ===
	settings_container = VBoxContainer.new()
	settings_container.add_theme_constant_override("separation", 15)
	settings_container.alignment = BoxContainer.ALIGNMENT_CENTER
	settings_container.hide()
	center_container.add_child(settings_container)
	
	var settings_title = Label.new()
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
	
	var back_btn = _create_custom_btn("◀ НАЗАД", impact_font, Color(1.0, 0.85, 0.2))
	back_btn.pressed.connect(_on_settings_back_pressed)
	settings_container.add_child(back_btn)
	
	bg_rect.hide()
	center_container.hide()

func _create_custom_btn(txt: String, font: Font, glow_color: Color) -> Button:
	var b = Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(350, 70)
	b.add_theme_font_size_override("font_size", 28)
	if font: b.add_theme_font_override("font", font)
	
	var corner_radius = 16
	
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	style_normal.border_width_left = 2
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = Color(0.3, 0.3, 0.35, 0.8)
	style_normal.corner_radius_top_left = corner_radius
	style_normal.corner_radius_top_right = corner_radius
	style_normal.corner_radius_bottom_left = corner_radius
	style_normal.corner_radius_bottom_right = corner_radius
	
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color(0.12, 0.12, 0.18, 1.0)
	style_hover.border_color = glow_color 
	style_hover.shadow_color = Color(glow_color.r, glow_color.g, glow_color.b, 0.4) 
	style_hover.shadow_size = 15
	
	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = Color(0.05, 0.05, 0.08, 1.0)
	style_pressed.border_color = Color(glow_color.r * 0.8, glow_color.g * 0.8, glow_color.b * 1.0, 1.0)
	style_pressed.shadow_color = Color(glow_color.r, glow_color.g, glow_color.b, 0.2)
	style_pressed.shadow_size = 5
	
	b.add_theme_stylebox_override("normal", style_normal)
	b.add_theme_stylebox_override("hover", style_hover)
	b.add_theme_stylebox_override("pressed", style_pressed)
	b.add_theme_stylebox_override("focus", style_hover) 
	
	b.mouse_entered.connect(func(): _play_ui_sound("ui_hover"))
	
	return b

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
	slider.max_value = 0.0
	
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
	sliders[bus_name] = slider

func _save_audio_settings() -> void:
	for bus_name in ["Master", "Music", "SFX", "UI"]:
		var bus_idx = AudioServer.get_bus_index(bus_name)
		if bus_idx != -1:
			config.set_value("Audio", bus_name, AudioServer.get_bus_volume_db(bus_idx))
	config.save(config_path)

func _play_ui_sound(sound_name: String) -> void:
	var p = AudioStreamPlayer.new()
	var paths = ["res://assets/sounds/" + sound_name + ".mp3", "res://assets/sounds/" + sound_name + ".wav", "res://assets/sounds/" + sound_name + ".ogg"]
	for path in paths:
		if ResourceLoader.exists(path):
			p.stream = load(path)
			break
	if p.stream:
		p.bus = "UI"
		if sound_name == "ui_click":
			p.volume_db = -18.0
		elif sound_name == "ui_hover":
			p.volume_db = -15.0
		else:
			p.volume_db = -15.0
			
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.add_child(p)
		p.play()
		p.finished.connect(func(): p.queue_free())

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var curr_scene = get_tree().current_scene
		if curr_scene:
			var sn = curr_scene.name.to_lower()
			if sn.contains("menu") or sn.contains("select"):
				return
				
		if get_tree().root.get_node_or_null("DeathMenuUI"): return
		if get_tree().root.get_node_or_null("DemoEndUI"): return
		
		if get_tree().paused:
			_resume()
		else:
			_pause()

func _pause() -> void:
	get_tree().paused = true
	
	# 🔥 Оновлюємо візуальні слайдери актуальними даними з AudioServer
	for bus_name in sliders:
		var bus_idx = AudioServer.get_bus_index(bus_name)
		if bus_idx != -1:
			sliders[bus_name].set_value_no_signal(AudioServer.get_bus_volume_db(bus_idx))
			
	settings_container.hide()
	vbox.show()
	bg_rect.show()
	center_container.show()

func _resume() -> void:
	_play_ui_sound("ui_click")
	_save_audio_settings()
	get_tree().paused = false
	bg_rect.hide()
	center_container.hide()
	settings_container.hide()
	vbox.show()

func _settings() -> void:
	_play_ui_sound("ui_click")
	vbox.hide()
	settings_container.show()

func _on_settings_back_pressed() -> void:
	_play_ui_sound("ui_click")
	_save_audio_settings()
	settings_container.hide()
	vbox.show()

func _main_menu() -> void:
	_play_ui_sound("ui_click")
	_save_audio_settings()
	get_tree().paused = false
	bg_rect.hide()
	center_container.hide()
	var hud = get_tree().root.get_node_or_null("PlayerHUD")
	if hud: hud.queue_free()
	get_tree().change_scene_to_file("res://tscn/mainmenu.tscn")
