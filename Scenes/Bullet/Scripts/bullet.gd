extends Area2D

var damage := 1
var speed := 500.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += Vector2.RIGHT.rotated(rotation) * speed * delta
	
func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()  # Remove bullet on hit
	
func _on_screen_exited() -> void:
	queue_free()  # Delete bullet when off-screen
