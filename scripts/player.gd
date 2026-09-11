extends CharacterBody2D

# === ЗДОРОВ'Я ===
signal health_changed(new_health: int, max_health: int)

@export var max_health: int = 100
var health: int = 100:
	set(value):
		health = clamp(value, 0, max_health)
		health_changed.emit(health, max_health)

var player_alive: bool = true
var death_menu_shown: bool = false

# === РУХ ===
@export var speed: float = 400.0
@export var rotation_speed: float = 50.0

# === ДЕШ ===
@export var dash_speed: float = 1000.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 1.5

var is_dashing: bool = false
var can_dash: bool = true
var dash_timer: float = 0.0
var cooldown_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO

# === ОСНОВНА ЗБРОЯ (ЛКМ) ===
@export var fire_rate: float = 0.5
@export var bullet_scene: PackedScene
var can_shoot: bool = true
var base_damage: int = 30

# === ДОДАТКОВА ЗБРОЯ (ПКМ) ===
enum WeaponType {
	SHOTGUN,
	AUTO_RIFLE,
	ROCKET,
	MINIGUN
}

var has_secondary: bool = false
var secondary_weapon: int = -1
var secondary_ammo: int = 0
var secondary_damage: int = 0
var secondary_fire_rate: float = 0.5
var can_shoot_secondary: bool = true

const WEAPON_ICONS = {
	0: "res://assets/weapon_SHOTGUN.png",
	1: "res://assets/weapon_AK.png",
	2: "res://assets/weapon_RPG.png",
	3: "res://assets/weapon_MINIGUN.png"
}

@onready var gun_point: Node2D = $GunPoint

# === HUD ===
var hud_canvas: CanvasLayer
var health_bar: ColorRect
var health_bar_bg: ColorRect
var health_label: Label
var ammo_label: Label = null
var weapon_label: Label = null
var weapon_icon: TextureRect = null
var dash_cooldown_label: Label = null
var dash_progress: TextureProgressBar = null
var main_panel: Panel = null

@export var heal_per_room: int = 20

# 🔥 IMPACT ШРИФТ
var impact_font: Font = null

# === ЗВУКИ ===
var audio_players: Dictionary = {}
var step_timer: float = 0.0


func _ready() -> void:
	has_secondary = false
	secondary_weapon = -1
	secondary_ammo = 0
	secondary_damage = 0
	
	impact_font = load("res://fonts/Impact.ttf")
	if impact_font == null:
		print("⚠️ Шрифт Impact.ttf не знайдено!")
	
	add_to_group("player")
	health = max_health
	print("🟢 Гравець створений. HP: ", health, "/", max_health)
	
	_setup_audio()
	_remove_existing_hud()
	_create_beautiful_hud()
	_update_weapon_hud()


func _setup_audio() -> void:
	var sounds = {
		"music": "res://assets/sounds/music",
		"walk": "res://assets/sounds/walk",
		"shoot_main": "res://assets/sounds/shoot_main",
		"shotgun": "res://assets/sounds/shotgun",
		"ak": "res://assets/sounds/ak",
		"rpg": "res://assets/sounds/rpg",
		"minigun": "res://assets/sounds/minigun",
		"dash": "res://assets/sounds/dash",
		"hit": "res://assets/sounds/hit",
		"death": "res://assets/sounds/death"
	}
	
	var custom_volumes = {
		"music": -20.0,
		"walk": -20.0,
		"shoot_main": -20.0,
		"shotgun": -20.0,
		"ak": -18.0,
		"rpg": -18.0,
		"minigun": -15.0,
		"dash": -15.0,
		"hit": -25.0,
		"death": -15.0
	}
	
	for key in sounds:
		var p = AudioStreamPlayer.new()
		var base_path = sounds[key]
		var final_stream = null
		
		for ext in [".mp3", ".wav", ".ogg"]:
			if ResourceLoader.exists(base_path + ext):
				final_stream = load(base_path + ext)
				break
		
		if final_stream:
			p.stream = final_stream
			
			if key == "music":
				p.bus = "Music"
			else:
				p.bus = "SFX"
				
			if custom_volumes.has(key):
				p.volume_db = custom_volumes[key] 
			add_child(p)
			audio_players[key] = p
		else:
			print("⚠️ Звук не знайдено: ", base_path)
			audio_players[key] = p 
	
	if audio_players.has("music") and audio_players["music"].stream:
		audio_players["music"].play()
		audio_players["music"].finished.connect(func(): audio_players["music"].play())


