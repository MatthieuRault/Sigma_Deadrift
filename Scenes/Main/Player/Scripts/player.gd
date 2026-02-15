extends CharacterBody2D

# ==================== EXPORTS ====================

@export var bullet_scene : PackedScene

# ==================== MOVEMENT ====================

var base_speed : float = 220.0
var speed : float = 220.0
var direction := Vector2.ZERO

# ==================== DASH ====================

var dash_speed := 600.0
var dash_duration := 0.15
var dash_cooldown := 0.8
var can_dash := true
var is_dashing := false

# ==================== WEAPONS ====================

var can_shoot := true
var is_firing := false
var current_weapon := "pistol"
var weapons := ["pistol", "shotgun", "sniper", "assault", "minigun", "rocket"]
var weapon_index := 0

var weapon_data := {
	"pistol":  {"damage": 1, "cooldown": 0.15, "speed": 500.0, "count": 1, "spread": 0.0,  "piercing": false, "auto": false},
	"shotgun": {"damage": 1, "cooldown": 0.5,  "speed": 400.0, "count": 5, "spread": 0.4,  "piercing": false, "auto": false},
	"sniper":  {"damage": 5, "cooldown": 1.0,  "speed": 800.0, "count": 1, "spread": 0.0,  "piercing": true,  "auto": false},
	"assault": {"damage": 1, "cooldown": 0.08, "speed": 450.0, "count": 1, "spread": 0.06, "piercing": false, "auto": true},
	"minigun": {"damage": 1, "cooldown": 0.04, "speed": 400.0, "count": 1, "spread": 0.15, "piercing": false, "auto": true},
	"rocket":  {"damage": 8, "cooldown": 1.8,  "speed": 280.0, "count": 1, "spread": 0.0,  "piercing": false, "auto": false},
}

var base_weapon_data := {}
var damage_buff_active := false
var fire_rate_buff_active := false

# ==================== GRENADE ====================

var grenade_scene : PackedScene
var can_grenade := true
var grenade_cooldown := 2.0

# ==================== MINE ====================

var can_mine := true
var mine_cooldown := 4.0
var mine_damage := 5
var mine_radius := 45.0

# ==================== HEALTH ====================

var health := 5
var invincible := false

# ==================== SOUNDS ====================

var shoot_sound = preload("res://Sounds/shoot.wav")
var hit_sound = preload("res://Sounds/player_hit.wav")

# ==================== NODE REFERENCES ====================

@onready var sprite = $Soldier
@onready var camera = $Camera2D

# ==================== INITIALIZATION ====================

func _ready() -> void:
	add_to_group("player")
	sprite.play("idle")
	sprite.scale = Vector2(1, 1)
	
	# Set camera limits to map bounds
	if camera:
		camera.limit_left = 0
		camera.limit_top = 0
		camera.limit_right = 960
		camera.limit_bottom = 540
	
	# Save base weapon stats to prevent buff stacking
	for w in weapon_data:
		base_weapon_data[w] = weapon_data[w].duplicate()
	
	# Load grenade scene if available
	if ResourceLoader.exists("res://Scenes/Grenade/grenade.tscn"):
		grenade_scene = load("res://Scenes/Grenade/grenade.tscn")

# ==================== GAME LOOP ====================

func _physics_process(_delta) -> void:
	if is_dashing:
		move_and_slide()
		return
	
	# Minigun slows player while firing
	if current_weapon == "minigun" and is_firing:
		speed = base_speed * 0.35
	else:
		speed = base_speed
	
	velocity = direction * speed
	move_and_slide()
	
	# Flip
	var mouse_pos = get_global_mouse_position()
	sprite.flip_h = mouse_pos.x < global_position.x

	# Auto-fire weapons (assault, minigun)
	if can_shoot and weapon_data[current_weapon]["auto"] and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_shoot()

# ==================== INPUT ====================

