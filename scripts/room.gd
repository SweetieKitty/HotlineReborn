extends Area2D

signal room_cleared

var has_emitted_cleared: bool = false
var boss_spawn_pending: bool = false
var boss_defeated: bool = false
var boss_door_directions: Array[String] = []

@export var is_boss_room: bool = false
@export var door_scene: PackedScene = preload("res://tscn/door.tscn")
@export var boss_scene: PackedScene
@export var enemy_scene: PackedScene = preload("res://tscn/enemy.tscn")
@export var waves: Array[int] = [3]
@export var spawn_delay: float = 0.5

var grid_pos: Vector2 = Vector2.ZERO
var is_cleared: bool = false
var player_inside: bool = false
var is_start_room: bool = false

var spawned_doors := {}
var neighbors := {}

var current_wave: int = 0
var alive_enemies: int = 0
var wave_active: bool = false

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	
	if not monitoring:
		monitoring = true
	if not monitorable:
		monitorable = true
	
	await get_tree().process_frame
	for child in get_children():
		if child.is_in_group("enemies"):
			child.queue_free()
	
	add_to_group("rooms")

func _on_body_entered(body: Node2D) -> void:
	if body.get_class() != "CharacterBody2D":
		return
	if not is_instance_valid(body):
		return
	if not body.is_in_group("player"):
		return
	if not body.has_method("shoot"):
		return
	
	var col_shape = get_node_or_null("CollisionShape2D")
	if col_shape and col_shape.shape is RectangleShape2D:
		var shape_size = col_shape.shape.size
		var shape_center = col_shape.position
		var room_rect = Rect2(global_position + shape_center - shape_size / 2.0, shape_size)
		if not room_rect.has_point(body.global_position):
			return
	
	player_inside = true
	
	if is_start_room:
		return
	
	if is_boss_room:
		if boss_defeated or wave_active:
			return
		lock_doors()
		_start_boss_fight_delayed()
		return
	
	if is_cleared or wave_active:
		return
	
	lock_doors()
	start_wave()

func _on_body_exited(body: Node2D) -> void:
	if body.get_class() != "CharacterBody2D":
		return
	if not is_instance_valid(body):
		return
	if not body.is_in_group("player"):
		return
	
	player_inside = false
	
	if is_boss_room and boss_spawn_pending and not wave_active:
		unlock_doors()

func start_wave() -> void:
	if current_wave >= waves.size() or enemy_scene == null:
		unlock_doors()
		return
	
	wave_active = true
	var enemy_count = waves[current_wave]
	alive_enemies = enemy_count
	
	for i in range(enemy_count):
		await get_tree().create_timer(spawn_delay).timeout
		if not is_instance_valid(self):
			return
		spawn_enemy()

func spawn_enemy() -> void:
	if enemy_scene == null or not enemy_scene.can_instantiate():
		return
	
	var enemy = enemy_scene.instantiate()
	if enemy == null:
		return
	
	var spawn_pos = _get_random_spawn_position()
	call_deferred("_add_enemy_to_room", enemy, spawn_pos)

func _add_enemy_to_room(enemy: Node2D, spawn_pos: Vector2) -> void:
	if not is_instance_valid(self):
		return
	add_child(enemy)
	enemy.global_position = spawn_pos
	
	if enemy.has_method("set_room"):
		enemy.set_room(self)

func _get_random_spawn_position() -> Vector2:
	var margin = 250.0 
	var room_size = Vector2(1920, 1080) 
	var max_attempts = 10
	
	for attempt in range(max_attempts):
		var random_x = randf_range(margin, room_size.x - margin)
		var random_y = randf_range(margin, room_size.y - margin)
		var candidate_pos = global_position + Vector2(random_x, random_y)
		
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsPointQueryParameters2D.new()
		query.position = candidate_pos
		query.collision_mask = 1 | 2
		query.exclude = [self.get_rid()]
		
		var result = space_state.intersect_point(query)
		if result.size() == 0:
			return candidate_pos
	
	return global_position + room_size / 2.0

func on_enemy_died(_enemy: Node2D = null) -> void:
	if is_cleared:
		return
		
	alive_enemies -= 1
	
	if alive_enemies <= 0:
		if is_boss_room:
			boss_defeated = true
			is_cleared = true
			wave_active = false
			unlock_doors()
			spawn_next_floor_door()
			room_cleared.emit()
			return
		
		wave_active = false
		is_cleared = true
		unlock_doors()