func play_sound(s_name: String) -> void:
	if audio_players.has(s_name) and audio_players[s_name].stream:
		audio_players[s_name].play()

func play_hit_sound() -> void:
	play_sound("hit")

func play_kill_sound() -> void:
	play_sound("death")


func shoot() -> void:
	shoot_primary()


func _physics_process(delta: float) -> void:
	if not player_alive:
		show_death_menu()
		return
	
	_handle_dash(delta)
	
	if is_dashing:
		velocity = dash_direction * dash_speed
		move_and_slide()
		_update_dash_hud()
		return
	
	smooth_rotate_to_mouse(delta)
	
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * speed
	move_and_slide()
	
	if velocity.length() > 0:
		step_timer -= delta
		if step_timer <= 0:
			play_sound("walk")
			step_timer = 0.35
	else:
		step_timer = 0.0
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and can_shoot:
		shoot_primary()
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and can_shoot_secondary:
		shoot_secondary()
	
	_update_dash_hud()


func smooth_rotate_to_mouse(delta: float) -> void:
	var target_angle = global_position.angle_to_point(get_global_mouse_position())
	rotation = lerp_angle(rotation, target_angle, rotation_speed * delta)


func _get_weapon_icon(weapon_type: int) -> Texture2D:
	var path = WEAPON_ICONS.get(weapon_type, "")
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	return null


func _remove_existing_hud() -> void:
	var old_hud = get_tree().root.get_node_or_null("PlayerHUD")
	if old_hud and is_instance_valid(old_hud):
		old_hud.queue_free()
	
	if hud_canvas and is_instance_valid(hud_canvas):
		hud_canvas.queue_free()
		hud_canvas = null
	
	for child in get_tree().root.get_children():
		if child is CanvasLayer and child.name == "PlayerHUD":
			child.queue_free()
	
	var death_menu = get_tree().root.get_node_or_null("DeathMenuUI")
	if death_menu and is_instance_valid(death_menu):
		death_menu.queue_free()


func _create_border_texture(size: int, thickness: int, color: Color) -> Texture2D:
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0)) 
	for x in range(size):
		for y in range(size):
			if x < thickness or x >= size - thickness or y < thickness or y >= size - thickness:
				img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


