extends Node2D

var is_open: bool = false
var current_direction: String = "top"

var can_teleport: bool = true
var teleport_cooldown: float = 1.0

var target_room: Node2D = null
var target_door: Node2D = null
var target_spawn_position: Vector2 = Vector2.ZERO
var my_room: Node2D = null

func _ready() -> void:
	var teleport_zone = get_node_or_null("TeleportZone")
	
	if not teleport_zone:
		teleport_zone = Area2D.new()
		teleport_zone.name = "TeleportZone"
		add_child(teleport_zone)
		
		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(120, 60)
		collision.shape = shape
		teleport_zone.add_child(collision)
	
	teleport_zone.monitoring = true
	teleport_zone.monitorable = true
	teleport_zone.collision_layer = 1
	teleport_zone.collision_mask = 1
	
	if not teleport_zone.body_entered.is_connected(_on_teleport_zone_body_entered):
		teleport_zone.body_entered.connect(_on_teleport_zone_body_entered)

func setup_direction(dir_key: String) -> void:
	current_direction = dir_key.strip_edges().to_lower()
	update_appearance()

func setup_target_room(neighbor_room: Node2D, my_direction: String) -> void:
	if neighbor_room == null or not is_instance_valid(neighbor_room):
		return
	
	if not neighbor_room.has_method("get_door_by_direction"):
		return
	
	target_room = neighbor_room
	
	var opposite_dir = _get_opposite_dir(my_direction)
	target_door = target_room.get_door_by_direction(opposite_dir)
	
	if target_door == null:
		target_spawn_position = target_room.global_position + Vector2(960, 540)
		return
	
	var spawn_marker = target_door.get_node_or_null("SpawnPoint")
	if spawn_marker:
		target_spawn_position = spawn_marker.global_position
	else:
		target_spawn_position = target_door.global_position + _get_spawn_offset(opposite_dir)

func set_open(open_state: bool) -> void:
	if open_state and not is_open:
		_play_door_open_sound()
		
	is_open = open_state
	visible = true
	update_appearance()
	
	var teleport_zone = get_node_or_null("TeleportZone")
	if teleport_zone:
		teleport_zone.set_deferred("monitoring", is_open)
		teleport_zone.set_deferred("monitorable", is_open)
	
	_disable_static_body_collisions(self, is_open)

func _play_door_open_sound() -> void:
	var p = AudioStreamPlayer.new()
	var paths = ["res://assets/sounds/door_open.mp3", "res://assets/sounds/door_open.wav", "res://assets/sounds/door_open.ogg"]
	for path in paths:
		if ResourceLoader.exists(path):
			p.stream = load(path)
			break
	if p.stream:
		p.bus = "SFX" # 🔥 ТУТ ПРИВ'ЯЗКА ДО ШИНИ ЗВУКІВ ГРИ
		p.volume_db = -10.0 
		get_tree().root.add_child(p)
		p.play()
		p.finished.connect(func(): p.queue_free())

func _disable_static_body_collisions(node: Node, disabled: bool) -> void:
	for child in node.get_children():
		if child.name == "TeleportZone":
			continue
		
		if child is StaticBody2D:
			for sub_child in child.get_children():
				if sub_child is CollisionShape2D or sub_child is CollisionPolygon2D:
					sub_child.set_deferred("disabled", disabled)
		
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", disabled)
		
		if not child is Area2D:
			_disable_static_body_collisions(child, disabled)

func update_appearance() -> void:
	for child in get_children():
		if child is Sprite2D:
			child.visible = false
	
	var state_prefix = "DoorOpen" if is_open else "DoorClose"
	var dir_suffix = current_direction.capitalize()
	var target_name = state_prefix + dir_suffix
	
	for child in get_children():
		if child is Sprite2D:
			if child.name == target_name:
				child.visible = true
				return
	
	for child in get_children():
		if not child is Sprite2D:
			continue
		
		var sprite_name = child.name.to_lower()
		var dir_lower = current_direction.to_lower()
		
		var matches_dir = sprite_name.contains(dir_lower)
		var matches_state = sprite_name.contains("open") if is_open else (sprite_name.contains("close") or sprite_name.contains("closed"))
		
		if matches_dir and matches_state:
			child.visible = true
			return

func _get_opposite_dir(dir: String) -> String:
	match dir.to_lower():
		"top": return "bottom"
		"bottom": return "top"
		"left": return "right"
		"right": return "left"
	return dir

func _get_spawn_offset(dir: String) -> Vector2:
	match dir.to_lower():
		"top": return Vector2(0, 200)
		"bottom": return Vector2(0, -200)
		"left": return Vector2(200, 0)
		"right": return Vector2(-200, 0)
	return Vector2.ZERO

func _on_teleport_zone_body_entered(body: Node2D) -> void:
	if not can_teleport:
		return
	
	if not body.is_in_group("player"):
		return
	
	if body.get_class() != "CharacterBody2D":
		return
	
	if not is_open:
		return
	
	if target_room == null or not is_instance_valid(target_room):
		_try_retarget()
		if target_room == null or not is_instance_valid(target_room):
			return
	
	if target_room and target_room.has_method("get") and target_room.get("is_boss_room") == true:
		var generator = get_tree().get_first_node_in_group("level_generator")
		if generator and generator.has_method("get") and not generator.get("boss_doors_unlocked"):
			return
	
	if target_spawn_position == Vector2.ZERO:
		if target_room and is_instance_valid(target_room):
			if target_room.has_method("get_door_by_direction"):
				var room_center = target_room.global_position + Vector2(960, 540)
				target_spawn_position = room_center + _get_spawn_offset(current_direction)
			else:
				return
		else:
			return
	
	body.global_position = target_spawn_position
	can_teleport = false
	
	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("move_to_room") and target_room:
		camera.move_to_room(target_room)
	
	await get_tree().create_timer(teleport_cooldown).timeout
	can_teleport = true

func set_my_room(room: Node2D) -> void:
	my_room = room

func _try_retarget() -> void:
	if not my_room or not is_instance_valid(my_room):
		return
	
	if not my_room.has_method("get") or not my_room.has_method("has_method"):
		return
	
	if my_room.has_method("get_door_by_direction"):
		var neighbor = null
		if my_room.has_method("get_neighbor"):
			neighbor = my_room.get_neighbor(current_direction)
		
		if neighbor and is_instance_valid(neighbor):
			setup_target_room(neighbor, current_direction)
