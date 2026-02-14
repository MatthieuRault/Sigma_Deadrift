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

# ==================== RANGED ====================

var shoot_range := 150.0
var shoot_cooldown := 2.0
var shoot_timer := 0.0
var bullet_speed := 200.0
var bullet_damage := 1

# ==================== SPLITTER ====================

var split_level := 0  # 0 = full size, 1 = small split

# ==================== EXPLODER ====================

var explode_range := 35.0
var explosion_radius := 50.0
var explosion_damage := 3
var is_exploding := false
var fuse_timer := 0.0
var fuse_duration := 0.8

# ==================== GHOST ====================

var ghost_visible := true
var ghost_timer := 0.0
var ghost_visible_duration := 2.0
var ghost_invisible_duration := 2.5

# ==================== SPRITE ANIMATION ====================

var anim_timer := 0.0
var anim_frame := 0
var anim_speed := 0.15  # seconds per frame

# ==================== RESOURCES ====================

var tex_normal = preload("res://Scenes/Main/Enemy/Sprites/mob_normal.png")
var tex_fast = preload("res://Scenes/Main/Enemy/Sprites/mob_fast.png")
var tex_tank = preload("res://Scenes/Main/Enemy/Sprites/mob_tank.png")
var tex_ranged = preload("res://Scenes/Main/Enemy/Sprites/mob_ranged.png")
var tex_splitter = preload("res://Scenes/Main/Enemy/Sprites/mob_splitter.png")
var tex_exploder = preload("res://Scenes/Main/Enemy/Sprites/mob_exploder.png")
var tex_ghost = preload("res://Scenes/Main/Enemy/Sprites/mob_ghost.png")
var tex_boss = preload("res://Scenes/Main/Enemy/Sprites/mob_boss.png")
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
			anim_speed = 0.08
		"tank":
			speed = 50.0
			health = 8
			score_value = 30
			damage = 2
			$Sprite2D.texture = tex_tank
			anim_speed = 0.25
		"ranged":
			speed = 60.0
			health = 2
			score_value = 20
			damage = 1
			$Sprite2D.texture = tex_ranged
		"splitter":
			speed = 80.0
			health = 4
			score_value = 20
			damage = 1
			$Sprite2D.texture = tex_splitter
		"exploder":
			speed = 130.0
			health = 2
			score_value = 25
			damage = 1
			$Sprite2D.texture = tex_exploder
			anim_speed = 0.1
		"ghost":
			speed = 90.0
			health = 3
			score_value = 25
			damage = 2
			$Sprite2D.texture = tex_ghost
		"boss":
			speed = 70.0
			health = 40
			score_value = 100
			damage = 3
			is_boss = true
			$Sprite2D.texture = tex_boss
			$Sprite2D.scale = Vector2(3.5, 3.5)
			$Sprite2D.modulate = Color(1.0, 0.3, 0.3)
			if $CollisionShape2D.shape is CircleShape2D:
				$CollisionShape2D.shape = $CollisionShape2D.shape.duplicate()
				$CollisionShape2D.shape.radius *= 2.0
	
	max_health = health
	$Sprite2D.hframes = 4
	$Sprite2D.vframes = 1
	$Sprite2D.frame = 0
	
	if not is_boss:
		$Sprite2D.scale = Vector2(1.5, 1.5)
	
	# Splitter children are smaller
	if enemy_type == "splitter" and split_level > 0:
		$Sprite2D.scale = Vector2(0.9, 0.9)
		if $CollisionShape2D.shape is CircleShape2D:
			$CollisionShape2D.shape = $CollisionShape2D.shape.duplicate()
			$CollisionShape2D.shape.radius *= 0.6