func _create_beautiful_hud() -> void:
	hud_canvas = CanvasLayer.new()
	hud_canvas.name = "PlayerHUD"
	hud_canvas.layer = 50
	get_tree().root.add_child(hud_canvas)
	
	main_panel = Panel.new()
	main_panel.position = Vector2(15, 15)
	main_panel.custom_minimum_size = Vector2(360, 220) 
	main_panel.add_theme_stylebox_override("panel", _create_hud_stylebox())
	hud_canvas.add_child(main_panel)
	
	var inner_container = MarginContainer.new()
	inner_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner_container.add_theme_constant_override("margin_left", 14)
	inner_container.add_theme_constant_override("margin_right", 14)
	inner_container.add_theme_constant_override("margin_top", 12)
	inner_container.add_theme_constant_override("margin_bottom", 12)
	main_panel.add_child(inner_container)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	inner_container.add_child(vbox)
	
	var hp_row = HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 10)
	vbox.add_child(hp_row)
	
	var heart_icon = Label.new()
	heart_icon.text = "❤️"
	heart_icon.add_theme_font_size_override("font_size", 28)
	heart_icon.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	hp_row.add_child(heart_icon)
	
	var hp_bar_container = Control.new()
	hp_bar_container.custom_minimum_size = Vector2(230, 26)
	hp_row.add_child(hp_bar_container)
	
	health_bar_bg = ColorRect.new()
	health_bar_bg.color = Color(0.08, 0.08, 0.12)
	health_bar_bg.position = Vector2.ZERO
	health_bar_bg.size = Vector2(230, 26)
	hp_bar_container.add_child(health_bar_bg)
	
	health_bar = ColorRect.new()
	health_bar.color = Color(0.2, 0.9, 0.3)
	health_bar.position = Vector2.ZERO
	health_bar.size = Vector2(230, 26)
	hp_bar_container.add_child(health_bar)
	
	health_label = Label.new()
	health_label.text = "100/100"
	health_label.add_theme_font_size_override("font_size", 16)
	health_label.add_theme_color_override("font_color", Color(1, 1, 1))
	health_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	health_label.add_theme_constant_override("outline_size", 2)
	health_label.position = Vector2(75, 3)
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.custom_minimum_size = Vector2(80, 20)
	if impact_font != null:
		health_label.add_theme_font_override("font", impact_font)
	hp_bar_container.add_child(health_label)
	
	health_changed.connect(_update_health_bar)
	_update_health_bar(health, max_health)
	
	var weapon_row = HBoxContainer.new()
	weapon_row.add_theme_constant_override("separation", 12)
	vbox.add_child(weapon_row)
	
	var icon_frame = Panel.new()
	icon_frame.custom_minimum_size = Vector2(72, 72)
	icon_frame.add_theme_stylebox_override("panel", _create_icon_frame_stylebox())
	icon_frame.clip_contents = true
	weapon_row.add_child(icon_frame)
	
	weapon_icon = TextureRect.new()
	weapon_icon.position = Vector2(4, 4)
	weapon_icon.custom_minimum_size = Vector2(64, 64)
	weapon_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	weapon_icon.pivot_offset = Vector2(32, 32)
	weapon_icon.scale = Vector2(1.9, 1.9)
	weapon_icon.texture = null
	icon_frame.add_child(weapon_icon)
	
	var weapon_info = VBoxContainer.new()
	weapon_info.alignment = BoxContainer.ALIGNMENT_CENTER
	weapon_info.add_theme_constant_override("separation", 0)
	weapon_row.add_child(weapon_info)
	
	weapon_label = Label.new()
	weapon_label.text = "ПКМ: Немає зброї"
	weapon_label.add_theme_font_size_override("font_size", 17)
	weapon_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	weapon_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	weapon_label.add_theme_constant_override("outline_size", 2)
	if impact_font != null:
		weapon_label.add_theme_font_override("font", impact_font)
	weapon_info.add_child(weapon_label)
	
	ammo_label = Label.new()
	ammo_label.text = ""
	ammo_label.add_theme_font_size_override("font_size", 15)
	ammo_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	ammo_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	ammo_label.add_theme_constant_override("outline_size", 2)
	if impact_font != null:
		ammo_label.add_theme_font_override("font", impact_font)
	weapon_info.add_child(ammo_label)
	
	var dash_row = HBoxContainer.new()
	dash_row.add_theme_constant_override("separation", 12)
	vbox.add_child(dash_row)
	
	var dash_icon_frame = Panel.new()
	dash_icon_frame.custom_minimum_size = Vector2(72, 72)
	dash_icon_frame.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	
	var mask_style = StyleBoxFlat.new()
	mask_style.bg_color = Color(1, 1, 1, 1) 
	mask_style.corner_radius_top_left = 8
	mask_style.corner_radius_top_right = 8
	mask_style.corner_radius_bottom_left = 8
	mask_style.corner_radius_bottom_right = 8
	dash_icon_frame.add_theme_stylebox_override("panel", mask_style)
	dash_row.add_child(dash_icon_frame)
	
	var dash_bg = ColorRect.new()
	dash_bg.color = Color(0.08, 0.06, 0.12, 0.85)
	dash_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dash_icon_frame.add_child(dash_bg)
	
	var dash_image = TextureRect.new()
	dash_image.custom_minimum_size = Vector2(64, 64)
	dash_image.position = Vector2(4, 4)
	dash_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dash_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var tex = load("res://assets/dash.jpg")
	if tex:
		dash_image.texture = tex
	else:
		var fb = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		fb.fill(Color(0.2, 0.2, 0.25))
		dash_image.texture = ImageTexture.create_from_image(fb)
	dash_icon_frame.add_child(dash_image)
	
	dash_progress = TextureProgressBar.new()
	dash_progress.custom_minimum_size = Vector2(72, 72)
	dash_progress.fill_mode = TextureProgressBar.FILL_COUNTER_CLOCKWISE
	dash_progress.texture_under = _create_border_texture(72, 3, Color(0.1, 0.1, 0.15, 0.8)) 
	dash_progress.texture_progress = _create_border_texture(72, 3, Color(0.2, 0.9, 0.3))
	dash_progress.min_value = 0
	dash_progress.max_value = 100
	dash_progress.value = 100
	dash_progress.step = 0.1
	dash_icon_frame.add_child(dash_progress)
	
	var dash_info = VBoxContainer.new()
	dash_info.alignment = BoxContainer.ALIGNMENT_CENTER
	dash_row.add_child(dash_info)
	
	dash_cooldown_label = Label.new()
	dash_cooldown_label.text = "Деш готовий"
	dash_cooldown_label.add_theme_font_size_override("font_size", 16)
	dash_cooldown_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	dash_cooldown_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	dash_cooldown_label.add_theme_constant_override("outline_size", 2)
	if impact_font != null:
		dash_cooldown_label.add_theme_font_override("font", impact_font)
	dash_info.add_child(dash_cooldown_label)
	
	_add_corner_decorations(main_panel)


