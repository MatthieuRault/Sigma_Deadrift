extends Node2D

# ==================== MAP ====================

var map_size := Vector2(960, 540)

# ==================== GAME STATE ====================

var score := 0
var is_game_over := false

# ==================== WAVE SYSTEM ====================

var current_wave := 0
var enemies_to_spawn := 0
var enemies_alive := 0
var wave_active := false
var between_waves := false
var boss_alive := false
var spawn_interval := 1.0

# ==================== HUD STATE ====================

var current_weapon_name := "pistol"

# HUD nodes (created in code)
var hearts_container : HBoxContainer
var weapon_icon : TextureRect
var weapon_label : Label
var grenade_icon : TextureRect
var dash_icon : TextureRect
var wave_label : Label
var score_display : Label

# ==================== RESOURCES ====================

var enemy_scene = preload("res://Scenes/Main/Enemy/enemy.tscn")
var gameover_sound = preload("res://Sounds/game_over.wav")

# HUD icons
var icon_heart = preload("res://Scenes/Main/HUD/Sprites/icon_heart.png")
var icon_heart_empty = preload("res://Scenes/Main/HUD/Sprites/icon_heart_empty.png")
var icon_pistol = preload("res://Scenes/Main/HUD/Sprites/icon_pistol.png")
var icon_shotgun = preload("res://Scenes/Main/HUD/Sprites/icon_shotgun.png")
var icon_sniper = preload("res://Scenes/Main/HUD/Sprites/icon_sniper.png")
var icon_grenade = preload("res://Scenes/Main/HUD/Sprites/icon_grenade.png")
var icon_dash = preload("res://Scenes/Main/HUD/Sprites/icon_dash.png")

# ==================== NODE REFERENCES ====================

@onready var score_label = $CanvasLayer/MarginContainer/Label

# ==================== INITIALIZATION ====================

func _ready() -> void:
	$Timer.timeout.connect(_on_timer_timeout)
	$Timer.stop()
	_create_obstacles()
	_create_walls()
	_create_hud()
	await get_tree().create_timer(1.0).timeout
	_start_next_wave()

# ==================== MAP SETUP ====================

func _create_obstacles() -> void:
	var crate_texture = preload("res://Scenes/Main/Sprites/crate.png")
	var positions = [
		Vector2(200, 150), Vector2(400, 300), Vector2(700, 150),
		Vector2(150, 400), Vector2(500, 200), Vector2(300, 100),
		Vector2(750, 400), Vector2(600, 450), Vector2(850, 250),
	]
	
	for pos in positions:
		var body = StaticBody2D.new()
		var sprite = Sprite2D.new()
		var col = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		
		sprite.texture = crate_texture
		shape.size = Vector2(32, 32)
		col.shape = shape
		body.collision_layer = 16
		body.collision_mask = 0
		
		body.add_child(sprite)
		body.add_child(col)
		body.position = pos
		add_child(body)

func _create_walls() -> void:
	var thickness = 16.0
	var walls = [
		{"pos": Vector2(map_size.x / 2, thickness / 2), "size": Vector2(map_size.x, thickness)},
		{"pos": Vector2(map_size.x / 2, map_size.y - thickness / 2), "size": Vector2(map_size.x, thickness)},
		{"pos": Vector2(thickness / 2, map_size.y / 2), "size": Vector2(thickness, map_size.y)},
		{"pos": Vector2(map_size.x - thickness / 2, map_size.y / 2), "size": Vector2(thickness, map_size.y)},
	]
	
	for w in walls:
		var body = StaticBody2D.new()
		var sprite = Sprite2D.new()
		var col = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		
		shape.size = w["size"]
		col.shape = shape
		sprite.region_enabled = true
		sprite.region_rect = Rect2(Vector2.ZERO, w["size"])
		sprite.texture = preload("res://Scenes/Main/Sprites/wall_brick.png")
		sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		
		body.collision_layer = 16
		body.collision_mask = 0
		body.position = w["pos"]
		body.add_child(sprite)
		body.add_child(col)
		add_child(body)