# ==================== GAME LOOP ====================

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	
	var direction = (player.global_position - global_position).normalized()
	var dist_to_player = global_position.distance_to(player.global_position)
	
	# Flip sprite based on movement direction
	$Sprite2D.flip_h = direction.x < 0
	
	# Animate sprite frames
	_animate(delta)
	
	# Type-specific behavior
	match enemy_type:
		"ranged":
			_process_ranged(delta, direction, dist_to_player)
		"exploder":
			_process_exploder(delta, direction, dist_to_player)
		"ghost":
			_process_ghost(delta, direction)
		_:
			_process_default(delta, direction)
	
	move_and_slide()
	
	# Contact damage
	if enemy_type != "exploder" or not is_exploding:
		var contact_dist = 50.0 if is_boss else 25.0
		if dist_to_player < contact_dist:
			if player.has_method("take_damage"):
				player.take_damage(damage)

# ==================== SPRITE ANIMATION ====================

func _animate(delta: float) -> void:
	anim_timer += delta
	if anim_timer >= anim_speed:
		anim_timer = 0.0
		anim_frame = (anim_frame + 1) % 4
		$Sprite2D.frame = anim_frame

# ==================== DEFAULT MOVEMENT ====================

func _process_default(delta: float, direction: Vector2) -> void:
	if is_boss:
		boss_charge_timer += delta
		if boss_charge_timer >= boss_charge_cooldown and not is_charging:
			_boss_charge(direction)
		elif not is_charging:
			velocity = direction * speed
	else:
		velocity = direction * speed

# ==================== BOSS CHARGE ====================

func _boss_charge(direction: Vector2) -> void:
	is_charging = true
	
	$Sprite2D.modulate = Color.WHITE
	await get_tree().create_timer(0.4).timeout
	if not is_instance_valid(self):
		return
	$Sprite2D.modulate = Color(1.0, 0.3, 0.3)
	
	velocity = direction * charge_speed
	await get_tree().create_timer(0.6).timeout
	if not is_instance_valid(self):
		return
	
	is_charging = false
	boss_charge_timer = 0.0

# ==================== RANGED BEHAVIOR ====================

func _process_ranged(delta: float, direction: Vector2, dist: float) -> void:
	shoot_timer += delta
	
	# Keep distance from player
	if dist > shoot_range + 30:
		velocity = direction * speed
	elif dist < shoot_range - 30:
		velocity = -direction * speed * 0.5
	else:
		# Strafe at ideal range
		velocity = direction.rotated(PI / 2) * speed * 0.3
	
	# Shoot when in range
	if dist <= shoot_range + 50 and shoot_timer >= shoot_cooldown:
		shoot_timer = 0.0
		_shoot_projectile(direction)

func _shoot_projectile(direction: Vector2) -> void:
	var projectile = Area2D.new()
	projectile.collision_layer = 0
	projectile.collision_mask = 1  # detect player
	
	# Purple magic bolt visual
	var color_rect = ColorRect.new()
	color_rect.size = Vector2(6, 6)
	color_rect.position = Vector2(-3, -3)
	color_rect.color = Color(0.8, 0.2, 1.0)
	projectile.add_child(color_rect)
	
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 4.0
	col.shape = shape
	projectile.add_child(col)
	
	projectile.global_position = global_position
	
	var script = GDScript.new()
	script.source_code = """extends Area2D

var dir := Vector2.ZERO
var spd := 200.0
var dmg := 1
var lifetime := 0.0

func _physics_process(delta: float) -> void:
	position += dir * spd * delta
	lifetime += delta
	if lifetime > 4.0:
		queue_free()

func _ready() -> void:
	body_entered.connect(_on_hit)

func _on_hit(body: Node2D) -> void:
	if body.is_in_group(\"player\") and body.has_method(\"take_damage\"):
		body.take_damage(dmg)
	queue_free()
"""
	script.reload()
	projectile.set_script(script)
	projectile.dir = direction
	projectile.spd = bullet_speed
	projectile.dmg = bullet_damage
	
	get_tree().current_scene.add_child(projectile)

# ==================== EXPLODER BEHAVIOR ====================

func _process_exploder(delta: float, direction: Vector2, dist: float) -> void:
	if is_exploding:
		fuse_timer += delta
		# Flash rapidly during fuse
		$Sprite2D.modulate = Color.WHITE if fmod(fuse_timer, 0.15) < 0.075 else Color(1.0, 0.3, 0.0)
		velocity = Vector2.ZERO
		if fuse_timer >= fuse_duration:
			_explode()
		return
	
	# Rush toward player
	velocity = direction * speed
	
	# Start fuse when close
	if dist < explode_range:
		is_exploding = true
		fuse_timer = 0.0

