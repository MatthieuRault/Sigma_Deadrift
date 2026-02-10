extends CharacterBody2D

var speed := 100.0
var player : CharacterBody2D
var health := 3
var enemy_type := "normal"
var score_value := 10
var damage := 1
var tex_normal = preload("res://Scenes/Main/Enemy/Sprites/enemy_normal.png")
var tex_fast = preload("res://Scenes/Main/Enemy/Sprites/enemy_fast.png")
var tex_tank = preload("res://Scenes/Main/Enemy/Sprites/enemy_tank.png")
var powerup_scene = preload("res://Scenes/PowerUp/powerup.tscn")

func _ready() -> void:
	add_to_group("enemy")
	if not player:
		player = get_tree().get_first_node_in_group("player")
		
func setup(type: String) -> void:
	enemy_type = type
	match type:
		"normal":
			speed = 100.0
			health = 3
			score_value = 10
			damage = 1
			$Sprite2D.texture = tex_normal
		"fast":
			speed = 200.0
			health = 1
			score_value = 15
			damage = 1
			$Sprite2D.texture = tex_fast
		"tank":
			speed = 50.0
			health = 8
			score_value = 30
			damage = 2
			$Sprite2D.texture = tex_tank
	
	$Sprite2D.hframes = 4
	$Sprite2D.vframes = 4

func _physics_process(delta: float) -> void:	
	if not is_instance_valid(player):
		return
		
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * speed
	move_and_slide()
		
	# Contact damage
	if global_position.distance_to(player.global_position) < 30:
		if player.has_method("take_damage"):
			player.take_damage(damage)


func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		var main = get_tree().current_scene
		if main.has_method("add_score"):
			main.add_score(score_value)
		# 30% chance for a power-up drop
		if randf() < 0.3:
			var powerup = powerup_scene.instantiate()
			var types = ["heal", "fire_rate", "damage"]
			powerup.setup(types.pick_random())
			powerup.global_position = global_position
			main.call_deferred("add_child", powerup)
		queue_free()  # Death
	else:
		var original_color = $Sprite2D.modulate
		$Sprite2D.modulate = Color.RED
		await get_tree().create_timer(0.1).timeout
		$Sprite2D.modulate = original_color
