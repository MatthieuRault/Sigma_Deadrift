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
var current_weapon := "pistol"  # pistol, shotgun, sniper
var weapons := ["pistol", "shotgun", "sniper"]
var weapon_index := 0

# Weapon stats (damage, cooldown, speed, count, spread, piercing)
var weapon_data := {
	"pistol":  {"damage": 1, "cooldown": 0.15, "speed": 500.0, "count": 1, "spread": 0.0, "piercing": false},
	"shotgun": {"damage": 1, "cooldown": 0.5,  "speed": 400.0, "count": 5, "spread": 0.4, "piercing": false},
	"sniper":  {"damage": 5, "cooldown": 1.0,  "speed": 800.0, "count": 1, "spread": 0.0, "piercing": true},
}

# Grenade
var grenade_scene : PackedScene
var can_grenade := true
var grenade_cooldown := 2.0

# Health
var health := 5
var invincible := false

# Base stats
var base_weapon_data := {}
var damage_buff_active := false
var fire_rate_buff_active := false

# Sounds
var shoot_sound = preload("res://Sounds/shoot.wav")
var hit_sound = preload("res://Sounds/player_hit.wav")

@onready var sprite = $Soldier

func _ready() -> void:
	add_to_group("player")
	sprite.play("idle")
	sprite.scale = Vector2(1, 1)
	
	for w in weapon_data:
		base_weapon_data[w] = weapon_data[w].duplicate()
	
	if ResourceLoader.exists("res://Scenes/Grenade/grenade.tscn"):
		grenade_scene = load("res://Scenes/Grenade/grenade.tscn")

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
	
	# Switch weapon mouse wheel
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			switch_weapon(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			switch_weapon(1)
	
	# Switch weapon
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			set_weapon(0)
		elif event.keycode == KEY_2:
			set_weapon(1)
		elif event.keycode == KEY_3:
			set_weapon(2)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and can_shoot:
			shoot()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and can_grenade:
			throw_grenade()
			
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE and can_dash and direction != Vector2.ZERO:
			dash()

func switch_weapon(dir: int) -> void:
	weapon_index = wrapi(weapon_index + dir, 0, weapons.size())
	current_weapon = weapons[weapon_index]
	_notify_weapon_change()

func set_weapon(index: int) -> void:
	if index >= 0 and index < weapons.size():
		weapon_index = index
		current_weapon = weapons[weapon_index]
		_notify_weapon_change()

func _notify_weapon_change() -> void:
	var main = get_tree().current_scene
	if main.has_method("on_weapon_changed"):
		main.on_weapon_changed(current_weapon)

# Shoot a bullet toward the mouse direction
func shoot() -> void:
	if not bullet_scene:
		return
		
	var data = weapon_data[current_weapon]
	var base_angle = sprite.rotation
	
	for i in data["count"]:
		var bullet = bullet_scene.instantiate()
		bullet.damage = data["damage"]
		bullet.speed = data["speed"]
		
		# Enable piercing bullet
		if bullet.has_method("set_piercing"):
			bullet.set_piercing(data["piercing"])
		
		# Spread angle shotgun shots
		var angle_offset := 0.0
		if data["count"] > 1:
			angle_offset = lerp(-data["spread"] / 2.0, data["spread"] / 2.0, float(i) / (data["count"] - 1))
		
		var final_angle = base_angle + angle_offset
		
		get_parent().add_child(bullet)
		bullet.global_position = sprite.global_position + Vector2.RIGHT.rotated(final_angle) * 20
		bullet.rotation = final_angle
	
	# Shoot animation and sound
	sprite.play("shoot")
	_play_sound(shoot_sound, -10)
	
	await get_tree().create_timer(0.1).timeout
	sprite.play("idle")
	
	# Shoot cooldown
	can_shoot = false
	await get_tree().create_timer(data["cooldown"]).timeout
	can_shoot = true
	
func throw_grenade() -> void:
	if not grenade_scene:
		return
	
	can_grenade = false
	
	var grenade = grenade_scene.instantiate()
	grenade.global_position = global_position
	grenade.target_position = get_global_mouse_position()
	get_parent().add_child(grenade)
	
	await get_tree().create_timer(grenade_cooldown).timeout
	can_grenade = true
	
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
			if fire_rate_buff_active:
				return
			fire_rate_buff_active = true
			for w in weapon_data:
				weapon_data[w]["cooldown"] = base_weapon_data[w]["cooldown"] * 0.4
			await get_tree().create_timer(5.0).timeout
			for w in weapon_data:
				weapon_data[w]["cooldown"] = base_weapon_data[w]["cooldown"]
			fire_rate_buff_active = false
		"damage":
			if damage_buff_active:
				return
			damage_buff_active = true
			for w in weapon_data:
				weapon_data[w]["damage"] = base_weapon_data[w]["damage"] * 3
			await get_tree().create_timer(5.0).timeout
			for w in weapon_data:
				weapon_data[w]["damage"] = base_weapon_data[w]["damage"]
			damage_buff_active = false

# Helper to play a one-shot sound effect
func _play_sound(sound: AudioStream, volume: float = -10) -> void:
	var audio = AudioStreamPlayer.new()
	audio.stream = sound
	audio.volume_db = volume
	add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)
