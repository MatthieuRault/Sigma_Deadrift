extends Node

# ==================== ENEMY DEATH PARTICLES ====================

func spawn_death(scene_root: Node, pos: Vector2, color: Color = Color.RED) -> void:
	var particles = CPUParticles2D.new()
	particles.global_position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 12
	particles.lifetime = 0.4
	particles.explosiveness = 1.0
	particles.direction = Vector2.ZERO
	particles.spread = 180.0
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 100.0
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = color
	
	scene_root.add_child(particles)
	
	# Auto-remove after particles finish
	particles.finished.connect(particles.queue_free)

# ==================== BULLET IMPACT PARTICLES ====================

func spawn_impact(scene_root: Node, pos: Vector2) -> void:
	var particles = CPUParticles2D.new()
	particles.global_position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 6
	particles.lifetime = 0.2
	particles.explosiveness = 1.0
	particles.direction = Vector2.ZERO
	particles.spread = 180.0
	particles.initial_velocity_min = 20.0
	particles.initial_velocity_max = 50.0
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.0
	particles.color = Color(1.0, 0.9, 0.5)
	
	scene_root.add_child(particles)
	particles.finished.connect(particles.queue_free)

func spawn_muzzle_flash(scene_root: Node, pos: Vector2, angle: float) -> void:	
	var particles = CPUParticles2D.new()
	particles.global_position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 4
	particles.lifetime = 0.08
	particles.explosiveness = 1.0
	particles.direction = Vector2.RIGHT.rotated(angle)
	particles.spread = 25.0
	particles.initial_velocity_min = 30.0
	particles.initial_velocity_max = 60.0
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.0
	particles.color = Color(1.0, 0.9, 0.4, 0.9)
	
	scene_root.add_child(particles)
	particles.finished.connect(particles.queue_free)
	
	var flash = _FlashCircle.new()
	flash.global_position = pos
	scene_root.add_child(flash)

# ==================== HIT MARKER ====================

func spawn_hit_marker(scene_root: Node, pos: Vector2, damage: int) -> void:
	# Floating damage number
	var container = Node2D.new()
	container.global_position = pos
	
	var label = Label.new()
	label.text = str(damage)
	label.add_theme_font_size_override("font_size", 10 + damage * 2)
	label.position = Vector2(randf_range(-8, 8), -10)
	label.modulate = Color(1.0, 0.3, 0.3) if damage >= 3 else Color.WHITE
	label.z_index = 10
	
	container.add_child(label)
	scene_root.add_child(container)
	
	# Float up and fade
	var tween = container.create_tween()
	tween.set_parallel(true)
	tween.tween_property(container, "position:y", container.position.y - 20, 0.6)
	tween.tween_property(container, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(container.queue_free)

# ==================== EXPLOSION PARTICLES ====================

func spawn_explosion(scene_root: Node, pos: Vector2, radius: float = 40.0) -> void:
	# Fire particles
	var fire = CPUParticles2D.new()
	fire.global_position = pos
	fire.emitting = true
	fire.one_shot = true
	fire.amount = 20
	fire.lifetime = 0.5
	fire.explosiveness = 1.0
	fire.direction = Vector2.ZERO
	fire.spread = 180.0
	fire.initial_velocity_min = 30.0
	fire.initial_velocity_max = radius * 1.5
	fire.gravity = Vector2.ZERO
	fire.scale_amount_min = 2.0
	fire.scale_amount_max = 5.0
	fire.color_ramp = _create_fire_gradient()
	
	scene_root.add_child(fire)
	fire.finished.connect(fire.queue_free)
	
	# Smoke particles (slightly delayed)
	var smoke = CPUParticles2D.new()
	smoke.global_position = pos
	smoke.emitting = true
	smoke.one_shot = true
	smoke.amount = 8
	smoke.lifetime = 0.7
	smoke.explosiveness = 0.8
	smoke.direction = Vector2.UP
	smoke.spread = 40.0
	smoke.initial_velocity_min = 10.0
	smoke.initial_velocity_max = 30.0
	smoke.gravity = Vector2(0, -20)
	smoke.scale_amount_min = 3.0
	smoke.scale_amount_max = 6.0
	smoke.color = Color(0.3, 0.3, 0.3, 0.5)
	
	scene_root.add_child(smoke)
	smoke.finished.connect(smoke.queue_free)

static func _create_fire_gradient() -> Gradient:
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 0.8, 0.2, 1.0))
	gradient.set_color(1, Color(1.0, 0.2, 0.0, 0.0))
	return gradient
	
# ==================== FLASH CIRCLE (MUZZLE) ====================

class _FlashCircle extends Node2D:
	var lifetime := 0.0
	var max_life := 0.06
	
	func _process(delta: float) -> void:
		lifetime += delta
		if lifetime >= max_life:
			queue_free()
			return
		queue_redraw()
	
	func _draw() -> void:
		var alpha = 1.0 - (lifetime / max_life)
		var radius = 4.0 + lifetime * 40.0
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.95, 0.7, alpha * 0.6))
