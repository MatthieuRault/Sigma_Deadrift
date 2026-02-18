extends CharacterBody2D

# ==================== EXPORTS ====================

@export var bullet_scene : PackedScene

# ==================== MOVEMENT ====================

var base_speed : float = 220.0
var speed      : float = 220.0
var direction  := Vector2.ZERO

# ==================== DASH ====================

var dash_speed    := 600.0
var dash_duration := 0.15
var dash_cooldown := 0.8
var can_dash      := true
var is_dashing    := false

# ==================== WEAPON INVENTORY ====================

# Player spawns with pistol only.
# All other weapons must be picked up from enemy drops.
var weapons        : Array = ["pistol"]
const MAX_WEAPONS  : int   = 3           # Pistol + 2 dropped weapons max
var weapon_index   : int   = 0
var current_weapon : String = "pistol"

var weapon_data := {
	"pistol":  {"damage":1, "cooldown":0.15, "speed":500.0, "count":1, "spread":0.0,  "piercing":false, "auto":false},
	"shotgun": {"damage":2, "cooldown":0.55, "speed":380.0, "count":5, "spread":0.38, "piercing":false, "auto":false},
	"sniper":  {"damage":6, "cooldown":1.1,  "speed":850.0, "count":1, "spread":0.0,  "piercing":true,  "auto":false},
	"assault": {"damage":1, "cooldown":0.09, "speed":460.0, "count":1, "spread":0.07, "piercing":false, "auto":true},
	"minigun": {"damage":1, "cooldown":0.05, "speed":400.0, "count":1, "spread":0.16, "piercing":false, "auto":true},
	"rocket":  {"damage":9, "cooldown":1.9,  "speed":270.0, "count":1, "spread":0.0,  "piercing":false, "auto":false},
}

# Ammo config: mag_size, max_stock, reload_time  (-1 stock = infinite)
var ammo_data := {
	"pistol":  {"mag_size":12, "max_stock":-1,  "reload_time":0.7},
	"shotgun": {"mag_size":4,  "max_stock":24,  "reload_time":1.5},
	"sniper":  {"mag_size":3,  "max_stock":12,  "reload_time":1.8},
	"assault": {"mag_size":20, "max_stock":80,  "reload_time":1.2},
	"minigun": {"mag_size":50, "max_stock":130, "reload_time":3.0},
	"rocket":  {"mag_size":2,  "max_stock":6,   "reload_time":2.5},
}

# Ammo granted when picking up a fresh drop.
# Balanced for roughly 1–1.5 waves of usage before running dry.
const DROP_AMMO := {
	"shotgun": {"mag":4,  "stock":12},   # 16 total shots
	"assault": {"mag":20, "stock":20},   # 40 total shots
	"sniper":  {"mag":3,  "stock":6},    # 9  total shots
	"minigun": {"mag":30, "stock":30},   # 60 total shots
	"rocket":  {"mag":2,  "stock":2},    # 4  total shots (high damage, low supply)
}

var current_mag   := {}
var current_stock := {}

var base_weapon_data      := {}
var damage_buff_active    := false
var fire_rate_buff_active := false

# ==================== FIRE MODES ====================

var fire_mode_weapons := ["assault", "minigun"]
var fire_modes        := ["auto", "burst", "semi"]
var current_fire_mode := "auto"
var burst_count       := 3
var burst_remaining   := 0
var is_bursting       := false

var can_shoot    := true
var is_firing    := false
var is_reloading := false

# ==================== GRENADE ====================

var grenade_scene    : PackedScene
var can_grenade      := true
var grenade_cooldown := 2.0

# ==================== MINE ====================

var can_mine      := true
var mine_cooldown := 4.0
var mine_damage   := 5
var mine_radius   := 45.0

# ==================== HEALTH ====================

var health     := 5
var max_health := 5
var invincible := false

# ==================== RELOAD VISUAL ====================

var reload_progress := 0.0
var reload_duration := 0.0

# ==================== SOUNDS ====================

var shoot_sound = preload("res://Sounds/shoot.wav")
var hit_sound   = preload("res://Sounds/player_hit.wav")

# ==================== NODE REFERENCES ====================

@onready var sprite = $Soldier
@onready var camera = $Camera2D

# ==================== INITIALIZATION ====================

