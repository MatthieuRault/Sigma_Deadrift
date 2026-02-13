extends Node2D

var score := 0
var is_game_over := false
var enemy_scene = preload("res://Scenes/Main/Enemy/enemy.tscn")
@onready var score_label = $CanvasLayer/MarginContainer/Label
var gameover_sound = preload("res://Sounds/game_over.wav")
var current_wave := 0
var enemies_to_spawn := 0
var enemies_alive := 0
var wave_active := false
var between_waves := false
var boss_alive := false
var spawn_interval := 1.0

func _ready() -> void:
	$Timer.timeout.connect(_on_timer_timeout)
	$Timer.stop()
	create_obstacles()
	await get_tree().create_timer(1.0).timeout
	start_next_wave()

# Spawn obstacles - predefined positions
func create_obstacles() -> void:
	var crate_texture = preload("res://Scenes/Main/Sprites/crate.png")
	var obstacle_positions = [
		Vector2(300, 200), Vector2(500, 400), Vector2(700, 150),
		Vector2(200, 350), Vector2(600, 300), Vector2(400, 100)
	]
	
	for pos in obstacle_positions:
		var body = StaticBody2D.new()
		var sprite = Sprite2D.new()
		var col = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		
		sprite.texture = crate_texture
		shape.size = Vector2(32, 32)
		col.shape = shape
		
		# Set obstacle to layer 5
		body.collision_layer = 16
		body.collision_mask = 0
		
		body.add_child(sprite)
		body.add_child(col)
		body.position = pos
		add_child(body)

func start_next_wave() -> void:
	current_wave += 1
	wave_active = true
	between_waves = false
	
	var is_boss_wave = current_wave % 5 == 0
	if is_boss_wave:
		enemies_to_spawn = 1
		boss_alive = true
	else:
	# Increase enemy count each wave
		enemies_to_spawn = 3 + current_wave * 2
	
	# Increase spawn speed for higher waves
	spawn_interval = max(0.3, 1.2 - current_wave * 0.05)
	$Timer.wait_time = spawn_interval
	$Timer.start()

func _start_intermission() -> void:
	await get_tree().create_timer(2.0).timeout
	if not is_game_over:
		start_next_wave()

# Update UI score and hp
func _process(delta: float) -> void:
	if is_game_over:
		return
		
	# Count alive enemies
	enemies_alive = get_tree().get_nodes_in_group("enemy").size()
		
	if wave_active and enemies_to_spawn <= 0 and enemies_alive <= 0:
		wave_active = false
		between_waves = true
		_start_intermission()
	
	# HUD
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var wave_text = ""
		if between_waves:
			wave_text = "  |  Prochaine vague..."
		elif current_wave % 5 == 0 and boss_alive:
			wave_text = "  |  BOSS !"
		score_label.text = "Score: %s  |  Vie: %s  |  Vague: %s%s" % [
			score, player.health, current_wave, wave_text
		]
		
func on_boss_killed() -> void:
		boss_alive = false

# Restart game
func _input(event: InputEvent) -> void:
	if is_game_over and event is InputEventKey and event.pressed:
		get_tree().reload_current_scene()

func add_score(amount: int) -> void:
	score += amount
	
func game_over() -> void:
	is_game_over = true
	score_label.text = "GAME OVER! Score: %s | Wave: %s\nPress any key to restart" % [str(score), str(current_wave)]

	$Timer.stop()
	var audio = AudioStreamPlayer.new()
	audio.stream = gameover_sound
	audio.volume_db = -20
	add_child(audio)
	audio.play()
	# Clear all remaining enemies
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.queue_free()
		
func _on_timer_timeout() -> void:
	if enemies_to_spawn <= 0:
		$Timer.stop()
		return
	
	var enemy = enemy_scene.instantiate()
	var is_boss_wave = current_wave % 5 == 0
	
	if is_boss_wave:
		enemy.setup("boss")
	else:
	# Increase difficulty
		var rand = randf()
		var tank_chance = min(0.1 + current_wave * 0.03, 0.35)
		var fast_chance = min(0.2 + current_wave * 0.02, 0.4)
	
		if rand < tank_chance:
			enemy.setup("tank")
		elif rand < tank_chance + fast_chance:
			enemy.setup("fast")
		else:
			enemy.setup("normal")
	# Random spawn at screen edges
	var side = randi() % 4
	var viewport_size = get_viewport_rect().size
	
	match side:
		0: # Top
			enemy.global_position = Vector2(randf() * viewport_size.x, -50)
		1: # Bottom
			enemy.global_position = Vector2(randf() * viewport_size.x, viewport_size.y + 50)
		2: # Left
			enemy.global_position = Vector2(-50, randf() * viewport_size.y)
		3: # Right
			enemy.global_position = Vector2(viewport_size.x + 50, randf() * viewport_size.y)
	
	add_child(enemy)
	enemies_to_spawn -= 1
	enemies_alive += 1
