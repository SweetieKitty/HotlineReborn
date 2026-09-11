extends Node2D

@export var player_scene: PackedScene
@export var minimap: Node
@export var weapon_item_scene: PackedScene    # 🔥 ДОДАНО

# 🔥 Гарантовані preload-посилання, щоб Godot не викинув їх при білді в .exe
@export var fallback_start_room: PackedScene = preload("res://tscn/OsamaRooms/floor1/room1.tscn")
@export var fallback_boss_room: PackedScene = preload("res://tscn/OsamaRooms/floor1/room8.2.tscn")

var boss_doors_unlocked: bool = false

var start_room_scene: PackedScene
var boss_room_scene: PackedScene
var normal_room_scenes: Array[PackedScene] = []

# 🔥 Збільшуємо відстань між кімнатами у сітці, щоб стіни не накладали одна на одну
var grid_size: Vector2 = Vector2(2400, 1500)
var occupied_grid: Dictionary = {}
var boss_room_instance: Node2D = null

var cleared_rooms: int = 0
var total_rooms_to_clear: int = 0

# 🔥 Система зброї
var cleared_rooms_for_weapons: int = 0
var weapons_spawned: int = 0
var max_weapons: int = 5

func _ready() -> void:
	add_to_group("level_generator")
	print("🔴 LevelGenerator._ready() ВИКЛИКАНО!")
	
	var current_floor = ProgressManager.current_stage
	load_rooms_for_floor(current_floor)
	
	var total_rooms = ProgressManager.get_random_rooms_count()
	total_rooms_to_clear = total_rooms - 2
	
	print("📊 total_rooms: ", total_rooms)
	print("📊 total_rooms_to_clear: ", total_rooms_to_clear)
	
	generate_level(total_rooms)
	
	# 🔥 Дебаг після генерації
	await get_tree().process_frame
	print("🔍 Після генерації:")
	print("   boss_room_instance: ", boss_room_instance.name if boss_room_instance else "null")