func setup_doors(has_top: bool, has_bottom: bool, has_left: bool, has_right: bool, top_room = null, bottom_room = null, left_room = null, right_room = null) -> void:
	neighbors = {
		"top": top_room, "bottom": bottom_room,
		"left": left_room, "right": right_room
	}
	
	if door_scene == null:
		return

	# Перевіряємо та створюємо ноду Doors, якщо її нема
	var doors_container = get_node_or_null("Doors")
	if not doors_container:
		doors_container = Node2D.new()
		doors_container.name = "Doors"
		add_child(doors_container)

	# Універсальний пошук маркерів (підтримує різні варіанти написання)
	var marker_top = _find_or_create_marker("Doors/DoorTop", Vector2(960, 0))
	var marker_bottom = _find_or_create_marker("Doors/DoorBottom", Vector2(960, 1080))
	var marker_left = _find_or_create_marker("Doors/DoorLeft", Vector2(0, 540))
	var marker_right = _find_or_create_marker("Doors/DoorRight", Vector2(1920, 540))

	if has_top: spawn_door_at("top", marker_top)
	if has_bottom: spawn_door_at("bottom", marker_bottom)
	if has_left: spawn_door_at("left", marker_left)
	if has_right: spawn_door_at("right", marker_right)

	if is_start_room or is_cleared:
		set_all_doors_open(true)
	else:
		lock_doors()

# 🔥 Допоміжна функція: шукає маркер або сама створює його на центрі стіни
func _find_or_create_marker(path: String, default_pos: Vector2) -> Node2D:
	var marker = get_node_or_null(path)
	if marker:
		return marker
		
	# Шукаємо також альтернативні назви (напр. DoorDown)
	var alt_path = path.replace("Bottom", "Down")
	marker = get_node_or_null(alt_path)
	if marker:
		return marker
		
	# Якщо маркерів взагалі немає в дереві — створюємо їх динамічно
	marker = Marker2D.new()
	marker.name = path.get_file()
	marker.position = default_pos
	
	var doors_node = get_node_or_null("Doors")
	if doors_node:
		doors_node.add_child(marker)
	else:
		add_child(marker)
		
	return marker

func spawn_door_at(dir_key: String, marker: Node) -> void:
	var door_inst = door_scene.instantiate()
	marker.add_child(door_inst)
	
	door_inst.position = Vector2.ZERO
	door_inst.rotation_degrees = 0
	door_inst.z_index = 10
	door_inst.add_to_group("doors")

	if door_inst.has_method("setup_direction"):
		door_inst.setup_direction(dir_key)
	
	if door_inst.has_method("set_my_room"):
		door_inst.set_my_room(self)
	
	if door_inst.has_method("set_open"):
		door_inst.set_open(is_start_room or is_cleared)
	
	spawned_doors[dir_key] = door_inst

func setup_teleport_targets() -> void:
	for dir_key in spawned_doors:
		var door = spawned_doors[dir_key]
		var target_room = neighbors.get(dir_key, null)
		if target_room and is_instance_valid(door) and door.has_method("setup_target_room"):
			door.setup_target_room(target_room, dir_key)

func get_door_by_direction(dir_key: String):
	return spawned_doors.get(dir_key, null)

func set_all_doors_open(open_state: bool) -> void:
	if not is_boss_room:
		is_cleared = open_state
	
	for dir_key in spawned_doors:
		var door = spawned_doors[dir_key]
		if is_instance_valid(door) and door.has_method("set_open"):
			if not is_boss_room and open_state and boss_door_directions.has(dir_key):
				var generator = get_tree().get_first_node_in_group("level_generator")
				if generator and generator.has_method("are_all_rooms_cleared") and generator.are_all_rooms_cleared():
					door.set_open(true)
				else:
					door.set_open(false)
				continue
			door.set_open(open_state)

func lock_doors() -> void:
	for dir_key in spawned_doors:
		var door = spawned_doors[dir_key]
		if is_instance_valid(door) and door.has_method("set_open"):
			door.set_open(false)

func unlock_doors() -> void:
	if is_boss_room:
		for dir_key in spawned_doors:
			var door = spawned_doors[dir_key]
			if is_instance_valid(door) and door.has_method("set_open"):
				door.set_open(true)
		return
	
	is_cleared = true
	
	var generator = get_tree().get_first_node_in_group("level_generator")
	var all_rooms_cleared = false
	if generator and generator.has_method("are_all_rooms_cleared"):
		all_rooms_cleared = generator.are_all_rooms_cleared()
	
	for dir_key in spawned_doors:
		var door = spawned_doors[dir_key]
		if is_instance_valid(door) and door.has_method("set_open"):
			if all_rooms_cleared or not boss_door_directions.has(dir_key):
				door.set_open(true)
			else:
				door.set_open(false)
	
	if not has_emitted_cleared:
		has_emitted_cleared = true
		room_cleared.emit()

func _start_boss_fight_delayed() -> void:
	if boss_spawn_pending:
		return
	
	boss_spawn_pending = true
	await get_tree().create_timer(2.0).timeout
	
	if not player_inside:
		boss_spawn_pending = false
		unlock_doors()
		return
	
	if not is_instance_valid(self):
		return
	
	boss_spawn_pending = false
	start_boss_wave()

