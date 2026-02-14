extends Area2D

# ==================== PROPERTIES ====================

var damage := 1
var speed := 500.0
var piercing := false
var hits := 0
var max_pierce := 5
var bullet_type := "player"
var source_enemy : Node = null

# ==================== INITIALIZATION ====================

func set_type(type: String) -> void:
	bullet_type = type
	
	match bullet_type:
		"player":
			$Sprite2D.texture = preload("res://Scenes/Bullet/Sprites/default.png")
			$Sprite2D.modulate = Color(1,1,1)
			$Sprite2D.scale = Vector2(0.15, 0.15)
		"shaman": # Lightning bolt
			$Sprite2D.texture = preload("res://Scenes/Bullet/Sprites/default.png")
			$Sprite2D.modulate = Color(0.3, 0.7, 1.0)
			$Sprite2D.scale = Vector2(0.12, 0.18)
		"necromancer": # Dark drain bolt
			$Sprite2D.texture = preload("res://Scenes/Bullet/Sprites/default.png")
			$Sprite2D.modulate = Color(0.6, 0.1, 0.8)
			$Sprite2D.scale = Vector2(0.18, 0.18)    

func _ready() -> void:
	body_entered.connect(_on_body_entered)

# ==================== GAME LOOP ====================

func _physics_process(delta: float) -> void:
	position += Vector2.RIGHT.rotated(rotation) * speed * delta

# ==================== PIERCING ====================

func set_piercing(value: bool) -> void:
	piercing = value

# ==================== COLLISION ====================

func _on_body_entered(body: Node2D) -> void:
	# Impact particles
	Effects.spawn_impact(get_tree().current_scene, global_position)
	
	if body.has_method("take_damage"):
		body.take_damage(damage)
	
	# Necromancer drain
		if bullet_type == "necromancer" and body.is_in_group("player"):
			if is_instance_valid(source_enemy) and source_enemy.has_method("on_drain_hit"):
				source_enemy.on_drain_hit()
	
	if piercing:
		hits += 1
		if hits >= max_pierce:
			queue_free()
	else:
		queue_free()

func _on_screen_exited() -> void:
	queue_free()
