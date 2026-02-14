extends Area2D

# ==================== PROPERTIES ====================

var type := "heal"

# ==================== RESOURCES ====================

var tex_heal = preload("res://Scenes/PowerUp/Sprites/powerup_heal.png")
var tex_fire_rate = preload("res://Scenes/PowerUp/Sprites/powerup_fire_rate.png")
var tex_damage = preload("res://Scenes/PowerUp/Sprites/powerup_damage.png")
var pickup_sound = preload("res://Sounds/powerup.wav")

# ==================== INITIALIZATION ====================

# Set type and matching texture
func setup(power_type: String) -> void:
	type = power_type
	match type:
		"heal":
			$Sprite2D.texture = tex_heal
		"fire_rate":
			$Sprite2D.texture = tex_fire_rate
		"damage":
			$Sprite2D.texture = tex_damage
	$Sprite2D.scale = Vector2(0.35, 0.35)

func _ready() -> void:
	# Despawn after 5 seconds if not picked up
	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(self):
		queue_free()

# ==================== PICKUP ====================

func _physics_process(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	if global_position.distance_to(player.global_position) < 25:
		if player.has_method("apply_powerup"):
			player.apply_powerup(type)
		
		# Play sound on main scene
		var audio = AudioStreamPlayer.new()
		audio.stream = pickup_sound
		audio.volume_db = -15
		get_tree().current_scene.add_child(audio)
		audio.play()
		audio.finished.connect(audio.queue_free)
		
		queue_free()