func _ready() -> void:
	add_to_group("player")
	sprite.play("idle")
	sprite.scale = Vector2(1, 1)

	if camera:
		camera.limit_left   = 0
		camera.limit_top    = 0
		camera.limit_right  = 960
		camera.limit_bottom = 540

	# Save base stats so buffs don't stack across multiple pickups
	for w in weapon_data:
		base_weapon_data[w] = weapon_data[w].duplicate()

	# Pistol has infinite ammo; all other weapons start empty until dropped
	for w in ammo_data:
		if w == "pistol":
			current_mag[w]   = ammo_data[w]["mag_size"]
			current_stock[w] = -1
		else:
			current_mag[w]   = 0
			current_stock[w] = 0

	if ResourceLoader.exists("res://Scenes/Grenade/grenade.tscn"):
		grenade_scene = load("res://Scenes/Grenade/grenade.tscn")

# ==================== GAME LOOP ====================

func _physics_process(delta) -> void:
	if is_dashing:
		move_and_slide()
		return

	if is_reloading:
		reload_progress += delta
	queue_redraw()

	# Minigun slows the player while firing
	speed = base_speed * 0.35 if (current_weapon == "minigun" and is_firing) else base_speed

	velocity = direction * speed
	move_and_slide()

	sprite.flip_h = get_global_mouse_position().x < global_position.x

	# Auto-fire for assault / minigun in auto mode
	if can_shoot and weapon_data[current_weapon]["auto"] \
			and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if _get_effective_fire_mode() == "auto":
			_shoot()

	if is_bursting and burst_remaining > 0 and can_shoot:
		_shoot_burst_tick()

# ==================== INPUT ====================

