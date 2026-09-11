extends Camera2D

@export var grid_size: Vector2 = Vector2(2065, 1075)

var current_room: Node2D = null

# === ЗМІННІ ДЛЯ ТРЯСКИ ===
var shake_strength: float = 0.0
var shake_fade: float = 5.0

func _ready() -> void:
	make_current()
	position_smoothing_enabled = false
	
	# 🔥 Ось тут я віддалив камеру (було 1.0, стало 0.9)
	zoom = Vector2(0.9, 0.9)

func _process(delta: float) -> void:
	# 🔥 Оновлюємо тряску екрану кожний кадр
	if shake_strength > 0:
		shake_strength = lerp(shake_strength, 0.0, shake_fade * delta)
		offset = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
	else:
		offset = Vector2.ZERO

# 🔥 Функція запуску тряски (сила + швидкість затухання)
func apply_shake(strength: float, fade: float = 5.0) -> void:
	if strength > shake_strength:
		shake_strength = strength
		shake_fade = fade

# 🔥 Викликається при телепорті гравця в нову кімнату
func move_to_room(room: Node2D) -> void:
	if not room:
		return
	
	current_room = room
	
	# Центр кімнати = її позиція + половина розміру
	var center = room.global_position + grid_size / 2.0
	
	# Миттєво переміщуємо камеру в центр кімнати (без анімації)
	global_position = center
	
	# Встановлюємо ліміти = межі кімнати
	limit_left = int(room.global_position.x)
	limit_top = int(room.global_position.y)
	limit_right = int(room.global_position.x + grid_size.x)
	limit_bottom = int(room.global_position.y + grid_size.y)
	
	print("📷 Камера на кімнаті: ", room.name, " | Центр: ", center)