# ==================== HUD ====================

func _create_hud() -> void:
	var hud = HBoxContainer.new()
	hud.anchor_right = 1.0
	hud.offset_left = 8
	hud.offset_top = 6
	hud.offset_right = -8
	hud.add_theme_constant_override("separation", 12)
	$CanvasLayer.add_child(hud)
	
	# Hearts
	hearts_container = HBoxContainer.new()
	hearts_container.add_theme_constant_override("separation", 2)
	hud.add_child(hearts_container)
	for i in 5:
		var h = TextureRect.new()
		h.texture = icon_heart
		h.stretch_mode = TextureRect.STRETCH_KEEP
		h.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		hearts_container.add_child(h)
	
	_add_separator(hud)
	
	# Weapon
	weapon_icon = TextureRect.new()
	weapon_icon.texture = icon_pistol
	weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP
	weapon_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hud.add_child(weapon_icon)
	
	weapon_label = Label.new()
	weapon_label.text = "Pistol"
	weapon_label.add_theme_font_size_override("font_size", 14)
	hud.add_child(weapon_label)
	
	_add_separator(hud)
	
	# Grenade
	grenade_icon = TextureRect.new()
	grenade_icon.texture = icon_grenade
	grenade_icon.stretch_mode = TextureRect.STRETCH_KEEP
	grenade_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hud.add_child(grenade_icon)
	
	# Dash
	dash_icon = TextureRect.new()
	dash_icon.texture = icon_dash
	dash_icon.stretch_mode = TextureRect.STRETCH_KEEP
	dash_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hud.add_child(dash_icon)
	
	_add_separator(hud)
	
	# Wave
	wave_label = Label.new()
	wave_label.text = "Wave 1"
	wave_label.add_theme_font_size_override("font_size", 14)
	hud.add_child(wave_label)
	
	# Score (aligned right)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.add_child(spacer)
	
	score_display = Label.new()
	score_display.text = "Score: 0"
	score_display.add_theme_font_size_override("font_size", 14)
	hud.add_child(score_display)
	
	score_label.visible = false

func _add_separator(parent: Node) -> void:
	var sep = Label.new()
	sep.text = "|"
	sep.add_theme_font_size_override("font_size", 14)
	sep.modulate = Color(1, 1, 1, 0.3)
	parent.add_child(sep)

func _update_hud() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	# Hearts
	for i in hearts_container.get_child_count():
		var h = hearts_container.get_child(i) as TextureRect
		h.texture = icon_heart if i < player.health else icon_heart_empty
	
	# Weapon icon and name
	var weapon_icons := {"pistol": icon_pistol, "shotgun": icon_shotgun, "sniper": icon_sniper}
	var weapon_names := {"pistol": "Pistol", "shotgun": "Shotgun", "sniper": "Sniper"}
	weapon_icon.texture = weapon_icons.get(current_weapon_name, icon_pistol)
	weapon_label.text = weapon_names.get(current_weapon_name, "")
	
	# Grenade and dash cooldowns
	grenade_icon.modulate = Color.WHITE if player.can_grenade else Color(1, 1, 1, 0.3)
	dash_icon.modulate = Color.WHITE if player.can_dash else Color(1, 1, 1, 0.3)
	
	# Wave display
	if between_waves:
		wave_label.text = "Prochaine vague..."
		wave_label.modulate = Color.WHITE
	elif current_wave % 5 == 0 and boss_alive:
		wave_label.text = "Vague %s - BOSS!" % current_wave
		wave_label.modulate = Color.RED
	else:
		wave_label.text = "Vague %s" % current_wave
		wave_label.modulate = Color.WHITE
	
	# Score
	score_display.text = "Score: %s" % score

func on_weapon_changed(weapon: String) -> void:
	current_weapon_name = weapon

# ==================== WAVE SYSTEM ====================