func _create_hud_stylebox() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.75)
	style.border_color = Color(0.4, 0.3, 0.6, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_size = 8
	style.shadow_color = Color(0.3, 0.2, 0.5, 0.3)
	style.shadow_offset = Vector2(0, 4)
	return style


func _create_icon_frame_stylebox() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.12, 0.85)
	style.border_color = Color(0.5, 0.4, 0.7, 0.6)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


func _add_corner_decorations(panel: Panel) -> void:
	var colors = [Color(0.6, 0.4, 0.8, 0.6), Color(0.4, 0.6, 0.9, 0.6)]
	for i in range(4):
		var corner = ColorRect.new()
		corner.color = colors[i % 2]
		corner.custom_minimum_size = Vector2(8, 8)
		
		match i:
			0: corner.position = Vector2(4, 4)
			1: corner.position = Vector2(panel.custom_minimum_size.x - 12, 4)
			2: corner.position = Vector2(4, panel.custom_minimum_size.y - 12)
			3: corner.position = Vector2(panel.custom_minimum_size.x - 12, panel.custom_minimum_size.y - 12)
		
		panel.add_child(corner)


func _update_health_bar(current: int, maximum: int) -> void:
	if not health_bar or not health_label:
		return
	
	var ratio = float(current) / float(maximum)
	var bar_width = 230.0 * ratio
	
	health_bar.size.x = bar_width
	health_label.text = str(current) + "/" + str(maximum)
	
	if ratio > 0.6:
		health_bar.color = Color(0.2, 0.9, 0.3)
	elif ratio > 0.3:
		health_bar.color = Color(1.0, 0.7, 0.1)
	else:
		health_bar.color = Color(1.0, 0.15, 0.15)
	
	if ratio <= 0.25 and ratio > 0:
		_pulse_health_bar()


func _pulse_health_bar() -> void:
	if not health_bar:
		return
	var tween = create_tween()
	tween.tween_property(health_bar, "color:a", 0.5, 0.3)
	tween.tween_property(health_bar, "color:a", 1.0, 0.3)


