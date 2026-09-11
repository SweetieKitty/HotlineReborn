extends Control

signal character_selected(character_id: int)

var characters = [
	{
		"id": 0,
		"name": "OSAMA",
		"unlocked": true,
		"color": Color(0.2, 0.9, 0.3),
		"description": "Основний персонаж",
		"icon": "res://assets/characters/osama.jpg"
	},
	{
		"id": 1,
		"name": "???",
		"unlocked": false,
		"color": Color(0.9, 0.2, 0.2),
		"description": "ЗАБЛОКОВАНО",
		"icon": "res://assets/characters/character_1.jpg"
	},
	{
		"id": 2,
		"name": "???",
		"unlocked": false,
		"color": Color(0.2, 0.3, 0.9),
		"description": "ЗАБЛОКОВАНО",
		"icon": "res://assets/characters/character_2.jpg"
	},
	{
		"id": 3,
		"name": "???",
		"unlocked": false,
		"color": Color(0.9, 0.7, 0.1),
		"description": "ЗАБЛОКОВАНО",
		"icon": "res://assets/characters/character_3.jpg"
	}
]

var selected_index: int = -1
var hovered_index: int = -1
var is_animating: bool = false

@onready var grid: GridContainer = $MainContainer/VBox/GridContainer
@onready var start_button: Button = $MainContainer/VBox/HBoxContainer/StartButton
@onready var back_button: Button = $MainContainer/VBox/HBoxContainer/BackButton

var impact_font: Font = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	impact_font = load("res://fonts/Impact.ttf")
	if impact_font == null:
		print("⚠️ Шрифт Impact.ttf не знайдено!")
	
	for child in get_children():
		if child is ColorRect:
			child.queue_free()
	
	var background = ColorRect.new()
	background.name = "Background"
	background.color = Color(0.03, 0.02, 0.06)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.z_index = -100
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	
	_create_stars()
	
	var vbox = $MainContainer/VBox
	for child in vbox.get_children():
		if child is Label:
			child.queue_free()
		if child is VBoxContainer and child != $MainContainer/VBox/GridContainer and child != $MainContainer/VBox/HBoxContainer:
			if child.name != "GridContainer" and child.name != "HBoxContainer":
				child.queue_free()
	
	var title_container = VBoxContainer.new()
	title_container.name = "TitleContainer"
	title_container.alignment = BoxContainer.ALIGNMENT_CENTER
	title_container.add_theme_constant_override("separation", 2)
	title_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	vbox.add_child(title_container)
	vbox.move_child(title_container, 0)
	
	var title_main = Label.new()
	title_main.name = "TitleMain"
	title_main.text = "HOTLINE REBORN"
	title_main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_main.add_theme_font_size_override("font_size", 56)
	title_main.add_theme_color_override("font_color", Color(1, 0.15, 0.15))
	title_main.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title_main.add_theme_constant_override("outline_size", 5)
	if impact_font != null:
		title_main.add_theme_font_override("font", impact_font)
	title_container.add_child(title_main)
	
	var title_sub = Label.new()
	title_sub.name = "TitleSub"
	title_sub.text = "ВИБІР ПЕРСОНАЖА"
	title_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_sub.add_theme_font_size_override("font_size", 30)
	title_sub.add_theme_color_override("font_color", Color(0.8, 0.7, 0.6))
	title_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	title_sub.add_theme_constant_override("outline_size", 2)
	if impact_font != null:
		title_sub.add_theme_font_override("font", impact_font)
	title_container.add_child(title_sub)
	
	var hbox = $MainContainer/VBox/HBoxContainer
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 60)
	
	if impact_font != null:
		back_button.add_theme_font_override("font", impact_font)
		start_button.add_theme_font_override("font", impact_font)
	
	_setup_buttons()
	
	back_button.pressed.connect(_on_back_button_pressed)
	start_button.pressed.connect(_on_start_button_pressed)
	
	_create_character_cards()
	_update_selection()


func _play_ui_sound(sound_name: String) -> void:
	var p = AudioStreamPlayer.new()
	var paths = ["res://assets/sounds/" + sound_name + ".mp3", "res://assets/sounds/" + sound_name + ".wav", "res://assets/sounds/" + sound_name + ".ogg"]
	for path in paths:
		if ResourceLoader.exists(path):
			p.stream = load(path)
			break
	if p.stream:
		p.bus = "UI" # 🔥 ПРОПИСАВ ШИНУ
		if sound_name == "ui_click":
			p.volume_db = -12.0
		elif sound_name == "ui_error":
			p.volume_db = -10.0
		elif sound_name == "ui_hover":
			p.volume_db = -22.0
		else:
			p.volume_db = -15.0
			
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.add_child(p)
		p.play()
		p.finished.connect(func(): p.queue_free())