func load_rooms_for_floor(floor_num: int) -> void:
	normal_room_scenes.clear()
	start_room_scene = null
	boss_room_scene = null
	
	var folder_path = "res://tscn/OsamaRooms/floor" + str(floor_num) + "/"
	print("📂 Завантаження кімнат з: ", folder_path)
	
	var dir = DirAccess.open(folder_path)
	if not dir:
		printerr("❌ Не вдалося відкрити папку: ", folder_path)
		# Fallback на випадок падіння DirAccess в білді
		start_room_scene = fallback_start_room
		boss_room_scene = fallback_boss_room
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var all_rooms: Array[PackedScene] = []
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tscn"):
			var room_res = load(folder_path + file_name) as PackedScene
			if room_res:
				all_rooms.append(room_res)
				print("   📄 Завантажено: ", file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	if all_rooms.size() == 0:
		printerr("❌ Папка порожня!")
		start_room_scene = fallback_start_room
		boss_room_scene = fallback_boss_room
		return
	
	# 🔥 Гнучкий пошук за ім'ям (не залежить від регістру чи дрібних розбіжностей)
	for room in all_rooms:
		var r_name = room.resource_path.get_file().to_lower()
		if "room1" in r_name:
			start_room_scene = room
			print("✅ Стартова кімната: ", r_name)
		elif "room8" in r_name or "boss" in r_name:
			boss_room_scene = room
			print("👑 Бос-кімната: ", r_name)
		else:
			normal_room_scenes.append(room)
	
	# Fallback, якщо чогось не знайшло
	if start_room_scene == null:
		start_room_scene = fallback_start_room
		printerr("⚠️ Стартову кімнату не знайдено, використано fallback!")
	
	if boss_room_scene == null:
		boss_room_scene = fallback_boss_room
		printerr("⚠️ Бос-кімнату не знайдено, використано fallback!")
	
	print("📊 Підсумок:")
	print("   Стартова: ", start_room_scene.resource_path.get_file() if start_room_scene else "немає")
	print("   Бос: ", boss_room_scene.resource_path.get_file() if boss_room_scene else "немає")
	print("   Звичайних: ", normal_room_scenes.size())

func generate_level(total_rooms: int) -> void:
	print("🚨 generate_level() ВИКЛИКАНО! total_rooms=", total_rooms)
	
	occupied_grid.clear()
	cleared_rooms = 0
	boss_room_instance = null
	cleared_rooms_for_weapons = 0
	weapons_spawned = 0
	
	# 1. Генерація сітки координат
	var grid_positions: Array[Vector2i] = [Vector2i.ZERO]
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	
	while grid_positions.size() < total_rooms:
		var random_existing = grid_positions.pick_random()
		var dir = directions.pick_random()
		var new_pos = random_existing + dir
		
		if not grid_positions.has(new_pos):
			grid_positions.append(new_pos)

	# 2. Спавн усіх кімнат
	for i in range(grid_positions.size()):
		var pos = grid_positions[i]
		var room_number = i + 1
		
		var is_start = (i == 0)
		var is_boss = (i == grid_positions.size() - 1) and not is_start
		
		var selected_scene: PackedScene = null
		
		if is_start:
			selected_scene = start_room_scene
		elif is_boss:
			selected_scene = boss_room_scene
		elif normal_room_scenes.size() > 0:
			selected_scene = normal_room_scenes.pick_random()
		else:
			selected_scene = start_room_scene
		
		if selected_scene:
			var room_type = "СТАРТОВА" if is_start else ("БОС 👑" if is_boss else "звичайна")
			print("   🏠 Кімната #", room_number, " [", room_type, "]: ", selected_scene.resource_path.get_file())
			spawn_room_instance(pos, is_boss, is_start, selected_scene, room_number)

	# 3. Налаштування дверей та телепортів
	setup_all_doors()
	
	# 4. Закриваємо двері бос-кімнати (до зачищення всіх кімнат)
	if boss_room_instance:
		lock_boss_doors()

	# 5. Спавн гравця (по центру нової сітки 2400x1500 -> 1200, 750)
	if player_scene:
		var player = player_scene.instantiate()
		player.name = "Player"
		add_child(player)
		player.global_position = grid_size / 2.0
		print("✅ Гравець заспавнено: ", player.name)

	# 6. Камера
	var camera = Camera2D.new()
	camera.name = "MainCamera"
	var camera_script = load("res://scripts/camera_manager.gd")
	if camera_script:
		camera.set_script(camera_script)
	add_child(camera)
	camera.add_to_group("camera")
	camera.make_current()
	
	if camera.has_method("move_to_room"):
		var start_room = occupied_grid.get(Vector2i.ZERO, null)
		if start_room and is_instance_valid(start_room):
			camera.move_to_room(start_room)
	
	print("✅ Камера створена")
	
	# 7. Мінімапа
	if minimap and minimap.has_method("setup_map"):
		var map_positions: Array[Vector2] = []
		for p in grid_positions:
			map_positions.append(Vector2(p))
		minimap.setup_map(map_positions, Vector2(grid_positions.back()))

func spawn_room_instance(grid_pos: Vector2i, is_boss: bool, is_start: bool, scene_to_spawn: PackedScene, room_number: int) -> void:
	if scene_to_spawn == null:
		return
	
	var room = scene_to_spawn.instantiate()
	if room == null:
		return
	
	room.position = Vector2(grid_pos) * grid_size
	
	if "room_number" in room:
		room.room_number = room_number
	if "is_boss_room" in room:
		room.is_boss_room = is_boss
	if "is_start_room" in room:
		room.is_start_room = is_start

	add_child(room)
	
	if "is_cleared" in room:
		room.is_cleared = is_start

	# Зберігаємо бос-кімнату
	if is_boss:
		boss_room_instance = room

	# Сигнали для ВСІХ кімнат, КРІМ стартової
	if not is_start and room.has_signal("room_cleared"):
		room.room_cleared.connect(_on_room_cleared)
		room.room_cleared.connect(_heal_player)

	occupied_grid[grid_pos] = room

# ЗЦІЛЮЄ ГРАВЦЯ ПІСЛЯ ЗАЧИЩЕННЯ КІМНАТИ
func _heal_player() -> void:
	print("💚 Викликаємо зцілення для гравця...")
	
	await get_tree().process_frame
	
	var players = get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		printerr("   ❌ Гравця не знайдено!")
		return
	
	var player = players[0]
	
	if player.has_method("heal"):
		var heal_amount = 20 
		if "heal_per_room" in player:
			heal_amount = player.heal_per_room
		
		player.heal(heal_amount)
		print("   ✅ Гравця зцілено!")
	else:
		printerr("   ⚠️ Гравець не має методу heal()!")

# СПАВН ВИПАДКОВОЇ ЗБРОЇ
func _spawn_random_weapon() -> void:
	if weapon_item_scene == null:
		weapon_item_scene = load("res://tscn/weapon_item.tscn")
		if weapon_item_scene == null:
			printerr("   ❌ weapon_item.tscn не знайдено!")
			return
	
	var players = get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		return
	
	var player = players[0]
	var current_room_grid = Vector2i(
		int(floor(player.global_position.x / grid_size.x)),
		int(floor(player.global_position.y / grid_size.y))
	)
	
	var current_room = occupied_grid.get(current_room_grid, null)
	if not current_room or not is_instance_valid(current_room):
		printerr("   ❌ Поточна кімната не знайдена для спавну зброї!")
		return
	
	var weapon = weapon_item_scene.instantiate()
	var random_type = randi() % 4
	weapon.weapon_type = random_type
	
	match random_type:
		0: 
			weapon.weapon_name = "Дробовик"
			weapon.ammo = 10
		1: 
			weapon.weapon_name = "Автомат"
			weapon.ammo = 50
		2: 
			weapon.weapon_name = "РПГ"
			weapon.ammo = 5
		3: 
			weapon.weapon_name = "Кулемет"
			weapon.ammo = 100
	
	current_room.add_child(weapon)
	
	# Центр кімнати для нової сітки 2400x1500 (1200, 750)
	var room_center = current_room.global_position + Vector2(1200, 750)
	weapon.global_position = room_center + Vector2(
		randf_range(-200, 200),
		randf_range(-100, 100)
	)
	
	weapons_spawned += 1
	print("🔫 Зброя заспавнена: ", weapon.weapon_name, " | Боєзапас: ", weapon.ammo, " | Залишилось: ", max_weapons - weapons_spawned)

func setup_all_doors() -> void:
	# ЕТАП 1: Створюємо двері для всіх кімнат
	for grid_pos in occupied_grid:
		var room = occupied_grid[grid_pos]
		if not is_instance_valid(room):
			continue
		
		var top_room = occupied_grid.get(grid_pos + Vector2i.UP, null)
		var bottom_room = occupied_grid.get(grid_pos + Vector2i.DOWN, null)
		var left_room = occupied_grid.get(grid_pos + Vector2i.LEFT, null)
		var right_room = occupied_grid.get(grid_pos + Vector2i.RIGHT, null)
		
		var has_top = is_instance_valid(top_room)
		var has_bottom = is_instance_valid(bottom_room)
		var has_left = is_instance_valid(left_room)
		var has_right = is_instance_valid(right_room)
		
		if not has_top: top_room = null
		if not has_bottom: bottom_room = null
		if not has_left: left_room = null
		if not has_right: right_room = null
		
		if room.has_method("setup_doors"):
			room.setup_doors(has_top, has_bottom, has_left, has_right, top_room, bottom_room, left_room, right_room)
		
		if "is_cleared" in room and room.is_cleared:
			if "is_boss_room" in room and room.is_boss_room:
				print("🔒 Бос-кімната: двері залишаються закритими")
			elif room.has_method("unlock_doors"):
				room.unlock_doors()

	# ЕТАП 2: НАЛАШТОВУЄМО ТЕЛЕПОРТИ ДЛЯ ВСІХ ДВЕРЕЙ
	for grid_pos in occupied_grid:
		var room = occupied_grid[grid_pos]
		if is_instance_valid(room) and room.has_method("setup_teleport_targets"):
			room.setup_teleport_targets()

# ЗАКРИВАЄМО ДВЕРІ БОС-КІМНАТИ
func lock_boss_doors() -> void:
	print("🔒 lock_boss_doors() ВИКЛИКАНО!")
	
	if not boss_room_instance or not is_instance_valid(boss_room_instance):
		printerr("   ❌ boss_room_instance не знайдено!")
		return
	
	var boss_grid_pos: Vector2i = Vector2i.ZERO
	var found = false
	for grid_pos in occupied_grid:
		if occupied_grid[grid_pos] == boss_room_instance:
			boss_grid_pos = grid_pos
			found = true
			break
	
	if not found:
		printerr("   ❌ Бос-кімната не знайдена!")
		return
	
	print("   Бос на позиції: ", boss_grid_pos)
	
	var directions = {
		"top": Vector2i.UP,
		"bottom": Vector2i.DOWN,
		"left": Vector2i.LEFT,
		"right": Vector2i.RIGHT
	}
	
	for dir_name in directions:
		var neighbor_pos = boss_grid_pos + directions[dir_name]
		var neighbor_room = occupied_grid.get(neighbor_pos, null)
		
		if neighbor_room and is_instance_valid(neighbor_room):
			var opposite_dir = _get_opposite_dir(dir_name)
			
			if neighbor_room.has_method("mark_boss_door"):
				neighbor_room.mark_boss_door(opposite_dir)
			
			if neighbor_room.has_method("get_door_by_direction"):
				var door = neighbor_room.get_door_by_direction(opposite_dir)
				if door and is_instance_valid(door) and door.has_method("set_open"):
					door.set_open(false)
					print("   🔒 Закрито двері в ", neighbor_room.name, " (", opposite_dir, ")")
	
	if boss_room_instance.has_method("lock_doors"):
		boss_room_instance.lock_doors()
	
	print("✅ Двері боса закриті!")
	
func unlock_boss_doors() -> void:
	if boss_doors_unlocked:
		return
	boss_doors_unlocked = true
	
	if not boss_room_instance or not is_instance_valid(boss_room_instance):
		return
	
	print("🔓 Відкриваю двері боса!")
	
	var boss_grid_pos: Vector2i = Vector2i.ZERO
	for grid_pos in occupied_grid:
		if occupied_grid[grid_pos] == boss_room_instance:
			boss_grid_pos = grid_pos
			break
	
	var directions = {
		"top": Vector2i.UP,
		"bottom": Vector2i.DOWN,
		"left": Vector2i.LEFT,
		"right": Vector2i.RIGHT
	}
	
	for dir_name in directions:
		var neighbor_pos = boss_grid_pos + directions[dir_name]
		var neighbor_room = occupied_grid.get(neighbor_pos, null)
		
		if neighbor_room and is_instance_valid(neighbor_room):
			var opposite_dir = _get_opposite_dir(dir_name)
			
			if neighbor_room.has_method("get_door_by_direction"):
				var door = neighbor_room.get_door_by_direction(opposite_dir)
				if door and is_instance_valid(door) and door.has_method("set_open"):
					door.set_open(true)
					print("   🔓 Відкрито двері в ", neighbor_room.name, " (", opposite_dir, ")")
	
	if boss_room_instance.has_method("unlock_all_doors_force"):
		boss_room_instance.unlock_all_doors_force()
	
	print("✅ Двері боса відкриті!")

# Спавн зброї при зачищенні кімнати
func _on_room_cleared() -> void:
	cleared_rooms += 1
	cleared_rooms_for_weapons += 1 
	
	print("✅ Кімната зачищена! Прогрес: ", cleared_rooms, "/", total_rooms_to_clear)
	print("   boss_doors_unlocked: ", boss_doors_unlocked)
	
	if cleared_rooms_for_weapons >= 2 and weapons_spawned < max_weapons:
		cleared_rooms_for_weapons = 0
		_spawn_random_weapon()
	
	if cleared_rooms >= total_rooms_to_clear:
		print("🎉 ВСІ КІМНАТИ ЗАЧИЩЕНІ! Викликаємо unlock_boss_doors()")
		if not boss_doors_unlocked:
			unlock_boss_doors()
			
func _get_opposite_dir(dir: String) -> String:
	match dir.to_lower():
		"top": return "bottom"
		"bottom": return "top"
		"left": return "right"
		"right": return "left"
	return dir
