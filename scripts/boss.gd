extends CharacterBody2D

# === ЗДОРОВ'Я ===
@export var max_health: int = 500
var health: int = 500
var boss_alive: bool = true
@export var boss_name: String = "БОС"

# === РУХ ===
@export var speed: float = 150.0
@export var dodge_speed: float = 350.0
@export var preferred_distance: float = 600.0
var player: Node2D = null

# === АТАКИ ===
@export var shoot_cooldown: float = 2.0
@export var bullet_scene: PackedScene
@export var contact_damage: int = 20
var can_shoot: bool = true
var shoot_timer: float = 0.0

# === УХИЛЕННЯ ===
@export var dodge_zone_radius: float = 250.0
@export var dodge_duration: float = 0.35
var dodge_direction: Vector2 = Vector2.ZERO
var dodge_timer: float = 0.0
var dodge_cooldown: float = 0.0
var strafe_direction: float = 1.0

# === КІМНАТА ===
var current_room: Node2D = null

# === ШКАЛА ЗДОРОВ'Я ===
var boss_hud_canvas: CanvasLayer = null
var boss_health_bar: ColorRect = null
var boss_health_label: Label = null

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
var tex_dead = preload("res://assets/boss1POMER.png")

# 🔥 IMPACT ШРИФТ
var impact_font: Font = null


func _ready() -> void:
	impact_font = load("res://fonts/Impact.ttf")
	if impact_font == null:
		print("⚠️ Шрифт Impact.ttf не знайдено!")
	
	add_to_group("enemies")
	add_to_group("boss")
	health = max_health
	print("👑 БОС створений! HP: ", health, "/", max_health)
	
	_create_hit_zone()
	_create_bullet_detector()
	_create_boss_health_bar()
	
	strafe_direction = 1.0 if randf() > 0.5 else -1.0