func _setup_buttons() -> void:
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.08, 0.06, 0.15, 0.9)
	button_style.border_color = Color(0.3, 0.2, 0.5, 0.5)
	button_style.border_width_left = 2
	button_style.border_width_right = 2
	button_style.border_width_top = 2
	button_style.border_width_bottom = 2
	button_style.corner_radius_top_left = 16
	button_style.corner_radius_top_right = 16
	button_style.corner_radius_bottom_left = 16
	button_style.corner_radius_bottom_right = 16
	button_style.shadow_size = 6
	button_style.shadow_color = Color(0.2, 0.1, 0.3, 0.4)
	button_style.shadow_offset = Vector2(0, 3)
	
	var active_style = StyleBoxFlat.new()
	active_style.bg_color = Color(0.1, 0.06, 0.2, 0.95)
	active_style.border_color = Color(0.6, 0.3, 0.9, 0.8)
	active_style.border_width_left = 2
	active_style.border_width_right = 2
	active_style.border_width_top = 2
	active_style.border_width_bottom = 2
	active_style.corner_radius_top_left = 16
	active_style.corner_radius_top_right = 16
	active_style.corner_radius_bottom_left = 16
	active_style.corner_radius_bottom_right = 16
	active_style.shadow_size = 10
	active_style.shadow_color = Color(0.5, 0.2, 0.8, 0.6)
	active_style.shadow_offset = Vector2(0, 4)
	
	var disabled_style = StyleBoxFlat.new()
	disabled_style.bg_color = Color(0.05, 0.05, 0.08, 0.7)
	disabled_style.border_color = Color(0.2, 0.15, 0.3, 0.3)
	disabled_style.border_width_left = 2
	disabled_style.border_width_right = 2
	disabled_style.border_width_top = 2
	disabled_style.border_width_bottom = 2
	disabled_style.corner_radius_top_left = 16
	disabled_style.corner_radius_top_right = 16
	disabled_style.corner_radius_bottom_left = 16
	disabled_style.corner_radius_bottom_right = 16
	
	back_button.add_theme_stylebox_override("normal", button_style)
	back_button.add_theme_stylebox_override("hover", button_style)
	back_button.add_theme_stylebox_override("pressed", button_style)
	
	start_button.add_theme_stylebox_override("normal", disabled_style)
	start_button.add_theme_stylebox_override("disabled", disabled_style)
	
	start_button.set_meta("active_style", active_style)
	start_button.set_meta("disabled_style", disabled_style)
	
	back_button.mouse_entered.connect(func(): _play_ui_sound("ui_hover"))
	start_button.mouse_entered.connect(func(): if not start_button.disabled: _play_ui_sound("ui_hover"))


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
		star.z_index = -50
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(star)


func _create_character_cards() -> void:
	for child in grid.get_children():
		child.queue_free()
	
	for i in range(characters.size()):
		var card = _create_character_card(i)
		grid.add_child(card)


