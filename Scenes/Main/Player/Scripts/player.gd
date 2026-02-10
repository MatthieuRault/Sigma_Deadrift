extends CharacterBody2D
@export var bullet_scene : PackedScene

var can_shoot := true
var speed : float = 200.0
var direction := Vector2.ZERO
var health := 5
var invincible := false
var bullet_damage := 1
var shoot_cooldown := 0.15
@onready var sprite = $Soldier

func _ready() -> void:
	add_to_group("player")
	sprite.play("idle")
	sprite.scale = Vector2(1, 1)

func _physics_process(delta: float) -> void:
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

func shoot() -> void:
	if bullet_scene:
		var bullet = bullet_scene.instantiate()
		bullet.damage = bullet_damage
		get_parent().add_child(bullet)		
		bullet.global_position = sprite.global_position + Vector2.RIGHT.rotated(sprite.rotation) * 20
		bullet.rotation = sprite.rotation		
		sprite.play("shoot")
		await get_tree().create_timer(0.1).timeout
		sprite.play("idle")		
		can_shoot = false
		await get_tree().create_timer(shoot_cooldown).timeout
		can_shoot = true
		
func take_damage(amount: int) -> void:
	if invincible:
		return
	health -= amount
	
	# Damage feedback = red flash
	sprite.modulate = Color.RED
	invincible = true
	await get_tree().create_timer(0.5).timeout
	sprite.modulate = Color.WHITE
	invincible = false
	
	if health <= 0:
		health = 0
		die()

func die() -> void:
	var main = get_tree().current_scene
	if main.has_method("game_over"):
		main.game_over()
	visible = false
	set_physics_process(false)
	set_process_input(false)

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
