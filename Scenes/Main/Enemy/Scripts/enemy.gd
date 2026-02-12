extends CharacterBody2D

# Movement
var speed := 100.0
var player : CharacterBody2D

# Combat
var health := 3
var enemy_type := "normal"
var score_value := 10
var damage := 1

# Textures per enemy type
var tex_normal = preload("res://Scenes/Main/Enemy/Sprites/enemy_normal.png")
var tex_fast = preload("res://Scenes/Main/Enemy/Sprites/enemy_fast.png")
var tex_tank = preload("res://Scenes/Main/Enemy/Sprites/enemy_tank.png")

# Power-up drop on death
var powerup_scene = preload("res://Scenes/PowerUp/powerup.tscn")

# Sounds
var death_sound = preload("res://Sounds/enemy_death.wav")

func _ready() -> void:
	add_to_group("enemy")
	if not player:
		player = get_tree().get_first_node_in_group("player")

# Configure enemy stats and appearance based on type
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
	
	# Move toward the player
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * speed
	move_and_slide()
	
	# Deal contact damage when close enough
	if global_position.distance_to(player.global_position) < 30:
		if player.has_method("take_damage"):
			player.take_damage(damage)

# Take damage from bullets, die at 0 HP
func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		var main = get_tree().current_scene
		
		# Add score
		if main.has_method("add_score"):
			main.add_score(score_value)
		
		# Play death sound on main scene (so it persists after queue_free)
		var audio = AudioStreamPlayer.new()
		audio.stream = death_sound
		audio.volume_db = -12
		main.add_child(audio)
		audio.play()
		audio.finished.connect(audio.queue_free)
		
		# 30% chance to drop a random power-up
		if randf() < 0.3:
			var powerup = powerup_scene.instantiate()
			var types = ["heal", "fire_rate", "damage"]
			powerup.setup(types.pick_random())
			powerup.global_position = global_position
			main.call_deferred("add_child", powerup)
		
		queue_free()
	else:
		# Hit flash - briefly turn red then back to normal
		var original_color = $Sprite2D.modulate
		$Sprite2D.modulate = Color.RED
		await get_tree().create_timer(0.1).timeout
		$Sprite2D.modulate = original_color