func _explode() -> void:
	var main = get_tree().current_scene
	
	# Damage nearby enemies
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == self:
			continue
		if is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= explosion_radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(explosion_damage)
	
	# Damage player
	if is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		if dist <= explosion_radius and player.has_method("take_damage"):
			var falloff = 1.0 - (dist / explosion_radius) * 0.5
			player.take_damage(int(explosion_damage * falloff))
		if player.has_method("shake_camera"):
			player.shake_camera(6.0, 0.25)
	
	# Effects
	Effects.spawn_explosion(main, global_position, explosion_radius)
	
	if main.has_method("add_score"):
		main.add_score(score_value)
	
	var audio = AudioStreamPlayer.new()
	audio.stream = death_sound
	audio.volume_db = -5
	audio.pitch_scale = 0.6
	main.add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)
	
	queue_free()

# ==================== GHOST BEHAVIOR ====================

func _process_ghost(delta: float, direction: Vector2) -> void:
	ghost_timer += delta
	
	var cycle = ghost_visible_duration if ghost_visible else ghost_invisible_duration
	
	if ghost_timer >= cycle:
		ghost_timer = 0.0
		ghost_visible = not ghost_visible
		
		if ghost_visible:
			$Sprite2D.modulate = Color(1, 1, 1, 1)
			collision_layer = 2  # hittable again
		else:
			$Sprite2D.modulate = Color(1, 1, 1, 0.15)
			collision_layer = 0  # bullets pass through
	
	velocity = direction * speed

# ==================== DAMAGE ====================

func take_damage(amount: int) -> void:
	# Ghost immune when invisible
	if enemy_type == "ghost" and not ghost_visible:
		return
	
	health -= amount
	
	if health <= 0:
		_die()
	else:
		_hit_flash()

func _die() -> void:
	var main = get_tree().current_scene
	
	if main.has_method("add_score"):
		main.add_score(score_value)
	
	if is_boss and main.has_method("on_boss_killed"):
		main.on_boss_killed()
	
	var audio = AudioStreamPlayer.new()
	audio.stream = death_sound
	audio.volume_db = -5 if is_boss else -12
	audio.pitch_scale = 0.6 if is_boss else 1.0
	main.add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)
	
	# Splitter: spawn 2 smaller copies
	if enemy_type == "splitter" and split_level == 0:
		_spawn_splits(main)
	
	_drop_powerups(main)
	
	# Death particles with type-specific color
	Effects.spawn_death(main, global_position, _get_death_color())
	
	queue_free()

func _get_death_color() -> Color:
	match enemy_type:
		"normal", "fast", "tank":
			return Color(0.2, 0.7, 0.2)  # Green (orcs)
		"ranged":
			return Color(0.8, 0.2, 1.0)  # Purple (shaman)
		"splitter":
			return Color(0.9, 0.9, 0.7)  # Bone white
		"exploder":
			return Color(1.0, 0.4, 0.1)  # Orange fire
		"ghost":
			return Color(0.5, 0.5, 0.8)  # Ghostly blue
		"boss":
			return Color(1.0, 0.3, 0.3)  # Boss red
		_:
			return Color.RED

func _hit_flash() -> void:
	var original_color = $Sprite2D.modulate
	$Sprite2D.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		$Sprite2D.modulate = original_color

# ==================== SPLITTER ====================

func _spawn_splits(main: Node) -> void:
	var enemy_scene = preload("res://Scenes/Main/Enemy/enemy.tscn")
	for i in 2:
		var split = enemy_scene.instantiate()
		split.setup("splitter")
		split.split_level = 1
		split.health = 2
		split.max_health = 2
		split.speed = 120.0
		split.score_value = 10
		split.damage = 1
		var offset = Vector2(randf_range(-15, 15), randf_range(-15, 15))
		split.global_position = global_position + offset
		main.call_deferred("add_child", split)

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
