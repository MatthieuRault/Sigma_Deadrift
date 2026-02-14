extends CharacterBody2D

# ==================== MOVEMENT ====================

var speed := 100.0
var player : CharacterBody2D

# ==================== COMBAT ====================

var health := 3
var max_health := 3
var enemy_type := "normal"
var score_value := 10
var damage := 1

# ==================== BOSS ====================

var is_boss := false
var boss_charge_cooldown := 3.0
var boss_charge_timer := 0.0
var is_charging := false
var charge_speed := 350.0

# ==================== RESOURCES ====================

var tex_normal = preload("res://Scenes/Main/Enemy/Sprites/enemy_normal.png")
var tex_fast = preload("res://Scenes/Main/Enemy/Sprites/enemy_fast.png")
var tex_tank = preload("res://Scenes/Main/Enemy/Sprites/enemy_tank.png")
var powerup_scene = preload("res://Scenes/PowerUp/powerup.tscn")
var death_sound = preload("res://Sounds/enemy_death.wav")

# ==================== INITIALIZATION ====================

func _ready() -> void:
	add_to_group("enemy")
	if not player:
		player = get_tree().get_first_node_in_group("player")

# Configure stats and appearance based on type
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
		"boss":
			speed = 70.0
			health = 40
			score_value = 100
			damage = 3
			is_boss = true
			$Sprite2D.texture = tex_tank
			$Sprite2D.scale = Vector2(2.0, 2.0)
			$Sprite2D.modulate = Color(1.0, 0.3, 0.3)
			if $CollisionShape2D.shape is CircleShape2D:
				$CollisionShape2D.shape = $CollisionShape2D.shape.duplicate()
				$CollisionShape2D.shape.radius *= 2.0
	
	max_health = health
	$Sprite2D.hframes = 4
	$Sprite2D.vframes = 4

# ==================== GAME LOOP ====================

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	
	var direction = (player.global_position - global_position).normalized()
	
	# Boss periodic charge attack
	if is_boss:
		boss_charge_timer += delta
		if boss_charge_timer >= boss_charge_cooldown and not is_charging:
			_boss_charge(direction)
		elif not is_charging:
			velocity = direction * speed
	else:
		velocity = direction * speed
	
	move_and_slide()
	
	# Deal contact damage when close enough
	var contact_dist = 50.0 if is_boss else 30.0
	if global_position.distance_to(player.global_position) < contact_dist:
		if player.has_method("take_damage"):
			player.take_damage(damage)

# ==================== BOSS CHARGE ====================

func _boss_charge(direction: Vector2) -> void:
	is_charging = true
	
	# White flash warning before charge
	$Sprite2D.modulate = Color.WHITE
	await get_tree().create_timer(0.4).timeout
	$Sprite2D.modulate = Color(1.0, 0.3, 0.3)
	
	velocity = direction * charge_speed
	await get_tree().create_timer(0.6).timeout
	
	is_charging = false
	boss_charge_timer = 0.0

# ==================== DAMAGE ====================

func take_damage(amount: int) -> void:
	health -= amount
	
	if health <= 0:
		_die()
	else:
		_hit_flash()

func _die() -> void:
	var main = get_tree().current_scene
	
	# Add score
	if main.has_method("add_score"):
		main.add_score(score_value)
	
	# Notify wave system for boss kill
	if is_boss and main.has_method("on_boss_killed"):
		main.on_boss_killed()
	
	# Play death sound on main scene (persists after queue_free)
	var audio = AudioStreamPlayer.new()
	audio.stream = death_sound
	audio.volume_db = -5 if is_boss else -12
	audio.pitch_scale = 0.6 if is_boss else 1.0
	main.add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)
	
	# Drop power-ups: boss drops all 3, others 30% chance for one
	_drop_powerups(main)
	
	queue_free()

func _hit_flash() -> void:
	var original_color = $Sprite2D.modulate
	$Sprite2D.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		$Sprite2D.modulate = original_color

# ==================== POWER-UP DROPS ====================

func _drop_powerups(main: Node) -> void:
	if is_boss:
		for ptype in ["heal", "fire_rate", "damage"]:
			var powerup = powerup_scene.instantiate()
			powerup.setup(ptype)
			powerup.global_position = global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
			main.call_deferred("add_child", powerup)
	elif randf() < 0.3:
		var powerup = powerup_scene.instantiate()
		powerup.setup(["heal", "fire_rate", "damage"].pick_random())
		powerup.global_position = global_position
		main.call_deferred("add_child", powerup)