func _create_character_card(index: int) -> Control:
	var wrapper = Control.new()
	wrapper.custom_minimum_size = Vector2(680, 320)
	wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
	wrapper.mouse_entered.connect(_on_card_hovered.bind(index))
	wrapper.mouse_exited.connect(_on_card_exited.bind(index))
	wrapper.gui_input.connect(_on_card_clicked.bind(index))

	var shadow_panel = Panel.new()
	shadow_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	shadow_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow_style = StyleBoxFlat.new()
	shadow_style.bg_color = Color(0.05, 0.05, 0.08, 0.95)
	shadow_style.corner_radius_top_left = 16
	shadow_style.corner_radius_top_right = 16
	shadow_style.corner_radius_bottom_left = 16
	shadow_style.corner_radius_bottom_right = 16
	shadow_style.shadow_offset = Vector2(0, 4)
	shadow_panel.add_theme_stylebox_override("panel", shadow_style)
	wrapper.add_child(shadow_panel)
	wrapper.set_meta("shadow_style", shadow_style)

	var clip_panel = Panel.new()
	clip_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	clip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_panel.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	
	var clip_style = StyleBoxFlat.new()
	clip_style.bg_color = Color(1, 1, 1, 1) 
	clip_style.corner_radius_top_left = 16
	clip_style.corner_radius_top_right = 16
	clip_style.corner_radius_bottom_left = 16
	clip_style.corner_radius_bottom_right = 16
	clip_panel.add_theme_stylebox_override("panel", clip_style)
	wrapper.add_child(clip_panel)
	
	var data = characters[index]
	
	var avatar = TextureRect.new()
	avatar.set_anchors_preset(Control.PRESET_FULL_RECT)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	avatar.texture = _load_and_scale_icon(data.icon, 680, 320)
	avatar.pivot_offset = Vector2(340, 160)
	clip_panel.add_child(avatar)
	wrapper.set_meta("avatar", avatar) 
	
	var bottom_bg = ColorRect.new()
	bottom_bg.color = Color(0, 0, 0, 0.8)
	bottom_bg.custom_minimum_size = Vector2(0, 80)
	
	var bottom_aligner = VBoxContainer.new()
	bottom_aligner.set_anchors_preset(Control.PRESET_FULL_RECT)
	bottom_aligner.alignment = BoxContainer.ALIGNMENT_END
	clip_panel.add_child(bottom_aligner)
	bottom_aligner.add_child(bottom_bg)
	wrapper.set_meta("bottom_bar", bottom_bg)
	
	var bottom_vbox = VBoxContainer.new()
	bottom_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	bottom_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_vbox.add_theme_constant_override("separation", 2)
	bottom_bg.add_child(bottom_vbox)
	
	var name_label = Label.new()
	if data.unlocked:
		name_label.text = data.name
		name_label.add_theme_font_size_override("font_size", 38)
		name_label.add_theme_color_override("font_color", Color(1, 1, 1))
	else:
		name_label.text = "ЗАБЛОКОВАНО.\nУМОВА НЕВИКОНАНА"
		name_label.add_theme_font_size_override("font_size", 26)
		name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	
	if impact_font != null:
		name_label.add_theme_font_override("font", impact_font)
	
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	name_label.add_theme_constant_override("outline_size", 3)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	bottom_vbox.add_child(name_label)
	wrapper.set_meta("name_label", name_label)

	var overlay = Panel.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var overlay_style = StyleBoxFlat.new()
	overlay_style.bg_color = Color(0, 0, 0, 0) 
	overlay_style.border_width_left = 2
	overlay_style.border_width_right = 2
	overlay_style.border_width_top = 2
	overlay_style.border_width_bottom = 2
	overlay_style.corner_radius_top_left = 16
	overlay_style.corner_radius_top_right = 16
	overlay_style.corner_radius_bottom_left = 16
	overlay_style.corner_radius_bottom_right = 16
	overlay.add_theme_stylebox_override("panel", overlay_style)
	wrapper.add_child(overlay)
	wrapper.set_meta("overlay_style", overlay_style)

	return wrapper


func _load_and_scale_icon(path: String, target_width: int, target_height: int) -> Texture2D:
	if path == "":
		return _create_fallback_texture(Color(0.3, 0.3, 0.4), target_width, target_height)
	
	if not ResourceLoader.exists(path):
		return _create_fallback_texture(Color(0.3, 0.3, 0.4), target_width, target_height)
	
	var texture = load(path)
	if texture == null:
		return _create_fallback_texture(Color(0.3, 0.3, 0.4), target_width, target_height)
	
	var image = texture.get_image()
	if image == null:
		return _create_fallback_texture(Color(0.3, 0.3, 0.4), target_width, target_height)
	
	image.resize(target_width, target_height, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)


