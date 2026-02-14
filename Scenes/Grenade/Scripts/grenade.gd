extends Area2D

# ==================== MOVEMENT ====================

var target_position := Vector2.ZERO
var start_position := Vector2.ZERO
var travel_time := 0.6
var velocity := Vector2.ZERO
var timer := 0.0
var fuse_time := 0.8

# ==================== EXPLOSION ====================

var explosion_radius := 40.0
var explosion_damage := 4
var exploded := false

# ==================== MAP BOUNDS ====================

var map_size := Vector2(960, 540)
var wall_thickness := 16.0

# ==================== INITIALIZATION ====================

func _ready() -> void:
	start_position = global_position
	if $Sprite2D:
		$Sprite2D.scale = Vector2(0.55, 0.55)
	
	# Calculate initial velocity toward target
	velocity = (target_position - start_position) / travel_time
	
	# Detect crate collisions for bouncing
	body_entered.connect(_on_body_entered)

# ==================== GAME LOOP ====================

func _physics_process(delta: float) -> void:
	if exploded:
		return
	
	timer += delta
	
	if timer >= fuse_time:
		_explode()
		return
	
	# Move grenade
	global_position += velocity * delta
	
	# Bounce off map walls
	_bounce_off_walls()
	
	# Arc effect (scale up then down to simulate height)
	var t = timer / fuse_time
	var arc = sin(t * PI)
	var base_scale = 0.5
	scale = Vector2(base_scale + arc * 0.3, base_scale + arc * 0.3)

# ==================== COLLISION ====================

func _bounce_off_walls() -> void:
	if global_position.x < wall_thickness:
		global_position.x = wall_thickness
		velocity.x = -velocity.x
	elif global_position.x > map_size.x - wall_thickness:
		global_position.x = map_size.x - wall_thickness
		velocity.x = -velocity.x
	
	if global_position.y < wall_thickness:
		global_position.y = wall_thickness
		velocity.y = -velocity.y
	elif global_position.y > map_size.y - wall_thickness:
		global_position.y = map_size.y - wall_thickness
		velocity.y = -velocity.y

# Bounce off crates and obstacles
func _on_body_entered(body: Node) -> void:
	if body is StaticBody2D:
		var to_body = (body.global_position - global_position).normalized()
		if abs(to_body.x) > abs(to_body.y):
			velocity.x = -velocity.x
		else:
			velocity.y = -velocity.y
		global_position -= to_body * 5

# ==================== EXPLOSION ====================

func _explode() -> void:
	exploded = true
	
	# Deal AoE damage with distance falloff
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy):
			var dist = global_position.distance_to(enemy.global_position)
			if dist <= explosion_radius and enemy.has_method("take_damage"):
				var falloff = 1.0 - (dist / explosion_radius) * 0.5
				enemy.take_damage(int(explosion_damage * falloff))
	
	# Screen shake
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("shake_camera"):
		player.shake_camera(8.0, 0.3)
	
	# Visual and sound
	_show_explosion_visual()
	_play_explosion_sound()
	
	# Hide sprite and remove after visual fades
	if $Sprite2D:
		$Sprite2D.visible = false
	await get_tree().create_timer(0.3).timeout
	queue_free()

func _show_explosion_visual() -> void:
	var canvas = Node2D.new()
	canvas.global_position = global_position
	get_tree().current_scene.add_child(canvas)
	
	var drawer = ExplosionDrawer.new()
	drawer.radius = explosion_radius
	canvas.add_child(drawer)
	
	var tween = canvas.create_tween()
	tween.tween_property(canvas, "modulate:a", 0.0, 0.3)
	tween.tween_callback(canvas.queue_free)

func _play_explosion_sound() -> void:
	if ResourceLoader.exists("res://Sounds/enemy_death.wav"):
		var audio = AudioStreamPlayer.new()
		audio.stream = load("res://Sounds/enemy_death.wav")
		audio.volume_db = -5
		audio.pitch_scale = 0.6
		get_tree().current_scene.add_child(audio)
		audio.play()
		audio.finished.connect(audio.queue_free)

# ==================== EXPLOSION DRAWER ====================

class ExplosionDrawer extends Node2D:
	var radius := 40.0
	
	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.6, 0.1, 0.5))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(1.0, 0.3, 0.0, 0.8), 2.0)
