extends Area2D

enum WeaponType {
	SHOTGUN,
	AUTO_RIFLE,
	ROCKET,
	MINIGUN
}

@export var weapon_type: WeaponType = WeaponType.SHOTGUN
@export var weapon_name: String = "Зброя"
@export var ammo: int = 10

var is_collected: bool = false
var player_in_range: bool = false
var player_ref: Node2D = null
var prompt_label: Label = null

var sprite_names = {
	WeaponType.SHOTGUN: "ShotgunSprite",
	WeaponType.AUTO_RIFLE: "AutoRifleSprite",
	WeaponType.ROCKET: "RocketSprite",
	WeaponType.MINIGUN: "MinigunSprite"
}

func _ready() -> void:
	add_to_group("weapon_items")
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	
	_show_correct_sprite()
	
	await get_tree().process_frame
	_start_floating_animation()
	_create_prompt()
	
	print("🔫 Зброя створена: ", weapon_name, " | Боєзапас: ", ammo)

func _process(_delta: float) -> void:
	if player_in_range and not is_collected:
		if Input.is_key_pressed(KEY_E):
			_try_pickup()

func _try_pickup() -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		return
	
	if not player_ref.has_method("pickup_weapon"):
		return
	
	is_collected = true
	print("🔫 Гравець підібрав зброю: ", weapon_name)
	
	player_ref.pickup_weapon(weapon_type, ammo)
	
	_play_pickup_sound() # 🔥 ЗВУК ПІДБОРУ
	_spawn_collect_effect()
	queue_free()

func _play_pickup_sound() -> void:
	var p = AudioStreamPlayer.new()
	var paths = ["res://assets/sounds/pickup.mp3", "res://assets/sounds/pickup.wav", "res://assets/sounds/pickup.ogg"]
	for path in paths:
		if ResourceLoader.exists(path):
			p.stream = load(path)
			break
	if p.stream:
		get_tree().root.add_child(p)
		p.play()
		p.finished.connect(func(): p.queue_free())

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		player_ref = body
		if prompt_label:
			prompt_label.visible = true
		print("   ✅ Гравець поруч зі зброєю: ", weapon_name)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		player_ref = null
		if prompt_label:
			prompt_label.visible = false

func _create_prompt() -> void:
	var impact_font = load("res://fonts/Impact.ttf")
	
	prompt_label = Label.new()
	prompt_label.text = "[E] Підібрати: " + weapon_name
	prompt_label.add_theme_font_size_override("font_size", 24)
	prompt_label.add_theme_color_override("font_color", Color(1, 1, 1))
	prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	prompt_label.add_theme_constant_override("outline_size", 2)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.size = Vector2(300, 30)
	prompt_label.position = Vector2(-150, -70)
	prompt_label.visible = false
	if impact_font != null:
		prompt_label.add_theme_font_override("font", impact_font)
	add_child(prompt_label)

func _show_correct_sprite() -> void:
	for child in get_children():
		if child is Sprite2D:
			child.visible = false
	
	var target_sprite_name = sprite_names.get(weapon_type, "")
	var target_sprite = get_node_or_null(target_sprite_name)
	
	if target_sprite and target_sprite is Sprite2D:
		target_sprite.visible = true
		print("   ✅ Показано спрайт: ", target_sprite_name)
	else:
		printerr("   ⚠️ Спрайт '", target_sprite_name, "' не знайдено!")
		for child in get_children():
			if child is Sprite2D:
				child.visible = true
				break

func _start_floating_animation() -> void:
	var base_y = position.y
	
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "position:y", base_y - 10, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position:y", base_y, 0.8).set_trans(Tween.TRANS_SINE)

func _spawn_collect_effect() -> void:
	var effect = ColorRect.new()
	effect.color = Color(1, 1, 1)
	effect.color.a = 0.8
	effect.size = Vector2(10, 10)
	effect.position = Vector2(-5, -5)
	
	var parent = get_parent()
	if parent and is_instance_valid(parent):
		parent.add_child(effect)
		effect.global_position = global_position
		
		var tween = effect.create_tween()
		tween.tween_property(effect, "size", Vector2(60, 60), 0.3)
		tween.parallel().tween_property(effect, "position", effect.position - Vector2(25, 25), 0.3)
		tween.parallel().tween_property(effect, "color:a", 0.0, 0.3)
		tween.tween_callback(effect.queue_free)
