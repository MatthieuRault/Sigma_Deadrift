extends CharacterBody2D

# Movement
@export var bullet_scene : PackedScene
var speed : float = 220.0
var direction := Vector2.ZERO

# Dash
var dash_speed := 600.0
var dash_duration := 0.15
var dash_cooldown := 0.8
var can_dash := true
var is_dashing := false

# Combat
var can_shoot := true
var bullet_damage := 1
var shoot_cooldown := 0.15

# Health
var health := 5
var invincible := false

# Sounds
var shoot_sound = preload("res://Sounds/shoot.wav")
var hit_sound = preload("res://Sounds/player_hit.wav")

@onready var sprite = $Soldier

func _ready() -> void:
	add_to_group("player")
	sprite.play("idle")
	sprite.scale = Vector2(1, 1)

func _physics_process(delta: float) -> void:
	# Dash
	if is_dashing:
		move_and_slide()
		return
	
	# Move the player
	velocity = direction * speed
	move_and_slide()
	
	# Rotate the sprite toward the mouse
	var mouse_pos = get_global_mouse_position()
	var angle = global_position.angle_to_point(mouse_pos)
	sprite.rotation = angle

func _input(event: InputEvent) -> void:
	direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and can_shoot:
			shoot()
			
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE and can_dash and direction != Vector2.ZERO:
			dash()

# Shoot a bullet toward the mouse direction
func shoot() -> void:
	if not bullet_scene:
		return
	
	var bullet = bullet_scene.instantiate()
	bullet.damage = bullet_damage
	get_parent().add_child(bullet)
	bullet.global_position = sprite.global_position + Vector2.RIGHT.rotated(sprite.rotation) * 20
	bullet.rotation = sprite.rotation
	
	# Shoot animation and sound
	sprite.play("shoot")
	_play_sound(shoot_sound, -10)
	
	await get_tree().create_timer(0.1).timeout
	sprite.play("idle")
	
	# Shoot cooldown
	can_shoot = false
	await get_tree().create_timer(shoot_cooldown).timeout
	can_shoot = true
	
func dash() -> void:
	is_dashing = true
	can_dash = false
	invincible = true
	
	# Ignore enemies during dash
	set_collision_mask_value(2, false)
	set_collision_layer_value(1, false)
	
	velocity = direction.normalized() * dash_speed
	
	# Player semi-transparent while dashing
	sprite.modulate = Color(1, 1, 1, 0.4)
	
	await get_tree().create_timer(dash_duration).timeout
	
	is_dashing = false
	set_collision_mask_value(2, true)
	sprite.modulate = Color.WHITE
	invincible = false
	
	# Cooldown timer ea dash
	await get_tree().create_timer(dash_cooldown).timeout
	can_dash = true

# Take damage from enemies, with knockback and invincibility frames
func take_damage(amount: int) -> void:
	if invincible or health <= 0:
		return
	
	health -= amount
	_play_sound(hit_sound, -15)
	
	# Knockback away from nearest enemy
	var nearest_enemy = get_tree().get_first_node_in_group("enemy")
	if nearest_enemy:
		var knockback_dir = (global_position - nearest_enemy.global_position).normalized()
		velocity = knockback_dir * 300
		move_and_slide()
	
	# Invincibility frames with red flash
	sprite.modulate = Color.RED
	invincible = true
	await get_tree().create_timer(0.75).timeout
	sprite.modulate = Color.WHITE
	invincible = false
	
	if health <= 0:
		health = 0
		die()

# Player death - hide and disable controls
func die() -> void:
	var main = get_tree().current_scene
	if main.has_method("game_over"):
		main.game_over()
	visible = false
	set_physics_process(false)
	set_process_input(false)

# Apply a power-up effect with temporary duration
func apply_powerup(type: String) -> void:
	match type:
		"heal":
			health = min(health + 2, 5)
		"fire_rate":
			shoot_cooldown = 0.05
			await get_tree().create_timer(5.0).timeout
			shoot_cooldown = 0.15
		"damage":
			bullet_damage = 3
			await get_tree().create_timer(5.0).timeout
			bullet_damage = 1

# Helper to play a one-shot sound effect
func _play_sound(sound: AudioStream, volume: float = -10) -> void:
	var audio = AudioStreamPlayer.new()
	audio.stream = sound
	audio.volume_db = volume
	add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)
