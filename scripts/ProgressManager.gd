extends Node

var current_stage: int = 1
var max_stages: int = 4
var cleared_rooms: Array = []
var boss_doors_unlocked: bool = false

func _ready() -> void:
	add_to_group("progress_manager")

func get_random_rooms_count() -> int:
	return randi_range(5, 8)

func next_stage() -> void:
	current_stage += 1
	if current_stage > max_stages:
		print("ГРА ПРОЙДЕНА! ВСІ ПОВЕРХИ ЗАЧИЩЕНО!")
		current_stage = 1
	get_tree().reload_current_scene()

func are_all_rooms_cleared() -> bool:
	var rooms = get_tree().get_nodes_in_group("rooms")
	for room in rooms:
		if is_instance_valid(room):
			if room.has_method("get") and not room.get("is_cleared"):
				return false
	return true

func reset_progress() -> void:
	cleared_rooms.clear()
	boss_doors_unlocked = false