func _update_weapon_hud() -> void:
	if not weapon_label or not ammo_label or not weapon_icon:
		return
	
	if not has_secondary:
		weapon_label.text = "ПКМ: Немає зброї"
		weapon_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		ammo_label.text = ""
		weapon_icon.texture = null
		return
	
	var weapon_data = {
		0: {"name": "Дробовик", "color": Color(1.0, 0.5, 0.1)},
		1: {"name": "Автомат", "color": Color(0.2, 0.6, 1.0)},
		2: {"name": "РПГ", "color": Color(1.0, 0.2, 0.2)},
		3: {"name": "Кулемет", "color": Color(0.2, 1.0, 0.3)}
	}
	
	var data = weapon_data.get(secondary_weapon, {"name": "Зброя", "color": Color(1, 1, 1)})
	
	weapon_label.text = "ПКМ: " + data["name"]
	weapon_label.add_theme_color_override("font_color", data["color"])
	ammo_label.text = "Боєзапас: " + str(secondary_ammo)
	
	var icon = _get_weapon_icon(secondary_weapon)
	if icon:
		var rotated = _rotate_texture(icon, -45)
		var img = rotated.get_image()
		img.resize(64, 64, Image.INTERPOLATE_LANCZOS)
		weapon_icon.texture = ImageTexture.create_from_image(img)
	else:
		var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(data["color"])
		for x in range(64):
			for y in range(64):
				if x < 2 or x > 61 or y < 2 or y > 61:
					img.set_pixel(x, y, Color(0.05, 0.05, 0.08, 0.9))
		weapon_icon.texture = ImageTexture.create_from_image(img)


func _rotate_texture(texture: Texture2D, angle_deg: float) -> Texture2D:
	var image = texture.get_image()
	var width = image.get_width()
	var height = image.get_height()
	
	var new_size = int(sqrt(width*width + height*height)) + 4
	var rotated = Image.create(new_size, new_size, false, Image.FORMAT_RGBA8)
	rotated.fill(Color(0, 0, 0, 0))
	
	var angle_rad = deg_to_rad(angle_deg)
	var center = Vector2(new_size / 2.0, new_size / 2.0)
	var img_center = Vector2(width / 2.0, height / 2.0)
	
	for x in range(width):
		for y in range(height):
			var color = image.get_pixel(x, y)
			if color.a > 0.01:
				var local = Vector2(x, y) - img_center
				var rotated_local = Vector2(
					local.x * cos(angle_rad) - local.y * sin(angle_rad),
					local.x * sin(angle_rad) + local.y * cos(angle_rad)
				)
				var new_pos = center + rotated_local
				var new_x = int(new_pos.x)
				var new_y = int(new_pos.y)
				
				if new_x >= 0 and new_x < new_size and new_y >= 0 and new_y < new_size:
					rotated.set_pixel(new_x, new_y, color)
	
	return ImageTexture.create_from_image(rotated)


func _update_dash_hud() -> void:
	if not dash_cooldown_label or not dash_progress:
		return
	
	if is_dashing:
		dash_progress.value = 0
		dash_cooldown_label.text = "Деш АКТИВОВАНО!"
		dash_cooldown_label.add_theme_color_override("font_color", Color(0.0, 1.0, 1.0))
		return
	
	if not can_dash:
		var ratio = 1.0 - (cooldown_timer / dash_cooldown)
		dash_progress.value = ratio * 100.0
		
		var formatted = str(ceil(cooldown_timer)) + "с"
		dash_cooldown_label.text = "Кулдаун: " + formatted
		dash_cooldown_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
		return
	
	dash_progress.value = 100.0
	dash_cooldown_label.text = "Деш готовий"
	dash_cooldown_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))


func _handle_dash(delta: float) -> void:
	if Input.is_action_just_pressed("dash") and can_dash and not is_dashing:
		_activate_dash()
	
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			_end_dash()
	
	if not can_dash and not is_dashing:
		cooldown_timer -= delta
		if cooldown_timer <= 0:
			can_dash = true