func _start_next_wave() -> void:
	current_wave += 1
	wave_active = true
	between_waves = false
	
	if current_wave % 5 == 0:
		enemies_to_spawn = 1
		boss_alive = true
	else:
		enemies_to_spawn = 5 + current_wave * 3
	
	spawn_interval = max(0.3, 1.2 - current_wave * 0.05)
	$Timer.wait_time = spawn_interval
	$Timer.start()

func _start_intermission() -> void:
	await get_tree().create_timer(2.0).timeout
	if not is_game_over:
		_start_next_wave()

func on_boss_killed() -> void:
	boss_alive = false

# ==================== GAME LOOP ====================

func _process(delta: float) -> void:
	if is_game_over:
		return
	
	enemies_alive = get_tree().get_nodes_in_group("enemy").size()
	
	# Remove enemies stuck outside map bounds
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var pos = enemy.global_position
		if pos.x < 0 or pos.x > map_size.x or pos.y < 0 or pos.y > map_size.y:
			enemy.queue_free()
	
	# Check if wave is complete
	if wave_active and enemies_to_spawn <= 0 and enemies_alive <= 0:
		wave_active = false
		between_waves = true
		_start_intermission()
	
	_update_hud()

# ==================== SCORE & GAME OVER ====================

func add_score(amount: int) -> void:
	score += amount

func _input(event: InputEvent) -> void:
	if is_game_over and event is InputEventKey and event.pressed:
		get_tree().change_scene_to_file("res://Scenes/Title/title.tscn")

func game_over() -> void:
	is_game_over = true
	score_label.visible = true
	score_label.text = "GAME OVER!\n\nScore: %s  |  Vague: %s\n\nAppuyer sur une touche" % [score, current_wave]
	$Timer.stop()
	
	var audio = AudioStreamPlayer.new()
	audio.stream = gameover_sound
	audio.volume_db = -20
	add_child(audio)
	audio.play()
	
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.queue_free()

# ==================== ENEMY SPAWNING ====================

func _get_available_types() -> Array:
	var types := ["normal"]
	
	if current_wave >= 2:
		types.append("fast")
	if current_wave >= 3:
		types.append("tank")
	if current_wave >= 4:
		types.append("ranged")
	if current_wave >= 6:
		types.append("splitter")
	if current_wave >= 7:
		types.append("exploder")
	if current_wave >= 8:
		types.append("ghost")
	
	return types

# Weighted random selection from available types
func _pick_enemy_type() -> String:
	var types = _get_available_types()
	
	# Base weights for each type
	var weights := {
		"normal": 30,
		"fast": 25,
		"tank": 10,
		"ranged": 15,
		"splitter": 10,
		"exploder": 8,
		"ghost": 8,
	}
	
	# Scale down normal weight as more types unlock
	if types.size() > 4:
		weights["normal"] = 20
	if types.size() > 6:
		weights["normal"] = 15
	
	# Build weighted pool
	var pool := []
	var total := 0.0
	for t in types:
		total += weights.get(t, 10)
		pool.append({"type": t, "cumulative": total})
	
	var roll = randf() * total
	for entry in pool:
		if roll <= entry["cumulative"]:
			return entry["type"]
	
	return "normal"

func _on_timer_timeout() -> void:
	if enemies_to_spawn <= 0:
		$Timer.stop()
		return
	
	var enemy = enemy_scene.instantiate()
	
	if current_wave % 5 == 0:
		enemy.setup("boss")
		enemies_to_spawn = 0
		$Timer.stop()
	else:
		enemy.setup(_pick_enemy_type())
	
	# Spawn at map edges
	var side = randi() % 4
	var margin = 40.0
	
	match side:
		0: enemy.global_position = Vector2(randf() * map_size.x, margin)
		1: enemy.global_position = Vector2(randf() * map_size.x, map_size.y - margin)
		2: enemy.global_position = Vector2(margin, randf() * map_size.y)
		3: enemy.global_position = Vector2(map_size.x - margin, randf() * map_size.y)
	
	add_child(enemy)
	enemies_to_spawn -= 1
	enemies_alive += 1
