extends CharacterBody2D

var speed := 100.0
var player : CharacterBody2D
var health := 3

func _ready() -> void:
	$Sprite2D.modulate = Color.RED

func _physics_process(delta: float) -> void:
	if not player:
		player = get_tree().get_first_node_in_group("player")
		
	if player:
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * speed
		move_and_slide()


func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		queue_free()  # Meurt
