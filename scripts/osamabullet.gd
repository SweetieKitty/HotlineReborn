extends Area2D

@export var speed: float = 800.0
@export var damage: float = 30.0

func _physics_process(delta: float) -> void:
	# Куля летить у напрямку, куди дивиться
	position += Vector2.RIGHT.rotated(rotation) * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
			_play_hit_sound() # 🔥 ЗВУК ВЛУЧАННЯ
		queue_free()

func _play_hit_sound() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0].has_method("play_hit_sound"):
		players[0].play_hit_sound()
