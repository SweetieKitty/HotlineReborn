extends Area2D

@export var speed: float = 800.0
@export var damage: float = 30.0
@export var lifetime: float = 3.0  # 🔥 Куля живе 3 секунди

var time_alive: float = 0.0

func _ready() -> void:
	print("🔫 Куля боса створена! Позиція: ", global_position)
	
	# 🔥 Підключаємо сигнал програмно (на випадок, якщо він не підключений у сцені)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	# 🔥 Перевіряємо, чи є CollisionShape2D
	var has_collision = false
	for child in get_children():
		if child is CollisionShape2D:
			has_collision = true
			break
	
	if not has_collision:
		printerr("   ⚠️ Куля НЕ МАЄ CollisionShape2D! Вона не буде ні з ким взаємодіяти!")

func _physics_process(delta: float) -> void:
	# Куля летить у напрямку, куди дивиться
	global_position += Vector2.RIGHT.rotated(rotation) * speed * delta
	
	# 🔥 Таймер знищення
	time_alive += delta
	if time_alive > lifetime:
		queue_free()

# 🔥 ВИПРАВЛЕНА логіка шкоди
func _on_body_entered(body: Node2D) -> void:
	# 🔥 Куля боса завдає шкоду ТІЛЬКИ гравцю
	if body.is_in_group("player"):
		print("💥 Куля боса влучила в гравця! Шкода: ", damage)
		if body.has_method("take_damage"):
			body.take_damage(int(damage))
		queue_free()