func _input(event: InputEvent) -> void:
	direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# Weapon switch with mouse wheel
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_switch_weapon(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_switch_weapon(1)
	
	# Weapon switch with number keys
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			_set_weapon(0)
		elif event.keycode == KEY_2:
			_set_weapon(1)
		elif event.keycode == KEY_3:
			_set_weapon(2)
		elif event.keycode == KEY_4:
			_set_weapon(3)
		elif event.keycode == KEY_5:
			_set_weapon(4)
		elif event.keycode == KEY_6:
			_set_weapon(5)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# Non-auto weapons fire on click
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and can_shoot:
			_shoot()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and can_grenade:
			_throw_grenade()
		# Track firing state for auto weapons
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_firing = event.pressed
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE and can_dash and direction != Vector2.ZERO:
			_dash()
		elif event.keycode == KEY_F and can_mine:
			_place_mine()

# ==================== WEAPONS ====================

func _switch_weapon(dir: int) -> void:
	weapon_index = wrapi(weapon_index + dir, 0, weapons.size())
	current_weapon = weapons[weapon_index]
	is_firing = false
	_notify_weapon_change()

func _set_weapon(index: int) -> void:
	if index >= 0 and index < weapons.size():
		weapon_index = index
		current_weapon = weapons[weapon_index]
		is_firing = false
		_notify_weapon_change()

func _notify_weapon_change() -> void:
	var main = get_tree().current_scene
	if main.has_method("on_weapon_changed"):
		main.on_weapon_changed(current_weapon)

func _shoot() -> void:
	if not bullet_scene:
		return
	
	var data = weapon_data[current_weapon]
	var mouse_pos = get_global_mouse_position()
	var base_angle = (mouse_pos - global_position).angle()
	
	# Spawn bullets (multiple for shotgun)
	for i in data["count"]:
		var bullet = bullet_scene.instantiate()
		bullet.damage = data["damage"]
		bullet.speed = data["speed"]
		
		if bullet.has_method("set_piercing"):
			bullet.set_piercing(data["piercing"])
			
		# Set bullet type for rockets
		if current_weapon == "rocket":
			bullet.set_type("rocket")
		else:
			bullet.set_type("player")
		
		# Calculate spread angle for multi-bullet weapons
		var angle_offset := 0.0
		if data["count"] > 1:
			angle_offset = lerp(-data["spread"] / 2.0, data["spread"] / 2.0, float(i) / (data["count"] - 1))
		
		# Add random spread for auto weapons
		if data["spread"] > 0 and data["count"] == 1:
			angle_offset = randf_range(-data["spread"], data["spread"])
		
		var final_angle = base_angle + angle_offset
		get_parent().add_child(bullet)
		bullet.global_position = global_position + Vector2.RIGHT.rotated(final_angle) * 20
		bullet.rotation = final_angle
	
	# Muzzle flash
	var flash_pos = global_position + Vector2.RIGHT.rotated(base_angle) * 20
	Effects.spawn_muzzle_flash(get_parent(), flash_pos, base_angle)
	
	# Animation and sound
	sprite.play("shoot")
	_play_sound(shoot_sound, -10)
	await get_tree().create_timer(0.1).timeout
	sprite.play("idle")
	
	# Weapon-specific cooldown
	can_shoot = false
	await get_tree().create_timer(data["cooldown"]).timeout
	can_shoot = true

# ==================== GRENADE ====================

func _throw_grenade() -> void:
	if not grenade_scene:
		return
	
	can_grenade = false
	var grenade = grenade_scene.instantiate()
	grenade.global_position = global_position
	grenade.target_position = get_global_mouse_position()
	get_parent().add_child(grenade)
	
	await get_tree().create_timer(grenade_cooldown).timeout
	can_grenade = true

# ==================== MINE ====================

func _place_mine() -> void:
	can_mine = false
	
	var mine = Area2D.new()
	mine.global_position = global_position
	mine.collision_layer = 0
	mine.collision_mask = 2  # detect enemies
	
	# Visual: small dark disc
	var visual = Node2D.new()
	mine.add_child(visual)
	
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 12.0
	col.shape = shape
	mine.add_child(col)
	
	# Mine script
	var script = GDScript.new()
	script.source_code = """extends Area2D

var armed := false
var mine_damage := 5
var mine_radius := 45.0
var lifetime := 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Arm after short delay
	await get_tree().create_timer(0.5).timeout
	armed = true

func _physics_process(delta: float) -> void:
	lifetime += delta
	# Despawn after 15 seconds
	if lifetime > 15.0:
		queue_free()

func _draw() -> void:
	# Draw mine visual
	draw_circle(Vector2.ZERO, 6, Color(0.3, 0.3, 0.3))
	draw_circle(Vector2.ZERO, 3, Color(0.8, 0.2, 0.2) if armed else Color(0.5, 0.5, 0.5))
	draw_arc(Vector2.ZERO, 6, 0, TAU, 16, Color(0.5, 0.5, 0.5), 1.0)

func _on_body_entered(body: Node2D) -> void:
	if not armed:
		return
	if not body.is_in_group(\"enemy\"):
		return
	_explode()

func _explode() -> void:
	var main = get_tree().current_scene
	
	# AoE damage to all enemies in radius
	for enemy in get_tree().get_nodes_in_group(\"enemy\"):
		if is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= mine_radius:
			if enemy.has_method(\"take_damage\"):
				var dist = global_position.distance_to(enemy.global_position)
				var falloff = 1.0 - (dist / mine_radius) * 0.5
				enemy.take_damage(int(mine_damage * falloff))
	
	# Self-damage to player
	var player = get_tree().get_first_node_in_group(\"player\")
	if player and is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		if dist <= mine_radius and player.has_method(\"take_damage\"):
			var falloff = 1.0 - (dist / mine_radius) * 0.5
			player.take_damage(int(mine_damage * falloff))
		if player.has_method(\"shake_camera\"):
			player.shake_camera(5.0, 0.2)
	
	Effects.spawn_explosion(main, global_position, mine_radius)
	queue_free()
"""
	script.reload()
	mine.set_script(script)
	mine.mine_damage = mine_damage
	mine.mine_radius = mine_radius
	
	get_parent().add_child(mine)
	
	_play_sound(shoot_sound, -15)
	
	await get_tree().create_timer(mine_cooldown).timeout
	can_mine = true

# ==================== DASH ====================

func _dash() -> void:
	is_dashing = true
	can_dash = false
	invincible = true
	
	# Disable collision with enemies in both directions
	set_collision_mask_value(2, false)
	set_collision_layer_value(1, false)
	
	velocity = direction.normalized() * dash_speed
	shake_camera(3.0, 0.1)
	sprite.modulate = Color(1, 1, 1, 0.4)
	
	await get_tree().create_timer(dash_duration).timeout
	
	is_dashing = false
	set_collision_mask_value(2, true)
	set_collision_layer_value(1, true)
	sprite.modulate = Color.WHITE
	invincible = false
	
	await get_tree().create_timer(dash_cooldown).timeout
	can_dash = true

# ==================== DAMAGE & HEALTH ====================

func take_damage(amount: int) -> void:
	if invincible or health <= 0:
		return
	
	health -= amount
	_play_sound(hit_sound, -15)
	shake_camera(6.0, 0.25)
	
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
		_die()

func _die() -> void:
	var main = get_tree().current_scene
	if main.has_method("game_over"):
		main.game_over()
	visible = false
	set_physics_process(false)
	set_process_input(false)

# ==================== POWER-UPS ====================

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

# ==================== UTILITY ====================

func _play_sound(sound: AudioStream, volume: float = -10) -> void:
	var audio = AudioStreamPlayer.new()
	audio.stream = sound
	audio.volume_db = volume
	add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)

func shake_camera(intensity: float = 5.0, duration: float = 0.2) -> void:
	if not camera:
		return
	var shake_timer := 0.0
	while shake_timer < duration:
		camera.offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		shake_timer += get_process_delta_time()
		await get_tree().process_frame
	camera.offset = Vector2.ZERO