func _activate_dash() -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if input_dir == Vector2.ZERO:
		dash_direction = _get_facing_direction()
	else:
		dash_direction = input_dir.normalized()
	
	is_dashing = true
	can_dash = false
	dash_timer = dash_duration
	cooldown_timer = dash_cooldown
	
	_activate_dash_visuals()
	_trigger_camera_shake(5.0, 15.0)
	
	play_sound("dash")


func _end_dash() -> void:
	is_dashing = false
	_deactivate_dash_visuals()


func _get_facing_direction() -> Vector2:
	if velocity.length() > 0:
		return velocity.normalized()
	return Vector2.RIGHT.rotated(rotation)


func _activate_dash_visuals() -> void:
	modulate = Color(0.3, 0.6, 1.0, 1.0)


func _deactivate_dash_visuals() -> void:
	modulate = Color(1.0, 1.0, 1.0, 1.0)


func _trigger_camera_shake(strength: float, fade: float = 5.0) -> void:
	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("apply_shake"):
		camera.apply_shake(strength, fade)


func shoot_primary() -> void:
	if bullet_scene == null:
		return
	
	can_shoot = false
	
	var projectile = bullet_scene.instantiate()
	get_parent().add_child(projectile)
	projectile.global_position = gun_point.global_position
	projectile.rotation = rotation
	projectile.add_to_group("player_bullets")
	if "damage" in projectile:
		projectile.damage = base_damage
	
	_trigger_camera_shake(3.0, 12.0)
	play_sound("shoot_main")
	
	await get_tree().create_timer(fire_rate).timeout
	can_shoot = true


func shoot_secondary() -> void:
	if not has_secondary:
		return
	
	if secondary_ammo <= 0:
		print("🔫 Додаткова зброя: боєзапас вичерпано!")
		has_secondary = false
		secondary_weapon = -1
		_update_weapon_hud()
		return
	
	if bullet_scene == null:
		return
	
	can_shoot_secondary = false
	secondary_ammo -= 1
	
	match secondary_weapon:
		WeaponType.SHOTGUN:
			_shoot_shotgun()
			play_sound("shotgun") 
		WeaponType.AUTO_RIFLE:
			_shoot_auto()
			play_sound("ak") 
		WeaponType.ROCKET:
			_shoot_rocket()
			play_sound("rpg") 
		WeaponType.MINIGUN:
			_shoot_minigun()
			play_sound("minigun") 
	
	_update_weapon_hud()
	
	await get_tree().create_timer(secondary_fire_rate).timeout
	can_shoot_secondary = true


func _shoot_shotgun() -> void:
	var angles = [-0.4, -0.2, 0.0, 0.2, 0.4]
	for angle in angles:
		var projectile = bullet_scene.instantiate()
		get_parent().add_child(projectile)
		projectile.global_position = gun_point.global_position
		projectile.rotation = rotation + angle
		projectile.add_to_group("player_bullets")
		if "damage" in projectile:
			projectile.damage = secondary_damage
	_trigger_camera_shake(12.0, 6.0)


func _shoot_auto() -> void:
	var spread = randf_range(-0.05, 0.05)
	var projectile = bullet_scene.instantiate()
	get_parent().add_child(projectile)
	projectile.global_position = gun_point.global_position
	projectile.rotation = rotation + spread
	projectile.add_to_group("player_bullets")
	if "damage" in projectile:
		projectile.damage = secondary_damage
	_trigger_camera_shake(4.0, 10.0)


func _shoot_rocket() -> void:
	var projectile = bullet_scene.instantiate()
	get_parent().add_child(projectile)
	projectile.global_position = gun_point.global_position
	projectile.rotation = rotation
	projectile.add_to_group("player_bullets")
	if "damage" in projectile:
		projectile.damage = secondary_damage
	if "speed" in projectile:
		projectile.speed = 500.0
	projectile.scale = Vector2(2.0, 2.0)
	_trigger_camera_shake(25.0, 3.0)


func _shoot_minigun() -> void:
	var spread = randf_range(-0.15, 0.15)
	var projectile = bullet_scene.instantiate()
	get_parent().add_child(projectile)
	projectile.global_position = gun_point.global_position
	projectile.rotation = rotation + spread
	projectile.add_to_group("player_bullets")
	if "damage" in projectile:
		projectile.damage = secondary_damage
	_trigger_camera_shake(3.5, 20.0)


