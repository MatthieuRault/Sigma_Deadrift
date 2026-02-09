extends Area2D

var speed := 500.0

func _physics_process(delta: float) -> void:
	position += Vector2.RIGHT.rotated(rotation) * speed * delta
	
func _on_screen_exited() -> void:
	queue_free()  # Supprimer la balle quand elle sort de l'écran