func start_boss_wave() -> void:
	if not player_inside:
		return
	
	var scene_to_use = boss_scene if boss_scene else enemy_scene
	if scene_to_use == null:
		unlock_doors()
		return
	
	wave_active = true
	alive_enemies = 1
	
	var boss = scene_to_use.instantiate()
	call_deferred("_add_boss_to_room", boss)

func _add_boss_to_room(boss: Node2D) -> void:
	if not is_instance_valid(self):
		return
	add_child(boss)
	var center_pos = global_position + Vector2(960, 540)
	boss.global_position = center_pos
	
	if boss.has_method("set_room"):
		boss.set_room(self)

func mark_boss_door(dir_key: String) -> void:
	if not boss_door_directions.has(dir_key):
		boss_door_directions.append(dir_key)

func spawn_next_floor_door() -> void:
	if door_scene == null:
		door_scene = load("res://tscn/door.tscn")
		if door_scene == null:
			return
	
	var free_wall = _find_free_wall()
	if free_wall == "":
		free_wall = "top"
	
	var marker_name = "Doors/Door" + free_wall.capitalize()
	var marker = get_node_or_null(marker_name)
	
	if marker == null:
		for wall in ["top", "bottom", "left", "right"]:
			var alt_marker_name = "Doors/Door" + wall.capitalize()
			marker = get_node_or_null(alt_marker_name)
			if marker:
				free_wall = wall
				break
		if marker == null:
			return
	
	var door_inst = door_scene.instantiate()
	marker.add_child(door_inst)
	
	door_inst.position = Vector2.ZERO
	door_inst.rotation_degrees = 0
	door_inst.z_index = 10
	door_inst.name = "BossExitDoor"
	
	if door_inst.has_method("setup_direction"):
		door_inst.setup_direction(free_wall)
	if door_inst.has_method("set_open"):
		door_inst.set_open(true)
	
	_disable_door_collisions_for_exit(door_inst)
	
	var teleport_zone = door_inst.get_node_or_null("TeleportZone")
	if teleport_zone:
		for connection in teleport_zone.body_entered.get_connections():
			if connection["callable"].is_valid():
				teleport_zone.body_entered.disconnect(connection["callable"])
		teleport_zone.body_entered.connect(_on_boss_exit_door_entered)
		teleport_zone.set_deferred("monitoring", true)
		teleport_zone.set_deferred("monitorable", true)
	
	spawned_doors[free_wall] = door_inst

func _disable_door_collisions_for_exit(door: Node) -> void:
	for child in door.get_children():
		if child.name == "TeleportZone":
			continue
		
		if child is StaticBody2D:
			for sub_child in child.get_children():
				if sub_child is CollisionShape2D or sub_child is CollisionPolygon2D:
					sub_child.set_deferred("disabled", true)
		
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", true)
		
		if not child is Area2D:
			_disable_door_collisions_for_exit(child)

func _find_free_wall() -> String:
	var walls = ["top", "bottom", "left", "right"]
	for wall in walls:
		if not spawned_doors.has(wall):
			return wall
	return ""

func _on_boss_exit_door_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or not body.has_method("shoot"):
		return
	show_demo_end_message()

func show_demo_end_message() -> void:
	if get_tree().root.get_node_or_null("DemoEndUI"):
		return
	
	var canvas = CanvasLayer.new()
	canvas.name = "DemoEndUI"
	canvas.layer = 100
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(canvas)
	
	var background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.85)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(background)
	
	var title_label = Label.new()
	title_label.text = " ДЯКУЄМО ЗА ГРУ! "
	title_label.add_theme_font_size_override("font_size", 64)
	title_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_label.position.y = -100
	canvas.add_child(title_label)
	
	var subtitle_label = Label.new()
	subtitle_label.text = "Це кінець демо-версії.\nПовна гра не скоро!"
	subtitle_label.add_theme_font_size_override("font_size", 32)
	subtitle_label.add_theme_color_override("font_color", Color(1, 1, 1))
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	subtitle_label.position.y = 50
	canvas.add_child(subtitle_label)
	
	var exit_button = Button.new()
	exit_button.text = "Вийти з гри"
	exit_button.add_theme_font_size_override("font_size", 24)
	exit_button.custom_minimum_size = Vector2(250, 60)
	exit_button.set_anchors_preset(Control.PRESET_CENTER)
	exit_button.position = Vector2(-125, 150)
	exit_button.pressed.connect(func(): get_tree().quit())
	exit_button.process_mode = Node.PROCESS_MODE_ALWAYS
	canvas.add_child(exit_button)
	
	get_tree().paused = true

func unlock_all_doors_force() -> void:
	for dir_key in spawned_doors:
		var door = spawned_doors[dir_key]
		if is_instance_valid(door) and door.has_method("set_open"):
			door.set_open(true)
