extends Control

# === НАЛАШТУВАННЯ ===
@export var map_size: Vector2 = Vector2(200, 200)
@export var room_cell_size: float = 20.0
@export var grid_size: Vector2 = Vector2(2100, 1200)

# === КОЛЬОРИ ===
var color_room_normal: Color = Color(0.3, 0.3, 0.5, 0.8)
var color_room_cleared: Color = Color(0.2, 0.6, 0.2, 0.8)
var color_room_current: Color = Color(0.9, 0.9, 0.2, 0.9)
var color_room_boss: Color = Color(0.8, 0.1, 0.1, 0.9)
var color_door_line: Color = Color(0.5, 0.5, 0.7, 0.5)

# === ДАНІ КАРТИ ===
var room_positions: Array[Vector2] = []
var boss_position: Vector2 = Vector2.ZERO
var player: Node2D = null
var map_center: Vector2 = Vector2.ZERO

func _ready() -> void:
	_find_player()

func _process(_delta: float) -> void:
	# 🔥 Перевіряємо, чи гравець все ще існує
	if player == null or not is_instance_valid(player):
		player = null  # 🔥 Обнуляємо звільнене посилання
		_find_player()
	queue_redraw()

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var found_player = players[0]
		# 🔥 Перевіряємо, що гравець дійсний
		if is_instance_valid(found_player):
			player = found_player

func setup_map(positions: Array[Vector2], boss_pos: Vector2) -> void:
	room_positions = positions
	boss_position = boss_pos
	
	if room_positions.size() > 0:
		var sum = Vector2.ZERO
		for p in room_positions:
			sum += p
		map_center = sum / room_positions.size()
	
	queue_redraw()

func _draw() -> void:
	# === 1. Фон карти ===
	var bg_rect = Rect2(-map_size / 2, map_size)
	draw_rect(bg_rect, Color(0.05, 0.05, 0.1, 0.7))
	
	# === 2. Лінії між кімнатами ===
	for i in range(room_positions.size()):
		var pos_a = room_positions[i]
		for j in range(i + 1, room_positions.size()):
			var pos_b = room_positions[j]
			if abs(pos_a.x - pos_b.x) + abs(pos_a.y - pos_b.y) == 1.0:
				var screen_a = _grid_to_map(pos_a)
				var screen_b = _grid_to_map(pos_b)
				draw_line(screen_a, screen_b, color_door_line, 2.0)
	
	# === 3. Кімнати ===
	for i in range(room_positions.size()):
		var pos = room_positions[i]
		var screen_pos = _grid_to_map(pos)
		var rect = Rect2(screen_pos - Vector2(room_cell_size / 2, room_cell_size / 2), 
						 Vector2(room_cell_size, room_cell_size))
		
		var color = color_room_normal
		
		# Бос-кімната
		if pos == boss_position:
			color = color_room_boss
		
		# 🔥 Зачищена кімната (з перевіркою is_instance_valid)
		var room = _get_room_at(pos)
		if room != null and is_instance_valid(room):
			if "is_cleared" in room and room.is_cleared:
				color = color_room_cleared
		
		# 🔥 Поточна кімната гравця
		if player != null and is_instance_valid(player):
			var player_grid = _world_to_grid(player.global_position)
			if player_grid == pos:
				color = color_room_current
		
		draw_rect(rect, color)
		draw_rect(rect, Color(1, 1, 1, 0.3), false, 1.0)

# === ДОПОМІЖНІ ФУНКЦІЇ ===

func _grid_to_map(grid_pos: Vector2) -> Vector2:
	var offset = grid_pos - map_center
	return offset * room_cell_size

func _world_to_grid(world_pos: Vector2) -> Vector2:
	return Vector2(
		floor(world_pos.x / grid_size.x),
		floor(world_pos.y / grid_size.y)
	)

# 🔥 ВИПРАВЛЕНА функція пошуку кімнати
func _get_room_at(grid_pos: Vector2) -> Node2D:
	var generator = get_tree().get_first_node_in_group("level_generator")
	
	# 🔥 Перевіряємо, що генератор існує
	if generator == null or not is_instance_valid(generator):
		return null
	
	if not "occupied_grid" in generator:
		return null
	
	var key = Vector2i(int(grid_pos.x), int(grid_pos.y))
	var room = generator.occupied_grid.get(key, null)
	
	# 🔥 Перевіряємо, що кімната існує
	if room != null and is_instance_valid(room):
		return room
	
	return null