func pickup_weapon(weapon_type: int, ammo: int) -> void:
	has_secondary = true
	secondary_weapon = weapon_type
	secondary_ammo = ammo
	
	match weapon_type:
		WeaponType.SHOTGUN:
			secondary_damage = 15
			secondary_fire_rate = 0.8
		WeaponType.AUTO_RIFLE:
			secondary_damage = 20
			secondary_fire_rate = 0.15
		WeaponType.ROCKET:
			secondary_damage = 100
			secondary_fire_rate = 1.2
		WeaponType.MINIGUN:
			secondary_damage = 10
			secondary_fire_rate = 0.05
	
	print("🔫 Додаткова зброя підібрана! Тип: ", weapon_type, " | Боєзапас: ", secondary_ammo)
	_update_weapon_hud()


func take_damage(amount: int, sound_type: String = "hit") -> void:
	if not player_alive:
		return
	
	health -= amount
	print("💔 Гравець отримав шкоду: ", amount, " | HP: ", health, "/", max_health)
	_trigger_camera_shake(6.0, 8.0)
	
	play_sound(sound_type)
	
	if health <= 0:
		health = 0
		player_alive = false
		print("💀 Гравець помер!")
		play_sound("death")
		show_death_menu()


var death_menu_canvas: CanvasLayer = null


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
			p.volume_db = -18.0
		elif sound_name == "ui_hover":
			p.volume_db = -15.0
		else:
			p.volume_db = -15.0
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.add_child(p)
		p.play()
		p.finished.connect(func(): p.queue_free())


func _create_death_menu_btn(txt: String, font: Font, glow_color: Color) -> Button:
	var b = Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(300, 60)
	b.add_theme_font_size_override("font_size", 24)
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
	style_pressed.border_color = Color(glow_color.r * 0.8, glow_color.g * 0.8, glow_color.b * 0.8, 1.0)
	style_pressed.shadow_color = Color(glow_color.r, glow_color.g, glow_color.b, 0.2)
	style_pressed.shadow_size = 5

	b.add_theme_stylebox_override("normal", style_normal)
	b.add_theme_stylebox_override("hover", style_hover)
	b.add_theme_stylebox_override("pressed", style_pressed)
	b.add_theme_stylebox_override("focus", style_hover)

	b.mouse_entered.connect(func(): _play_ui_sound("ui_hover"))

	return b


func show_death_menu() -> void:
	if death_menu_shown:
		return
	death_menu_shown = true
	
	set_physics_process(false)
	set_process(false)
	
	_clear_hud()
	
	death_menu_canvas = CanvasLayer.new()
	death_menu_canvas.name = "DeathMenuUI"
	death_menu_canvas.layer = 100
	get_tree().root.add_child(death_menu_canvas)
	
	var background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.9)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_menu_canvas.add_child(background)
	
	var title_label = Label.new()
	title_label.text = "ВИ ЗАГИНУЛИ"
	title_label.add_theme_font_size_override("font_size", 80)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.15, 0.15))
	title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	title_label.add_theme_constant_override("outline_size", 4)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_label.position.y = -150
	if impact_font != null:
		title_label.add_theme_font_override("font", impact_font)
	death_menu_canvas.add_child(title_label)
	
	var subtitle_label = Label.new()
	subtitle_label.text = "Ваша подорож закінчилась..."
	subtitle_label.add_theme_font_size_override("font_size", 28)
	subtitle_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	subtitle_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	subtitle_label.add_theme_constant_override("outline_size", 2)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	subtitle_label.position.y = -50
	if impact_font != null:
		subtitle_label.add_theme_font_override("font", impact_font)
	death_menu_canvas.add_child(subtitle_label)
	
	var button_container = VBoxContainer.new()
	button_container.set_anchors_preset(Control.PRESET_CENTER)
	button_container.position = Vector2(-150, 15) 
	button_container.custom_minimum_size = Vector2(300, 0)
	button_container.add_theme_constant_override("separation", 20)
	death_menu_canvas.add_child(button_container)
	
	var retry_button = _create_death_menu_btn("Спробувати знову", impact_font, Color(0.2, 0.9, 0.3))
	retry_button.pressed.connect(func():
		_play_ui_sound("ui_click")
		_remove_death_menu()
		get_tree().reload_current_scene()
	)
	button_container.add_child(retry_button)
	
	var menu_button = _create_death_menu_btn("Головне меню", impact_font, Color(1.0, 0.85, 0.2))
	menu_button.pressed.connect(func():
		_play_ui_sound("ui_click")
		_remove_death_menu()
		_remove_all_hud()
		get_tree().change_scene_to_file("res://tscn/mainmenu.tscn")
	)
	button_container.add_child(menu_button)
	
	var exit_button = _create_death_menu_btn("Вийти з гри", impact_font, Color(0.9, 0.2, 0.2))
	exit_button.pressed.connect(func():
		_play_ui_sound("ui_click")
		get_tree().create_timer(0.15).timeout.connect(func(): get_tree().quit())
	)
	button_container.add_child(exit_button)


