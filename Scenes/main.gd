extends Node2D

var score := 0
var enemy_scene = preload("res://Scenes/Main/Enemy/enemy.tscn")
@onready var score_label = $CanvasLayer/MarginContainer/Label

func _ready() -> void:
	$Timer.timeout.connect(_on_timer_timeout)

func add_score(amount: int) -> void:
	score += amount
	score_label.text = "Score : " + str(score)

func _on_timer_timeout() -> void:
	var enemy = enemy_scene.instantiate()
	
	# Random spawn at screen edges
	var side = randi() % 4
	var viewport_size = get_viewport_rect().size
	
	match side:
		0: # Top
			enemy.global_position = Vector2(randf() * viewport_size.x, -50)
		1: # Bottom
			enemy.global_position = Vector2(randf() * viewport_size.x, viewport_size.y + 50)
		2: # Left
			enemy.global_position = Vector2(-50, randf() * viewport_size.y)
		3: # Right
			enemy.global_position = Vector2(viewport_size.x + 50, randf() * viewport_size.y)
	
	add_child(enemy)