func _physics_process(delta: float) -> void:
	if not boss_alive:
		return
	
	if dodge_cooldown > 0:
		dodge_cooldown -= delta
	
	if not can_shoot:
		shoot_timer -= delta
		if shoot_timer <= 0:
			can_shoot = true
	
	if player == null or not is_instance_valid(player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
			print("👑 Бос знайшов гравця: ", player.name)
		return
	
	if dodge_timer > 0:
		dodge_timer -= delta
		velocity = dodge_direction * dodge_speed
		move_and_slide()
		rotation = global_position.angle_to_point(player.global_position)
		return
	
	_normal_movement(delta)
	rotation = global_position.angle_to_point(player.global_position)
	
	var dist = global_position.distance_to(player.global_position)
	if can_shoot and dist < 900:
		_shoot_at_player()


func _normal_movement(delta: float) -> void:
	var to_player = player.global_position - global_position
	var dist = to_player.length()
	var direction_to_player = to_player.normalized()
	
	var strafe_vector = Vector2(-direction_to_player.y, direction_to_player.x) * strafe_direction
	
	var move_direction = Vector2.ZERO
	
	if dist > preferred_distance + 150:
		move_direction += direction_to_player
	elif dist < preferred_distance - 150:
		move_direction -= direction_to_player
	
	move_direction += strafe_vector * 0.8
	
	if randf() < 0.003:
		strafe_direction *= -1.0
	
	velocity = move_direction.normalized() * speed
	move_and_slide()


func _shoot_at_player() -> void:
	if bullet_scene == null:
		printerr("❌ bullet_scene НЕ ВСТАНОВЛЕНО у боса!")
		return
	
	if not can_shoot:
		return
	
	can_shoot = false
	shoot_timer = shoot_cooldown
	
	var angles = [-0.3, 0.0, 0.3]
	var parent_node = get_parent()
	
	var gun_point = get_node_or_null("GunPoint")
	var spawn_pos = global_position
	
	if gun_point:
		spawn_pos = gun_point.global_position
	
	for angle in angles:
		var bullet = bullet_scene.instantiate()
		parent_node.add_child(bullet)
		bullet.global_position = spawn_pos
		bullet.rotation = rotation + angle
	
	print("👑 Бос стріляє!")
	_play_shoot_sound()


func _play_shoot_sound() -> void:
	var p = AudioStreamPlayer.new()
	var paths = ["res://assets/sounds/shotgun.mp3", "res://assets/sounds/shotgun.wav", "res://assets/sounds/shotgun.ogg"]
	for path in paths:
		if ResourceLoader.exists(path):
			p.stream = load(path)
			break
	if p.stream:
		p.bus = "SFX" # 🔥 ПРОПИСАВ ШИНУ
		p.volume_db = -12.0
		get_tree().root.add_child(p)
		p.play()
		p.finished.connect(func(): p.queue_free())


func _create_boss_health_bar() -> void:
	boss_hud_canvas = CanvasLayer.new()
	boss_hud_canvas.name = "BossHealthUI"
	boss_hud_canvas.layer = 60
	get_tree().root.add_child(boss_hud_canvas)
	
	var viewport_size = get_viewport_rect().size
	
	var name_label = Label.new()
	name_label.text = boss_name
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	name_label.add_theme_constant_override("outline_size", 2)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size = Vector2(400, 40)
	name_label.position = Vector2(viewport_size.x / 2.0 - 200, 30)
	if impact_font != null:
		name_label.add_theme_font_override("font", impact_font)
	boss_hud_canvas.add_child(name_label)
	
	var bar_bg = ColorRect.new()
	bar_bg.color = Color(0.1, 0.1, 0.1, 0.8)
	bar_bg.size = Vector2(500, 25)
	bar_bg.position = Vector2(viewport_size.x / 2.0 - 250, 70)
	boss_hud_canvas.add_child(bar_bg)
	
	boss_health_bar = ColorRect.new()
	boss_health_bar.color = Color(0.9, 0.15, 0.15)
	boss_health_bar.size = Vector2(500, 25)
	boss_health_bar.position = Vector2(viewport_size.x / 2.0 - 250, 70)
	boss_hud_canvas.add_child(boss_health_bar)
	
	var border = ReferenceRect.new()
	border.position = Vector2(viewport_size.x / 2.0 - 250, 70)
	border.size = Vector2(500, 25)
	border.border_color = Color(1, 1, 1, 0.8)
	border.border_width = 2.0
	border.editor_only = false
	boss_hud_canvas.add_child(border)
	
	boss_health_label = Label.new()
	boss_health_label.text = str(health) + " / " + str(max_health)
	boss_health_label.add_theme_font_size_override("font_size", 18)
	boss_health_label.add_theme_color_override("font_color", Color(1, 1, 1))
	boss_health_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	boss_health_label.add_theme_constant_override("outline_size", 2)
	boss_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_health_label.size = Vector2(500, 25)
	boss_health_label.position = Vector2(viewport_size.x / 2.0 - 250, 72)
	if impact_font != null:
		boss_health_label.add_theme_font_override("font", impact_font)
	boss_hud_canvas.add_child(boss_health_label)


func _update_boss_health_bar() -> void:
	if not boss_health_bar or not boss_health_label:
		return
	
	var ratio = float(health) / float(max_health)
	var bar_width = 500.0 * ratio
	
	boss_health_bar.size.x = bar_width
	boss_health_label.text = str(health) + " / " + str(max_health)
	
	if ratio > 0.6:
		boss_health_bar.color = Color(0.9, 0.15, 0.15)
	elif ratio > 0.3:
		boss_health_bar.color = Color(0.9, 0.5, 0.1)
	else:
		boss_health_bar.color = Color(0.9, 0.8, 0.1)


func _remove_boss_health_bar() -> void:
	if boss_hud_canvas and is_instance_valid(boss_hud_canvas):
		boss_hud_canvas.queue_free()
		boss_hud_canvas = null
		boss_health_bar = null
		boss_health_label = null


func _create_hit_zone() -> void:
	var hit_zone = Area2D.new()
	hit_zone.name = "HitZone"
	hit_zone.collision_layer = 0
	hit_zone.collision_mask = 1
	hit_zone.monitoring = true
	add_child(hit_zone)
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 50.0
	collision.shape = shape
	hit_zone.add_child(collision)
	
	hit_zone.body_entered.connect(_on_hit_zone_body_entered)


func _on_hit_zone_body_entered(body: Node2D) -> void:
	if not boss_alive:
		return
	if not body.is_in_group("player"):
		return
	print("💥 Бос торкнувся гравця! Шкода: ", contact_damage)
	if body.has_method("take_damage"):
		body.take_damage(contact_damage, "hit")
		_play_impact_sound()


func _play_impact_sound() -> void:
	var p = AudioStreamPlayer.new()
	var paths = ["res://assets/sounds/hit.mp3", "res://assets/sounds/hit.wav", "res://assets/sounds/hit.ogg"]
	for path in paths:
		if ResourceLoader.exists(path):
			p.stream = load(path)
			break
	if p.stream:
		p.bus = "SFX" # 🔥 ПРОПИСАВ ШИНУ
		p.volume_db = -10.0
		get_tree().root.add_child(p)
		p.play()
		p.finished.connect(func(): p.queue_free())


func _create_bullet_detector() -> void:
	var detector = Area2D.new()
	detector.name = "BulletDetector"
	detector.collision_layer = 0
	detector.collision_mask = 1 | 2 | 4 | 8
	detector.monitoring = true
	add_child(detector)
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = dodge_zone_radius
	collision.shape = shape
	detector.add_child(collision)
	
	detector.area_entered.connect(_on_bullet_detected)
	detector.body_entered.connect(_on_bullet_detected)


func _on_bullet_detected(bullet: Node) -> void:
	if not boss_alive:
		return
	
	if not bullet.is_in_group("player_bullets"):
		return
	
	if dodge_cooldown > 0:
		return
	
	var bullet_velocity = Vector2.ZERO
	
	if "velocity" in bullet:
		bullet_velocity = bullet.velocity
	elif "speed" in bullet:
		bullet_velocity = Vector2.RIGHT.rotated(bullet.rotation) * bullet.speed
	
	if bullet_velocity.length() < 1:
		return
	
	var perpendicular_1 = Vector2(-bullet_velocity.y, bullet_velocity.x).normalized()
	var perpendicular_2 = Vector2(bullet_velocity.y, -bullet_velocity.x).normalized()
	
	var future_bullet_pos = bullet.global_position + bullet_velocity * 0.3
	var dist_1 = (global_position + perpendicular_1 * 100).distance_to(future_bullet_pos)
	var dist_2 = (global_position + perpendicular_2 * 100).distance_to(future_bullet_pos)
	
	if dist_1 > dist_2:
		dodge_direction = perpendicular_1
	else:
		dodge_direction = perpendicular_2
	
	dodge_timer = dodge_duration
	dodge_cooldown = 0.5


func take_damage(amount: int) -> void:
	if not boss_alive:
		return
	
	health -= amount
	_update_boss_health_bar()
	
	if health <= 0:
		health = 0
		boss_alive = false
		_remove_boss_health_bar()
		die()


func set_room(room: Node2D) -> void:
	current_room = room


func die() -> void:
	if player and is_instance_valid(player) and player.has_method("play_kill_sound"):
		player.play_kill_sound()
	else:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0 and players[0].has_method("play_kill_sound"):
			players[0].play_kill_sound()

	if current_room and is_instance_valid(current_room):
		current_room.on_enemy_died(self)
	
	if player and is_instance_valid(player):
		rotation = global_position.angle_to_point(player.global_position)
	
	if sprite:
		sprite.texture = tex_dead
	
	var main_col = get_node_or_null("CollisionShape2D")
	if main_col:
		main_col.set_deferred("disabled", true)
		
	var hit_zone = get_node_or_null("HitZone")
	if hit_zone:
		hit_zone.set_deferred("monitoring", false)
		hit_zone.set_deferred("monitorable", false)
		
	var bullet_det = get_node_or_null("BulletDetector")
	if bullet_det:
		bullet_det.set_deferred("monitoring", false)
		bullet_det.set_deferred("monitorable", false)
		
	set_physics_process(false)
	remove_from_group("enemies")
	remove_from_group("boss")
	z_index = 0


func _exit_tree() -> void:
	_remove_boss_health_bar()