func _remove_death_menu() -> void:
	if death_menu_canvas and is_instance_valid(death_menu_canvas):
		death_menu_canvas.queue_free()
		death_menu_canvas = null
	death_menu_shown = false
	
	set_physics_process(true)
	set_process(true)
	
	_remove_existing_hud()
	_create_beautiful_hud()
	_update_weapon_hud()


func _remove_all_hud() -> void:
	var old_hud = get_tree().root.get_node_or_null("PlayerHUD")
	if old_hud and is_instance_valid(old_hud):
		old_hud.queue_free()
	
	if hud_canvas and is_instance_valid(hud_canvas):
		hud_canvas.queue_free()
		hud_canvas = null
	
	for child in get_tree().root.get_children():
		if child is CanvasLayer and child.name == "PlayerHUD":
			child.queue_free()
	
	var death_menu = get_tree().root.get_node_or_null("DeathMenuUI")
	if death_menu and is_instance_valid(death_menu):
		death_menu.queue_free()
	
	health_bar = null
	health_bar_bg = null
	health_label = null
	ammo_label = null
	weapon_label = null
	weapon_icon = null
	dash_cooldown_label = null
	dash_progress = null
	main_panel = null


func heal(amount: int) -> void:
	if not player_alive:
		return
	
	var old_health = health
	health += amount
	
	var actual_heal = health - old_health
	if actual_heal > 0:
		print("💚 Гравець зцілений на ", actual_heal, " HP! Тепер: ", health, "/", max_health)
		_show_heal_popup(actual_heal)


func _show_heal_popup(amount: int) -> void:
	if not hud_canvas:
		return
	
	var popup = Label.new()
	popup.text = "+" + str(amount) + " ❤️"
	popup.add_theme_font_size_override("font_size", 40)
	popup.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
	popup.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	popup.add_theme_constant_override("outline_size", 3)
	popup.position = Vector2(250, 25)
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if impact_font != null:
		popup.add_theme_font_override("font", impact_font)
	hud_canvas.add_child(popup)
	
	var tween = create_tween()
	tween.tween_property(popup, "position:y", -30, 1.0)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 1.0)
	tween.tween_callback(popup.queue_free)


func _clear_hud() -> void:
	if hud_canvas and is_instance_valid(hud_canvas):
		for child in hud_canvas.get_children():
			if is_instance_valid(child):
				child.queue_free()
		hud_canvas.queue_free()
		hud_canvas = null
		health_bar = null
		health_bar_bg = null
		health_label = null
		ammo_label = null
		weapon_label = null
		weapon_icon = null
		dash_cooldown_label = null
		dash_progress = null
		main_panel = null
	
	for child in get_tree().root.get_children():
		if child is CanvasLayer and child.name == "PlayerHUD":
			child.queue_free()
