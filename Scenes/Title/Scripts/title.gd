extends Control

# ==================== INITIALIZATION ====================

func _ready() -> void:
	_create_background()
	_create_title()
	_create_menu()

# ==================== BACKGROUND ====================

func _create_background() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.12, 1.0)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

# ==================== TITLE ====================

func _create_title() -> void:
	var title = Label.new()
	title.text = "SIGMA"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.anchor_top = 0.12
	title.offset_left = -150
	title.offset_right = 150
	
	var subtitle = Label.new()
	subtitle.text = "DEADRIFT"
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(0.8, 0.3, 0.3)
	add_child(subtitle)
	subtitle.anchor_left = 0.5
	subtitle.anchor_right = 0.5
	subtitle.anchor_top = 0.24
	subtitle.offset_left = -150
	subtitle.offset_right = 150
	
	var tagline = Label.new()
	tagline.text = "La faille s'ouvre. Les morts se relèvent. Tu es le dernier."
	tagline.add_theme_font_size_override("font_size", 10)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.modulate = Color(1, 1, 1, 0.4)
	add_child(tagline)
	tagline.anchor_left = 0.5
	tagline.anchor_right = 0.5
	tagline.anchor_top = 0.32
	tagline.offset_left = -200
	tagline.offset_right = 200

# ==================== MENU ====================

func _create_menu() -> void:
	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_top = 0.45
	vbox.offset_left = -80
	vbox.offset_right = 80
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)
	
	var play_btn = Button.new()
	play_btn.text = "JOUER"
	play_btn.add_theme_font_size_override("font_size", 18)
	play_btn.pressed.connect(_on_play)
	vbox.add_child(play_btn)
	
	var quit_btn = Button.new()
	quit_btn.text = "QUITTER"
	quit_btn.add_theme_font_size_override("font_size", 18)
	quit_btn.pressed.connect(_on_quit)
	vbox.add_child(quit_btn)
	
	var controls = Label.new()
	controls.text = "ZQSD - Move  |  LMB - Shoot  |  RMB - Grenade\nF - Mine  |  Space - Dash  |  B - Fire Mode\n1-6 - Weapons  |  R - Reload  |  Scroll - Switch"
	controls.add_theme_font_size_override("font_size", 10)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.modulate = Color(1, 1, 1, 0.4)
	add_child(controls)
	controls.anchor_left = 0.5
	controls.anchor_right = 0.5
	controls.anchor_top = 0.8
	controls.offset_left = -200
	controls.offset_right = 200

# ==================== ACTIONS ====================

func _on_play() -> void:
	get_tree().change_scene_to_file("res://Scenes/main.tscn")

func _on_quit() -> void:
	get_tree().quit()