func _input(event: InputEvent) -> void:
	direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# Mouse wheel cycles inventory slots
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP   and event.pressed: _switch_weapon(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed: _switch_weapon(1)

	if event is InputEventKey and event.pressed:
		if   event.keycode == KEY_1: _set_weapon(0)
		elif event.keycode == KEY_2: _set_weapon(1)
		elif event.keycode == KEY_3: _set_weapon(2)
		elif event.keycode == KEY_R: _reload()
		elif event.keycode == KEY_B: _cycle_fire_mode()		
		elif event.keycode == KEY_G: _try_swap_weapon()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed \
				and can_shoot and not is_reloading:
			var mode = _get_effective_fire_mode()
			if mode == "burst" and weapon_data[current_weapon]["auto"]:
				_start_burst()
			elif mode == "semi" or not weapon_data[current_weapon]["auto"]:
				_shoot()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and can_grenade:
			_throw_grenade()
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_firing = event.pressed

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE and can_dash and direction != Vector2.ZERO:
			_dash()
		elif event.keycode == KEY_F and can_mine:
			_place_mine()

# ==================== WEAPON SWITCHING ====================

func _switch_weapon(dir: int) -> void:
	_cancel_reload()
	weapon_index   = wrapi(weapon_index + dir, 0, weapons.size())
	current_weapon = weapons[weapon_index]
	is_firing      = false
	_notify_weapon_change()

func _set_weapon(index: int) -> void:
	_cancel_reload()
	if index >= 0 and index < weapons.size():
		weapon_index   = index
		current_weapon = weapons[weapon_index]
		is_firing      = false
		_notify_weapon_change()

func _notify_weapon_change() -> void:
	var main = get_tree().current_scene
	if main.has_method("on_weapon_changed"):
		main.on_weapon_changed(current_weapon)
	current_fire_mode = "auto"
	is_bursting       = false
	burst_remaining   = 0
	if main.has_method("on_fire_mode_changed"):
		main.on_fire_mode_changed(current_fire_mode)

# ==================== WEAPON PICKUP ====================

# Returns true if the weapon was taken (free slot or same-weapon ammo refill).
func pickup_weapon(type: String) -> bool:
	# Already carrying this weapon → refill ammo instead
	if type in weapons:
		var drop = DROP_AMMO.get(type, {"mag":0, "stock":10})
		current_stock[type] = min(
			current_stock[type] + drop["stock"],
			ammo_data[type]["max_stock"]
		)
		_flash(Color(0.5, 1.0, 0.5))
		return true

	# Inventory full — player must use G to swap
	if weapons.size() >= MAX_WEAPONS:
		return false

	# Add to free slot and auto-switch to new weapon
	weapons.append(type)
	var drop = DROP_AMMO.get(type, {"mag":10, "stock":10})
	current_mag[type]   = drop["mag"]
	current_stock[type] = drop["stock"]
	weapon_index   = weapons.find(type)
	current_weapon = type
	_notify_weapon_change()
	_flash(Color(1.0, 1.0, 0.3))
	return true

func _try_swap_weapon() -> void:
	var best_drop : Node  = null
	var best_dist : float = 55.0

	for node in get_tree().get_nodes_in_group("weapon_drops"):
		if not is_instance_valid(node): continue
		var d = global_position.distance_to(node.global_position)
		if d < best_dist:
			best_dist = d
			best_drop = node

	if not best_drop:
		return

	var drop_type : String = best_drop.weapon_type

	# If we already carry this type just refill ammo
	if drop_type in weapons:
		pickup_weapon(drop_type)
		best_drop.queue_free()
		return

	# Drop current weapon on the ground and pick up the new one
	_spawn_weapon_drop_at(current_weapon, global_position)

	var old_weapon = current_weapon
	weapons.remove_at(weapon_index)
	current_mag[old_weapon]   = 0
	current_stock[old_weapon] = 0

	weapons.insert(weapon_index, drop_type)
	var drop_ammo = DROP_AMMO.get(drop_type, {"mag":10, "stock":10})
	current_mag[drop_type]   = drop_ammo["mag"]
	current_stock[drop_type] = drop_ammo["stock"]

	current_weapon = drop_type
	_notify_weapon_change()
	_flash(Color(1.0, 0.6, 0.1))
	best_drop.queue_free()

# Spawn a weapon drop node at the given world position (used when swapping out).
func _spawn_weapon_drop_at(type: String, pos: Vector2) -> void:
	if type == "pistol": return   # Pistol never drops — always kept in slot 1
	if not ResourceLoader.exists("res://Scenes/WeaponDrop/weapon_drop.tscn"): return
	var scene = load("res://Scenes/WeaponDrop/weapon_drop.tscn")
	var drop  = scene.instantiate()
	drop.setup(type)
	drop.global_position = pos + Vector2(randf_range(-10, 10), randf_range(-10, 10))
	get_parent().add_child(drop)

# Remove a weapon from the inventory (called when mag + stock reach zero).
func _remove_weapon(type: String) -> void:
	if type == "pistol": return
	var idx = weapons.find(type)
	if idx == -1: return
	weapons.remove_at(idx)
	current_mag[type]   = 0
	current_stock[type] = 0
	# Fall back to pistol if the active weapon was just removed
	if current_weapon == type:
		weapon_index   = 0
		current_weapon = "pistol"
		_notify_weapon_change()
	else:
		weapon_index = weapons.find(current_weapon)
		if weapon_index == -1:
			weapon_index   = 0
			current_weapon = "pistol"

# Drop a weapon if it has run completely out of ammo.
func _check_weapon_durability() -> void:
	if current_weapon == "pistol": return
	if current_mag.get(current_weapon, 0) <= 0 and current_stock.get(current_weapon, 0) <= 0:
		_remove_weapon(current_weapon)

# ==================== FIRE MODES ====================

func _get_effective_fire_mode() -> String:
	return current_fire_mode if current_weapon in fire_mode_weapons else "semi"

func _cycle_fire_mode() -> void:
	if current_weapon not in fire_mode_weapons: return
	var idx           = fire_modes.find(current_fire_mode)
	current_fire_mode = fire_modes[(idx + 1) % fire_modes.size()]
	is_bursting       = false
	burst_remaining   = 0
	var main = get_tree().current_scene
	if main.has_method("on_fire_mode_changed"):
		main.on_fire_mode_changed(current_fire_mode)

func _start_burst() -> void:
	if is_bursting: return
	is_bursting     = true
	burst_remaining = burst_count
	_shoot_burst_tick()

func _shoot_burst_tick() -> void:
	if burst_remaining <= 0 or not can_shoot:
		is_bursting     = false
		burst_remaining = 0
		return
	if current_mag[current_weapon] == 0:
		is_bursting     = false
		burst_remaining = 0
		if current_stock[current_weapon] <= 0:
			_check_weapon_durability()
			return
		_reload()
		return
	burst_remaining -= 1
	_shoot()
	if burst_remaining <= 0:
		is_bursting = false

# ==================== SHOOTING ====================

func _shoot() -> void:
	if not bullet_scene or is_reloading: return

	if current_mag[current_weapon] == 0:
		if current_stock[current_weapon] != -1 and current_stock[current_weapon] <= 0:
			_check_weapon_durability()
			return
		_reload()
		return

	var data       = weapon_data[current_weapon]
	var base_angle = (get_global_mouse_position() - global_position).angle()

	for i in data["count"]:
		var bullet    = bullet_scene.instantiate()
		bullet.damage = data["damage"]
		bullet.speed  = data["speed"]
		if bullet.has_method("set_piercing"):
			bullet.set_piercing(data["piercing"])
		bullet.set_type("rocket" if current_weapon == "rocket" else "player")

		var angle_offset := 0.0
		if data["count"] > 1:
			angle_offset = lerp(-data["spread"] / 2.0, data["spread"] / 2.0,
				float(i) / (data["count"] - 1))
		elif data["spread"] > 0:
			angle_offset = randf_range(-data["spread"], data["spread"])

		var final_angle = base_angle + angle_offset
		get_parent().add_child(bullet)
		bullet.global_position = global_position + Vector2.RIGHT.rotated(final_angle) * 20
		bullet.rotation        = final_angle

	if current_mag[current_weapon] != -1:
		current_mag[current_weapon] -= 1

	Effects.spawn_muzzle_flash(get_parent(),
		global_position + Vector2.RIGHT.rotated(base_angle) * 20, base_angle)

	sprite.play("shoot")
	_play_sound(shoot_sound, -10)
	await get_tree().create_timer(0.1).timeout
	sprite.play("idle")

	can_shoot = false
	await get_tree().create_timer(data["cooldown"]).timeout
	can_shoot = true

	_check_weapon_durability()

# ==================== RELOAD ====================

func _reload() -> void:
	var a = ammo_data[current_weapon]
	if current_mag[current_weapon] == a["mag_size"]: return
	if current_stock[current_weapon] != -1 and current_stock[current_weapon] <= 0: return
	if is_reloading: return

	is_reloading    = true
	is_firing       = false
	reload_duration = a["reload_time"]
	reload_progress = 0.0
	sprite.modulate = Color(0.7, 0.7, 1.0)

	await get_tree().create_timer(a["reload_time"]).timeout

	if not is_instance_valid(self) or not is_reloading: return

	var needed = a["mag_size"] - current_mag[current_weapon]
	if current_stock[current_weapon] == -1:
		current_mag[current_weapon] = a["mag_size"]
	else:
		var to_load = min(needed, current_stock[current_weapon])
		current_mag[current_weapon]   += to_load
		current_stock[current_weapon] -= to_load

	sprite.modulate = Color.WHITE
	is_reloading    = false
	reload_progress = 0.0
	reload_duration = 0.0
	_check_weapon_durability()

func _cancel_reload() -> void:
	if is_reloading:
		is_reloading    = false
		reload_progress = 0.0
		reload_duration = 0.0
		sprite.modulate = Color.WHITE

# ==================== AMMO POWERUP ====================

func add_ammo(weapon: String, amount: int) -> void:
	if ammo_data[weapon]["max_stock"] == -1: return
	current_stock[weapon] = min(current_stock[weapon] + amount, ammo_data[weapon]["max_stock"])

func add_ammo_all(amount: int) -> void:
	for w in weapons:
		add_ammo(w, amount)

# ==================== GRENADE ====================

func _throw_grenade() -> void:
	if not grenade_scene: return
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
	var mine       = Area2D.new()
	mine.global_position = global_position
	mine.collision_layer = 0
	mine.collision_mask  = 2  # Detect enemies
	var col   = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 12.0
	col.shape    = shape
	mine.add_child(col)
	var script = GDScript.new()
	script.source_code = """extends Area2D
var armed := false
var mine_damage := 5
var mine_radius := 45.0
var lifetime := 0.0
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Arm after a short delay to avoid instant self-detonation
	await get_tree().create_timer(0.5).timeout
	armed = true
func _physics_process(delta: float) -> void:
	lifetime += delta
	if lifetime > 15.0: queue_free()
func _draw() -> void:
	draw_circle(Vector2.ZERO, 6, Color(0.3, 0.3, 0.3))
	draw_circle(Vector2.ZERO, 3, Color(0.8, 0.2, 0.2) if armed else Color(0.5, 0.5, 0.5))
	draw_arc(Vector2.ZERO, 6, 0, TAU, 16, Color(0.5, 0.5, 0.5), 1.0)
func _on_body_entered(body: Node2D) -> void:
	if not armed or not body.is_in_group(\"enemy\"): return
	_explode()
func _explode() -> void:
	var main = get_tree().current_scene
	for enemy in get_tree().get_nodes_in_group(\"enemy\"):
		if is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= mine_radius:
			if enemy.has_method(\"take_damage\"):
				enemy.take_damage(int(mine_damage * (1.0 - global_position.distance_to(enemy.global_position) / mine_radius * 0.5)))
	var player = get_tree().get_first_node_in_group(\"player\")
	if player and is_instance_valid(player):
		var d = global_position.distance_to(player.global_position)
		if d <= mine_radius and player.has_method(\"take_damage\"):
			player.take_damage(int(mine_damage * (1.0 - d / mine_radius * 0.5)))
		if player.has_method(\"shake_camera\"): player.shake_camera(5.0, 0.2)
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
	can_dash   = false
	invincible = true
	# Temporarily disable collision with enemies
	set_collision_mask_value(2, false)
	set_collision_layer_value(1, false)
	velocity        = direction.normalized() * dash_speed
	sprite.modulate = Color(1, 1, 1, 0.4)
	shake_camera(3.0, 0.1)
	await get_tree().create_timer(dash_duration).timeout
	is_dashing      = false
	set_collision_mask_value(2, true)
	set_collision_layer_value(1, true)
	sprite.modulate = Color.WHITE
	invincible      = false
	await get_tree().create_timer(dash_cooldown).timeout
	can_dash = true

# ==================== DAMAGE & HEALTH ====================

func take_damage(amount: int) -> void:
	if invincible or health <= 0: return
	health -= amount
	_play_sound(hit_sound, -15)
	shake_camera(6.0, 0.25)
	# Knockback away from nearest enemy
	var nearest = get_tree().get_first_node_in_group("enemy")
	if nearest:
		velocity = (global_position - nearest.global_position).normalized() * 300
		move_and_slide()
	sprite.modulate = Color.RED
	invincible      = true
	await get_tree().create_timer(0.75).timeout
	sprite.modulate = Color.WHITE
	invincible      = false
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
			health = min(health + 2, max_health)
		"ammo":
			add_ammo_all(20)
		"fire_rate":
			if fire_rate_buff_active: return
			fire_rate_buff_active = true
			for w in weapon_data: weapon_data[w]["cooldown"] = base_weapon_data[w]["cooldown"] * 0.4
			await get_tree().create_timer(5.0).timeout
			for w in weapon_data: weapon_data[w]["cooldown"] = base_weapon_data[w]["cooldown"]
			fire_rate_buff_active = false
		"damage":
			if damage_buff_active: return
			damage_buff_active = true
			for w in weapon_data: weapon_data[w]["damage"] = base_weapon_data[w]["damage"] * 3
			await get_tree().create_timer(5.0).timeout
			for w in weapon_data: weapon_data[w]["damage"] = base_weapon_data[w]["damage"]
			damage_buff_active = false

# ==================== PLAYER VISUAL INDICATORS ====================

func _draw() -> void:
	_draw_health_bar()
	if is_reloading:
		_draw_reload_arc()

func _draw_health_bar() -> void:
	var bar_width  := 24.0
	var bar_height := 3.0
	var bar_y      := -22.0
	var hp_ratio   := float(health) / float(max_health)
	var bar_x      := -bar_width / 2.0
	draw_rect(Rect2(bar_x - 1, bar_y - 1, bar_width + 2, bar_height + 2), Color(0, 0, 0, 0.5))
	var c := Color(0.2, 0.8, 0.2)
	if hp_ratio < 0.4: c = Color(0.9, 0.2, 0.1)
	elif hp_ratio < 0.7: c = Color(0.9, 0.7, 0.1)
	draw_rect(Rect2(bar_x, bar_y, bar_width * hp_ratio, bar_height), c)

func _draw_reload_arc() -> void:
	if reload_duration <= 0.0: return
	var ratio  = clamp(reload_progress / reload_duration, 0.0, 1.0)
	var radius := 18.0
	var sa     := -PI / 2.0   # Start from top
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(0.4, 0.4, 0.4, 0.25), 2.0)
	if ratio > 0.01:
		var c = Color(0.3, 1.0, 0.5, 0.8) if ratio > 0.8 else Color(0.5, 0.7, 1.0, 0.7)
		draw_arc(Vector2.ZERO, radius, sa, sa + TAU * ratio, 32, c, 2.5)

# ==================== UTILITY ====================

# Brief colour flash on the sprite (pickup feedback).
func _flash(color: Color) -> void:
	sprite.modulate = color
	await get_tree().create_timer(0.12).timeout
	if is_instance_valid(self):
		sprite.modulate = Color.WHITE

func _play_sound(sound: AudioStream, volume: float = -10) -> void:
	var audio = AudioStreamPlayer.new()
	audio.stream    = sound
	audio.volume_db = volume
	add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)

func shake_camera(intensity: float = 5.0, duration: float = 0.2) -> void:
	if not camera: return
	var t := 0.0
	while t < duration:
		camera.offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		t += get_process_delta_time()
		await get_tree().process_frame
	camera.offset = Vector2.ZERO
