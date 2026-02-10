extends Area2D

var type := "heal"
var tex_heal = preload("res://Scenes/PowerUp/Sprites/powerup_heal.png")
var tex_fire_rate = preload("res://Scenes/PowerUp/Sprites/powerup_fire_rate.png")
var tex_damage = preload("res://Scenes/PowerUp/Sprites/powerup_damage.png")

func setup(power_type: String) -> void:
	#print("test du buff ici:", type)
	type = power_type
	
	# Type power-up
	match type:
		"heal":
			$Sprite2D.texture = tex_heal
		"fire_rate":
			$Sprite2D.texture = tex_fire_rate
		"damage":
			$Sprite2D.texture = tex_damage
			
	$Sprite2D.scale = Vector2(0.35, 0.35)
	
func _ready() -> void:
	#body_entered.connect(_on_body_entered)	
	
	# Despawn after 5 seconds if not picked up
	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(self):
		queue_free()
		
func _physics_process(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and global_position.distance_to(player.global_position) < 25:
		if player.has_method("apply_powerup"):
			player.apply_powerup(type)
		queue_free()

#func _on_body_entered(body: Node2D) -> void:
	#if body.is_in_group("player") and body.has_method("apply_powerup"):
		#body.apply_powerup(type)
		#queue_free()