func _create_fallback_texture(color: Color, target_width: int, target_height: int) -> Texture2D:
	var img = Image.create(target_width, target_height, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


func _on_card_hovered(index: int) -> void:
	if hovered_index != index:
		_play_ui_sound("ui_hover") 
	hovered_index = index
	_update_selection()


func _on_card_exited(index: int) -> void:
	if hovered_index == index:
		hovered_index = -1
	_update_selection()


func _on_card_clicked(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if characters[index].unlocked:
			_play_ui_sound("ui_click") 
			if selected_index == index:
				selected_index = -1
			else:
				selected_index = index
			_update_selection()
		else:
			_play_ui_sound("ui_error") 
			var wrapper = grid.get_child(index)
			_shake_card(wrapper)


func _shake_card(card: Node) -> void:
	if is_animating:
		return
	is_animating = true
	
	var tween = create_tween()
	var original_pos = card.position
	
	for i in range(3):
		tween.tween_property(card, "position:x", original_pos.x + 10 * (-1 if i % 2 == 0 else 1), 0.05)
		tween.tween_property(card, "position:x", original_pos.x + 10 * (1 if i % 2 == 0 else -1), 0.05)
	
	tween.tween_property(card, "position:x", original_pos.x, 0.05)
	tween.tween_callback(func(): is_animating = false)


func _update_selection() -> void:
	var has_selection = selected_index >= 0 and characters[selected_index].unlocked
	
	for i in range(grid.get_child_count()):
		var wrapper = grid.get_child(i)
		var avatar = wrapper.get_meta("avatar")
		var bottom_bar = wrapper.get_meta("bottom_bar")
		var shadow_style = wrapper.get_meta("shadow_style")
		var overlay_style = wrapper.get_meta("overlay_style")
		var name_label = wrapper.get_meta("name_label")
		var data = characters[i]
		
		var target_avatar_scale = Vector2.ONE
		var target_bar_alpha = 1.0
		var target_name_alpha = 1.0
		
		var target_border_color: Color
		var target_shadow_color: Color
		var target_shadow_size: int
		
		if i == selected_index and data.unlocked:
			target_border_color = Color(0.8, 0.5, 1.0, 1.0)
			target_shadow_color = Color(0.7, 0.3, 1.0, 0.8)
			target_shadow_size = 22
			target_avatar_scale = Vector2(1.08, 1.08)
			target_bar_alpha = 0.0
			target_name_alpha = 0.0
		elif i == hovered_index and data.unlocked and selected_index == -1:
			target_border_color = Color(0.6, 0.3, 0.9, 0.9)
			target_shadow_color = Color(0.6, 0.2, 0.9, 0.8)
			target_shadow_size = 26
			target_avatar_scale = Vector2(1.08, 1.08)
			target_bar_alpha = 0.0
			target_name_alpha = 0.0
		elif i == hovered_index and not data.unlocked:
			target_border_color = Color(0.4, 0.2, 0.6, 0.6)
			target_shadow_color = Color(0.4, 0.1, 0.6, 0.5)
			target_shadow_size = 18
			target_avatar_scale = Vector2(1.06, 1.06)
			target_bar_alpha = 0.0
			target_name_alpha = 0.0
		else:
			if data.unlocked:
				target_border_color = Color(0.5, 0.2, 0.7, 0.6)
				target_shadow_color = Color(0.3, 0.1, 0.5, 0.4)
				target_shadow_size = 12
			else:
				target_border_color = Color(0.3, 0.15, 0.4, 0.5)
				target_shadow_color = Color(0.2, 0.05, 0.3, 0.3)
				target_shadow_size = 8
		
		var tween = create_tween().set_parallel(true)
		tween.tween_property(avatar, "scale", target_avatar_scale, 0.15).set_ease(Tween.EASE_OUT)
		tween.tween_property(bottom_bar, "modulate:a", target_bar_alpha, 0.15).set_ease(Tween.EASE_OUT)
		tween.tween_property(overlay_style, "border_color", target_border_color, 0.15).set_ease(Tween.EASE_OUT)
		tween.tween_property(shadow_style, "shadow_color", target_shadow_color, 0.15).set_ease(Tween.EASE_OUT)
		tween.tween_property(shadow_style, "shadow_size", target_shadow_size, 0.15).set_ease(Tween.EASE_OUT)
		tween.tween_property(name_label, "modulate:a", target_name_alpha, 0.15).set_ease(Tween.EASE_OUT)
	
	if has_selection:
		start_button.disabled = false
		start_button.text = "ГРАТИ"
		start_button.add_theme_color_override("font_color", Color(0.7, 0.3, 1.0))
		start_button.add_theme_font_size_override("font_size", 24)
		var active_style = start_button.get_meta("active_style")
		start_button.add_theme_stylebox_override("normal", active_style)
		start_button.add_theme_stylebox_override("hover", active_style)
		start_button.add_theme_stylebox_override("pressed", active_style)
	else:
		start_button.disabled = true
		start_button.text = "ОБЕРІТЬ\nПЕРСОНАЖА"
		start_button.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		start_button.add_theme_font_size_override("font_size", 18)
		var disabled_style = start_button.get_meta("disabled_style")
		start_button.add_theme_stylebox_override("normal", disabled_style)
		start_button.add_theme_stylebox_override("disabled", disabled_style)


func _on_back_button_pressed() -> void:
	_play_ui_sound("ui_click") 
	print("◀ НАЗАД натиснуто! Повернення в головне меню...")
	get_tree().change_scene_to_file("res://tscn/mainmenu.tscn")


func _on_start_button_pressed() -> void:
	_play_ui_sound("ui_click") 
	if selected_index >= 0 and characters[selected_index].unlocked:
		print("✅ Вибрано персонажа: ", characters[selected_index].name)
		get_tree().change_scene_to_file("res://tscn/mainworld.tscn")
	else:
		print("⚠️ Персонаж не вибраний!")
