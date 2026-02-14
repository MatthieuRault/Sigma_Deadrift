extends Area2D

# ==================== PROPERTIES ====================

var damage := 1
var speed := 500.0
var piercing := false
var hits := 0
var max_pierce := 5

# ==================== INITIALIZATION ====================

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
	
	if piercing:
		hits += 1
		if hits >= max_pierce:
			queue_free()
	else:
		queue_free()

func _on_screen_exited() -> void:
	queue_free()
