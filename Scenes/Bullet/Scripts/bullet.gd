extends Area2D

var speed := 500.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += Vector2.RIGHT.rotated(rotation) * speed * delta
	
func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(1)
	queue_free()  # La balle disparaît à l'impact
	
func _on_screen_exited() -> void:
	queue_free()  # Supprimer la balle quand elle sort de l'écran
