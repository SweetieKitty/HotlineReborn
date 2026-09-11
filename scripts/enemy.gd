extends CharacterBody2D

# === НАЛАШТУВАННЯ ===
@export var speed: float = 350.0
@export var attack_damage: int = 10
@export var attack_range: float = 120.0
@export var attack_cooldown: float = 1.0
@export var health: int = 100
@onready var aim_point: Node2D = get_node_or_null("AimPoint")

# 🔥 ЗАВАНТАЖУЄМО ТЕКСТУРИ
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
var tex_idle = preload("res://assets/musor0.png")
var tex_attack = preload("res://assets/musor1.png")
var tex_dead = preload("res://assets/musorPOMER.png")

# === ЗМІННІ ===
var player: Node2D = null
var player_chase: bool = false
var can_attack: bool = true
var current_room: Node2D = null
var is_dead: bool = false

func _ready() -> void:
	add_to_group("enemies")


func set_room(room: Node2D) -> void:
	current_room = room


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if player == null or not is_instance_valid(player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
		else:
			return
	
	look_at_player()
	
	if player_chase:
		var distance = global_position.distance_to(player.global_position)
		var direction = (player.global_position - global_position).normalized()
		
		if distance > attack_range:
			velocity = direction * speed
			move_and_slide()
		else:
			velocity = Vector2.ZERO 
			_try_attack()


func _try_attack() -> void:
	if not can_attack:
		return
	
	if player and is_instance_valid(player) and player.has_method("take_damage"):
		can_attack = false
		player.take_damage(attack_damage, "shocker")
		
		_play_shocker_sound()
		flash_shocker()
		
		await get_tree().create_timer(attack_cooldown).timeout
		can_attack = true


func _play_shocker_sound() -> void:
	var p = AudioStreamPlayer.new()
	var paths = ["res://assets/sounds/shocker.mp3", "res://assets/sounds/shocker.wav", "res://assets/sounds/shocker.ogg"]
	for path in paths:
		if ResourceLoader.exists(path):
			p.stream = load(path)
			break
	if p.stream:
		p.bus = "SFX" # 🔥 ПРОПИСАВ ШИНУ
		p.volume_db = -8.0
		get_tree().root.add_child(p)
		p.play()
		p.finished.connect(func(): p.queue_free())


func flash_shocker() -> void:
	if sprite and not is_dead:
		sprite.texture = tex_attack
		await get_tree().create_timer(0.2).timeout 
		if sprite and not is_dead: 
			sprite.texture = tex_idle


func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
		player_chase = true


func _on_detection_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = null
		player_chase = false


func take_damage(amount: int) -> void:
	if is_dead:
		return
	
	health -= amount
	print("💥 Ворог отримав шкоду: ", amount, " | HP: ", health)
	
	if health <= 0:
		die()


func die() -> void:
	if is_dead:
		return
	is_dead = true
	
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
		sprite.scale = Vector2(0.4, 0.4) 
		
	var main_col = get_node_or_null("CollisionShape2D")
	if main_col:
		main_col.set_deferred("disabled", true)
		
	var det_area = get_node_or_null("detection_area")
	if det_area:
		det_area.set_deferred("monitoring", false)
		det_area.set_deferred("monitorable", false)
		
	set_physics_process(false)
	remove_from_group("enemies")
	z_index = 0


func is_alive() -> bool:
	return health > 0


func look_at_player() -> void:
	if player == null or not is_instance_valid(player):
		return
	
	var angle_to_player = global_position.angle_to_point(player.global_position)
	
	if aim_point and aim_point.position.length() > 0.1:
		rotation = angle_to_player - aim_point.position.angle()
	else:
		rotation = angle_to_player
