extends Area2D

var target_position := Vector2.ZERO
var start_position := Vector2.ZERO
var travel_time := 0.6
var timer := 0.0
var exploded := false
var velocity := Vector2.ZERO
var fuse_time := 0.8 
# Explosion settings
var explosion_radius := 40.0
var explosion_damage := 4

func _ready() -> void:
	start_position = global_position
	if $Sprite2D:
		$Sprite2D.scale = Vector2(0.55, 0.55)
		
	var direction = (target_position - start_position)
	velocity = direction / travel_time
	
	# Detect collision
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if exploded:
		return
	
	timer += delta
	# Explode when fuse time expires
	if timer >= fuse_time:
		explode()
		return
	
	global_position += velocity * delta
	# Bounce off map walls
	var map_size = Vector2(960, 540)
	var margin = 16.0
	
	if global_position.x < margin:
		global_position.x = margin
		velocity.x = -velocity.x
	elif global_position.x > map_size.x - margin:
		global_position.x = map_size.x - margin
		velocity.x = -velocity.x
	
	if global_position.y < margin:
		global_position.y = margin
		velocity.y = -velocity.y
	elif global_position.y > map_size.y - margin:
		global_position.y = map_size.y - margin
		velocity.y = -velocity.y
	
	var t = timer / fuse_time
	var arc = sin(t * PI)
	var base_scale = 0.5
	scale = Vector2(base_scale + arc * 0.3, base_scale + arc * 0.3)

func explode() -> void:
	exploded = true
	# Apply damage to all enemies within explosion radius
	var enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if is_instance_valid(enemy):
			var dist = global_position.distance_to(enemy.global_position)
			if dist <= explosion_radius:
				if enemy.has_method("take_damage"):
					var falloff = 1.0 - (dist / explosion_radius) * 0.5
					enemy.take_damage(int(explosion_damage * falloff))
					
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("shake_camera"):
		player.shake_camera(8.0, 0.3)
		
	_show_explosion_visual()
	
	if ResourceLoader.exists("res://Sounds/enemy_death.wav"):
		var audio = AudioStreamPlayer.new()
		audio.stream = load("res://Sounds/enemy_death.wav")
		audio.volume_db = -5
		audio.pitch_scale = 0.6
		get_tree().current_scene.add_child(audio)
		audio.play()
		audio.finished.connect(audio.queue_free)
	
	if $Sprite2D:
		$Sprite2D.visible = false
	await get_tree().create_timer(0.3).timeout
	queue_free()
	
# Bounce when colliding
func _on_body_entered(body: Node) -> void:
	if body is StaticBody2D:		
		var to_body = (body.global_position - global_position).normalized()		
		
		if abs(to_body.x) > abs(to_body.y):
			velocity.x = -velocity.x
		else:
			velocity.y = -velocity.y
		
		global_position -= to_body * 5

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

class ExplosionDrawer extends Node2D:
	var radius := 80.0
	
	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.6, 0.1, 0.5))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(1.0, 0.3, 0.0, 0.8), 2.0)
