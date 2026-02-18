extends Node2D

# ==================== MAP ====================

var map_size := Vector2(960, 540)

# ==================== GAME STATE ====================

var score        := 0
var is_game_over := false

# ==================== WAVE SYSTEM ====================

var current_wave     := 0
var enemies_to_spawn := 0
var enemies_alive    := 0
var wave_active      := false
var between_waves    := false
var boss_alive       := false
var spawn_interval   := 1.0

# ==================== HUD STATE ====================

var current_weapon_name := "pistol"

# Top HUD
var hearts_container : HBoxContainer
var wave_label       : Label
var score_display    : Label

# Bottom weapon HUD — 3 inventory slots
var inv_panels : Array = []
var inv_icons  : Array = []
var inv_ammos  : Array = []

var fire_mode_label : Label
var grenade_icon    : TextureRect
var dash_icon       : TextureRect
var mine_icon       : TextureRect

# ==================== BOSS HP BAR ====================

var boss_bar_container : PanelContainer
var boss_bar_fill      : ColorRect
var boss_bar_bg        : ColorRect
var boss_name_label    : Label
var boss_hp_label      : Label
var boss_bar_width     := 200.0

# ==================== PAUSE ====================

var is_paused       := false
var pause_overlay   : ColorRect
var pause_container : VBoxContainer

# ==================== RADIO ====================

var radio_label     : Label
var radio_callsign  : Label
var radio_container : PanelContainer
var radio_tween     : Tween
var radio_visible   := false

var RADIO_MESSAGES := {
	# === ACT I — PREMIER CONTACT ===
	1: {"from": "QG OTAN", "msg": "Sigma-7, anomalies sismiques confirmées au col Vrancea. Progressez vers le camp de recherche. Terminé."},
	2: {"from": "SIGMA-7 LEAD", "msg": "Contact hostile confirmé. Créatures bipèdes, résistantes aux tirs standards. Deux hommes à terre. Demande extraction."},
	3: {"from": "SIGMA-7 LEAD", "msg": "Négatif extraction. Ils sont organisés. Les gros encaissent pour protéger les rapides. Demande renfort immédiat."},
	4: {"from": "SIGMA-3", "msg": "Sigma-7, ici Sigma-3. On capte des interférences massives sur toutes les fréquences. Vos coordonnées sont... *statique*"},
	5: {"from": "SIGMA-7 LEAD", "msg": "Un meneur. Massif. Il dirige les assauts. Si on l'abat, peut-être que les autres se replieront..."},
	
	# === ACT II — LES MORTS SE RELÈVENT ===
	6: {"from": "DERNIER SURVIVANT", "msg": "...l'unité est tombée. Je suis le dernier. Et les corps... les corps de mes hommes... ils bougent encore."},
	7: {"from": "DERNIER SURVIVANT", "msg": "Nouveaux hostiles. Ils ressemblent à des mages. Lancent des projectiles d'énergie sombre. Ça draine les forces."},
	8: {"from": "DERNIER SURVIVANT", "msg": "Des formes translucides. Des spectres. Les balles les traversent quand ils disparaissent. Je deviens fou."},
	9: {"from": "???", "msg": "*statique prolongée* ...la faille... elle s'agrandit... chaque mort la nourrit... vous ne comprenez pas... *signal perdu*"},
	10: {"from": "DERNIER SURVIVANT", "msg": "Un squelette colossal. Il porte une armure ancienne. La montagne recrache ses guerriers morts depuis des siècles."},
	
	# === ACT III — L'ESCALADE ===
	11: {"from": "DERNIER SURVIVANT", "msg": "La faille pulse comme un coeur. Plus je tue, plus elle s'ouvre. C'est un piège. Un cercle sans fin."},
	12: {"from": "QG OTAN", "msg": "*signal faible* ...évacuation du secteur impossible... zone de quarantaine établie... frappes aériennes en discussion..."},
	13: {"from": "DERNIER SURVIVANT", "msg": "Ils arrivent des deux côtés. Orcs par la faille, morts-vivants du sol. Ils ne se combattent pas entre eux."},
	14: {"from": "DERNIER SURVIVANT", "msg": "J'ai trouvé un dépôt de munitions sous les décombres. Quelqu'un savait. Quelqu'un avait prévu."},
	15: {"from": "QG OTAN", "msg": "Sigma-7, frappe aérienne refusée. La faille émet un champ magnétique qui dévie les missiles. Vous êtes seul. Désolé."},
	16: {"from": "DERNIER SURVIVANT", "msg": "Seul. Ça ne change rien. Tant que j'ai des balles, cette faille ne s'étend pas plus loin."},
	17: {"from": "???", "msg": "*interférence* ...d'autres failles... Oural... Alpes... Andes... *transmission corrompue*"},
	18: {"from": "DERNIER SURVIVANT", "msg": "Chaque vague plus forte que la précédente. Mais je m'adapte. C'est ce qu'on fait. On s'adapte ou on meurt."},
	19: {"from": "DERNIER SURVIVANT", "msg": "Si quelqu'un capte ce message... ne venez pas me chercher. Tenez les autres failles. Celle-ci, c'est mon combat."},
	20: {"from": "QG OTAN", "msg": "Sigma-7... nous perdons le contact avec d'autres unités partout dans le monde. Vous n'êtes pas le seul front. Tenez bon."},
}

var RADIO_LATE_GAME := [
	{"from": "DERNIER SURVIVANT", "msg": "Encore une vague. Toujours debout."},
	{"from": "???", "msg": "*statique* ...ils ne s'arrêteront jamais... la faille est éternelle... *statique*"},
	{"from": "DERNIER SURVIVANT", "msg": "Les munitions s'épuisent. La faille, jamais."},
	{"from": "DERNIER SURVIVANT", "msg": "Je ne compte plus les morts. Ni les miens, ni les leurs."},
	{"from": "???", "msg": "*fragment corrompu* ...de l'autre côté du portail... une armée entière attend... *signal perdu*"},
	{"from": "DERNIER SURVIVANT", "msg": "Combien de temps encore ? Aucune importance. Ici, le temps n'existe plus."},
	{"from": "QG OTAN", "msg": "*signal très faible* ...front de l'Oural tombé... Alpes tiennent encore... continuez... *fin de transmission*"},
	{"from": "DERNIER SURVIVANT", "msg": "Je commence à comprendre leur langage. Les cris des orcs. Les murmures des morts. C'est pas bon signe."},
]

# ==================== GUARANTEED DROP SCHEDULE ====================

const GUARANTEED_DROPS := {
	3:  "shotgun",   # First upgrade: crowd control
	5:  "sniper",    # Reward for surviving the first boss
	8:  "minigun",   # Mid-game power spike
	10: "rocket",    # Second boss reward
}

# ==================== RESOURCES ====================

var enemy_scene    = preload("res://Scenes/Main/Enemy/enemy.tscn")
var gameover_sound = preload("res://Sounds/game_over.wav")

var icon_heart       = preload("res://Scenes/Main/HUD/Sprites/icon_heart.png")
var icon_heart_empty = preload("res://Scenes/Main/HUD/Sprites/icon_heart_empty.png")
var icon_pistol      = preload("res://Scenes/Main/HUD/Sprites/icon_pistol.png")
var icon_shotgun     = preload("res://Scenes/Main/HUD/Sprites/icon_shotgun.png")
var icon_sniper      = preload("res://Scenes/Main/HUD/Sprites/icon_sniper.png")
var icon_assault     = preload("res://Scenes/Main/HUD/Sprites/icon_assault.png")
var icon_minigun     = preload("res://Scenes/Main/HUD/Sprites/icon_minigun.png")
var icon_rocket      = preload("res://Scenes/Main/HUD/Sprites/icon_rocket.png")
var icon_grenade     = preload("res://Scenes/Main/HUD/Sprites/icon_grenade.png")
var icon_dash        = preload("res://Scenes/Main/HUD/Sprites/icon_dash.png")
var icon_mine        = preload("res://Scenes/Main/HUD/Sprites/icon_mine.png")

@onready var score_label = $CanvasLayer/MarginContainer/Label

# ==================== INITIALIZATION ====================

func _ready() -> void:
	$Timer.timeout.connect(_on_timer_timeout)
	$Timer.stop()
	_create_obstacles()
	_create_walls()
	_create_top_hud()
	_create_weapon_hud()
	_create_boss_bar()
	_create_radio_display()
	_create_pause_menu()
	_show_radio_message(1)
	await get_tree().create_timer(1.0).timeout
	_start_next_wave()

# ==================== MAP SETUP ====================

var obstacle_types := [
	{"texture": "res://Scenes/Main/Sprites/crate.png",   "size": Vector2(32, 32)},
	{"texture": "res://Scenes/Main/Sprites/barrel.png",  "size": Vector2(28, 28)},
	{"texture": "res://Scenes/Main/Sprites/sandbag.png", "size": Vector2(36, 24)},
]

func _create_obstacles() -> void:
	var player_spawn = Vector2(87, 129)
	var placed : Array[Vector2] = []

	for i in randi_range(8, 14):
		var pos   := Vector2.ZERO
		var valid := false
		
		for _a in 30:
			pos = Vector2(randf_range(50, map_size.x - 50), randf_range(50, map_size.y - 50))
			if pos.distance_to(player_spawn) < 80: continue
			
			var ok := true
			
			for p in placed:
				if pos.distance_to(p) < 45: ok = false; break
			if ok: valid = true; break
		
		if valid:
			placed.append(pos)
			_spawn_obstacle(pos, obstacle_types[randi() % obstacle_types.size()])

	# Add 1–3 tight clusters of crates
	for _c in randi_range(1, 3):
		var center = Vector2(randf_range(150, map_size.x - 150), randf_range(100, map_size.y - 100))
		if center.distance_to(player_spawn) < 100: continue
		for _j in randi_range(2, 3):
			var cpos = center + Vector2(randf_range(-30, 30), randf_range(-20, 20))
			
			var ok := true
			
			for p in placed:
				if cpos.distance_to(p) < 30: ok = false; break
			if ok:
				placed.append(cpos)
				_spawn_obstacle(cpos, obstacle_types[0])

func _spawn_obstacle(pos: Vector2, type: Dictionary) -> void:
	var body = StaticBody2D.new()
	var spr  = Sprite2D.new()
	var col  = CollisionShape2D.new()
	var shp  = RectangleShape2D.new()
	spr.texture = load(type["texture"]); shp.size = type["size"]
	col.shape = shp; body.collision_layer = 16; body.collision_mask = 0
	body.add_child(spr); body.add_child(col); body.position = pos; add_child(body)

func _create_walls() -> void:
	var t := 16.0
	for w in [
		{"pos": Vector2(map_size.x / 2, t / 2),             "size": Vector2(map_size.x, t)},
		{"pos": Vector2(map_size.x / 2, map_size.y - t / 2),"size": Vector2(map_size.x, t)},
		{"pos": Vector2(t / 2, map_size.y / 2),             "size": Vector2(t, map_size.y)},
		{"pos": Vector2(map_size.x - t / 2, map_size.y / 2),"size": Vector2(t, map_size.y)},
	]:
		var body = StaticBody2D.new(); var spr = Sprite2D.new()
		var col  = CollisionShape2D.new(); var shp = RectangleShape2D.new()
		shp.size = w["size"]; col.shape = shp
		spr.region_enabled = true; spr.region_rect = Rect2(Vector2.ZERO, w["size"])
		spr.texture = preload("res://Scenes/Main/Sprites/wall_brick.png")
		spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		body.collision_layer = 16; body.collision_mask = 1 | 16
		body.position = w["pos"]; body.add_child(spr); body.add_child(col); add_child(body)

# ==================== TOP HUD (hearts + wave + score) ====================

func _create_top_hud() -> void:
	var hud = HBoxContainer.new()
	hud.anchor_right = 1.0; hud.offset_left = 8; hud.offset_top = 4; hud.offset_right = -8
	hud.add_theme_constant_override("separation", 8)
	$CanvasLayer.add_child(hud)
	
	# Hearts
	hearts_container = HBoxContainer.new()
	hearts_container.add_theme_constant_override("separation", 1)
	hud.add_child(hearts_container)
	for i in 5:
		var h = TextureRect.new()
		h.texture = icon_heart; h.stretch_mode = TextureRect.STRETCH_KEEP
		h.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		hearts_container.add_child(h)

	# Separator
	var sep = Label.new(); sep.text = "|"
	sep.add_theme_font_size_override("font_size", 10); sep.modulate = Color(1, 1, 1, 0.25)
	hud.add_child(sep)

	# Wave
	wave_label = Label.new(); wave_label.text = "Wave 1"
	wave_label.add_theme_font_size_override("font_size", 12); hud.add_child(wave_label)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hud.add_child(spacer)

	# Escape
	var esc_hint = Label.new(); esc_hint.text = "[ESC] Pause"
	esc_hint.add_theme_font_size_override("font_size", 9); esc_hint.modulate = Color(1, 1, 1, 0.28)
	hud.add_child(esc_hint)

	# Score (right)
	score_display = Label.new(); score_display.text = "0"
	score_display.add_theme_font_size_override("font_size", 12)
	score_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_display.size_flags_horizontal = Control.SIZE_SHRINK_END
	hud.add_child(score_display)

	# Hide the tscn label
	score_label.visible = false

# ==================== BOTTOM WEAPON HUD (3 slots) ====================

func _create_weapon_hud() -> void:
	# Panel anchored bottom-left
	var panel = PanelContainer.new()
	panel.anchor_left = 0.0; panel.anchor_top = 1.0; panel.anchor_bottom = 1.0
	panel.offset_left = 6; panel.offset_bottom = -6; panel.offset_top = -36; panel.offset_right = 370
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.50); style.border_color = Color(1, 1, 1, 0.12)
	style.set_border_width_all(1); style.set_corner_radius_all(3)
	style.content_margin_left = 6; style.content_margin_right = 6
	style.content_margin_top = 4; style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4); panel.add_child(hbox)

	# Build 3 inventory slots
	var slot_keys := ["[1]", "[2]", "[3]"]
	for s in 3:
		var sp = PanelContainer.new()
		var ss = StyleBoxFlat.new()
		ss.bg_color = Color(0, 0, 0, 0); ss.border_color = Color(1, 1, 1, 0)
		ss.set_border_width_all(1); ss.set_corner_radius_all(2)
		ss.content_margin_left = 4; ss.content_margin_right = 4
		ss.content_margin_top = 2; ss.content_margin_bottom = 2
		sp.add_theme_stylebox_override("panel", ss)
		sp.custom_minimum_size = Vector2(95, 26)
		inv_panels.append(sp)

		var sh = HBoxContainer.new()
		sh.add_theme_constant_override("separation", 3); sp.add_child(sh)

		var kl = Label.new(); kl.text = slot_keys[s]
		kl.add_theme_font_size_override("font_size", 8); kl.modulate = Color(1, 1, 1, 0.35)
		sh.add_child(kl)

		var ir = TextureRect.new()
		ir.texture = icon_pistol if s == 0 else null
		ir.stretch_mode = TextureRect.STRETCH_KEEP
		ir.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sh.add_child(ir); inv_icons.append(ir)

		var al = Label.new(); al.text = "∞" if s == 0 else ""
		al.add_theme_font_size_override("font_size", 9); al.modulate = Color(0.8, 0.8, 0.8)
		sh.add_child(al); inv_ammos.append(al)

		hbox.add_child(sp)
		if s < 2:
			var d = Label.new(); d.text = "|"
			d.add_theme_font_size_override("font_size", 10); d.modulate = Color(1, 1, 1, 0.15)
			hbox.add_child(d)

	# [G] swap reminder
	var g_hint = Label.new(); g_hint.text = "[G] Swap"
	g_hint.add_theme_font_size_override("font_size", 8); g_hint.modulate = Color(1.0, 0.85, 0.3, 0.6)
	hbox.add_child(g_hint)

	# Utility icons (grenade / dash / mine)
	var div1 = Label.new(); div1.text = "|"
	div1.add_theme_font_size_override("font_size", 10); div1.modulate = Color(1, 1, 1, 0.15)
	hbox.add_child(div1)

	# Grenade icon
	grenade_icon = TextureRect.new(); grenade_icon.texture = icon_grenade
	grenade_icon.stretch_mode = TextureRect.STRETCH_KEEP
	grenade_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; hbox.add_child(grenade_icon)

	# Dash icon
	dash_icon = TextureRect.new(); dash_icon.texture = icon_dash
	dash_icon.stretch_mode = TextureRect.STRETCH_KEEP
	dash_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; hbox.add_child(dash_icon)

	# Mine icon
	mine_icon = TextureRect.new(); mine_icon.texture = icon_mine
	mine_icon.stretch_mode = TextureRect.STRETCH_KEEP
	mine_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; hbox.add_child(mine_icon)

	var div2 = Label.new(); div2.text = "|"
	div2.add_theme_font_size_override("font_size", 10); div2.modulate = Color(1, 1, 1, 0.15)
	hbox.add_child(div2)

	fire_mode_label = Label.new(); fire_mode_label.text = ""
	fire_mode_label.add_theme_font_size_override("font_size", 9)
	fire_mode_label.modulate = Color(0.6, 0.8, 1.0)
	hbox.add_child(fire_mode_label)

	$CanvasLayer.add_child(panel)

# ==================== HUD UPDATE ====================

func _update_hud() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player: return

	# Heart icons
	for i in hearts_container.get_child_count():
		var h = hearts_container.get_child(i) as TextureRect
		h.texture = icon_heart if i < player.health else icon_heart_empty

	# Weapon icon
	var weapon_icons := {
		"pistol":icon_pistol, "shotgun":icon_shotgun, "sniper":icon_sniper,
		"assault":icon_assault, "minigun":icon_minigun, "rocket":icon_rocket,
	}
	# Border colour matches drop rarity
	var rarity_colors := {
		"pistol":  Color(0.5,  0.5,  0.5,  0.5),
		"shotgun": Color(0.85, 0.85, 0.85, 0.6),
		"assault": Color(0.85, 0.85, 0.85, 0.6),
		"sniper":  Color(0.25, 0.55, 1.0,  0.7),
		"minigun": Color(0.25, 0.55, 1.0,  0.7),
		"rocket":  Color(1.0,  0.45, 0.0,  0.85),
	}

	for s in 3:
		var sp : PanelContainer = inv_panels[s]
		var ir : TextureRect    = inv_icons[s]
		var al : Label          = inv_ammos[s]
		var ss : StyleBoxFlat   = sp.get_theme_stylebox("panel")

		if s < player.weapons.size():
			var w          = player.weapons[s]
			var is_current = (w == player.current_weapon)
			ir.texture     = weapon_icons.get(w, icon_pistol)
			ir.modulate    = Color.WHITE if is_current else Color(1, 1, 1, 0.45)

			if player.is_reloading and is_current:
				al.text     = "RELOADING"
				al.modulate = Color(0.7, 0.7, 1.0)
			else:
				var mag   = player.current_mag.get(w, 0)
				var stock = player.current_stock.get(w, 0)
				al.text   = ("%d|∞" % mag) if stock == -1 else ("%d|%d" % [mag, stock])
				if mag == 0 and stock == 0:
					al.modulate = Color(1.0, 0.2, 0.2)
				elif mag <= 2:
					al.modulate = Color(1.0, 0.7, 0.3)
				else:
					al.modulate = Color(0.85, 0.85, 0.85)

			if is_current:
				ss.bg_color     = Color(0.15, 0.15, 0.15, 0.7)
				ss.border_color = rarity_colors.get(w, Color(1, 1, 1, 0.4))
			else:
				ss.bg_color     = Color(0, 0, 0, 0)
				ss.border_color = Color(1, 1, 1, 0.08)
		else:
			ir.texture      = null
			al.text         = "— Aucune —"
			al.modulate     = Color(1, 1, 1, 0.2)
			ss.bg_color     = Color(0, 0, 0, 0)
			ss.border_color = Color(1, 1, 1, 0.05)

	# Cooldowns icons
	grenade_icon.modulate = Color.WHITE if player.can_grenade else Color(1, 1, 1, 0.3)
	dash_icon.modulate    = Color.WHITE if player.can_dash    else Color(1, 1, 1, 0.3)
	mine_icon.modulate    = Color.WHITE if player.can_mine    else Color(1, 1, 1, 0.3)

	# Fire mode (assault / minigun only)
	if current_weapon_name in ["assault", "minigun"]:
		var mode_names  := {"auto": "AUTO", "burst": "BURST", "semi": "SEMI"}
		var mode_colors := {
			"auto":  Color(0.6, 0.8, 1.0),
			"burst": Color(1.0, 0.8, 0.3),
			"semi":  Color(0.5, 1.0, 0.5),
		}
		fire_mode_label.text     = "[B] %s" % mode_names.get(player.current_fire_mode, "AUTO")
		fire_mode_label.modulate = mode_colors.get(player.current_fire_mode, Color.WHITE)
		fire_mode_label.visible  = true
	else:
		fire_mode_label.visible = false

	# Wave display
	if between_waves:
		wave_label.text = "Prochaine vague..."; wave_label.modulate = Color.WHITE
	elif current_wave % 5 == 0 and boss_alive:
		wave_label.text = "Vague %s — BOSS!" % current_wave; wave_label.modulate = Color.RED
	else:
		wave_label.text = "Vague %s" % current_wave; wave_label.modulate = Color.WHITE
		
	# Score
	score_display.text = "Score: %s" % score

func on_weapon_changed(weapon: String) -> void:
	current_weapon_name = weapon

func on_fire_mode_changed(_mode: String) -> void:
	pass

# ==================== GUARANTEED WEAPON DROPS ====================

func _spawn_guaranteed_drop(weapon: String) -> void:
	if not ResourceLoader.exists("res://Scenes/WeaponDrop/weapon_drop.tscn"):
		return
	var scene = load("res://Scenes/WeaponDrop/weapon_drop.tscn")
	var drop  = scene.instantiate()
	drop.setup(weapon)
	drop.global_position = Vector2(randf_range(200, 760), randf_range(120, 420))
	add_child(drop)
	_show_drop_announcement(weapon)

# Brief floating announcement when a guaranteed drop spawns on the map.
func _show_drop_announcement(weapon: String) -> void:
	var names  := {"shotgun":"SHOTGUN","assault":"ASSAULT","sniper":"SNIPER","minigun":"MINIGUN","rocket":"ROCKET"}
	var colors := {
		"shotgun": Color(0.85, 0.85, 0.85),
		"assault": Color(0.85, 0.85, 0.85),
		"sniper":  Color(0.25, 0.55, 1.0),
		"minigun": Color(0.25, 0.55, 1.0),
		"rocket":  Color(1.0,  0.45, 0.0),
	}
	var lbl = Label.new()
	lbl.text = "▼  %s DROPPED !" % names.get(weapon, weapon.to_upper())
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.modulate = colors.get(weapon, Color.WHITE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.anchor_left = 0.5; lbl.anchor_right = 0.5; lbl.anchor_top = 0.18
	lbl.offset_left = -150; lbl.offset_right = 150
	$CanvasLayer.add_child(lbl)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position:y", lbl.position.y - 14, 1.5)
	tween.tween_property(lbl, "modulate:a", 0.0, 1.5)
	tween.chain().tween_callback(lbl.queue_free)

# ==================== BOSS HP BAR ====================

func _create_boss_bar() -> void:
	# Main container centered at top
	boss_bar_container = PanelContainer.new()
	boss_bar_container.anchor_left = 0.5
	boss_bar_container.anchor_right = 0.5
	boss_bar_container.anchor_top = 0.0
	boss_bar_container.offset_left = -120
	boss_bar_container.offset_right = 120
	boss_bar_container.offset_top = 22
	boss_bar_container.offset_bottom = 58
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.02, 0.02, 0.85)
	style.border_color = Color(0.6, 0.15, 0.1, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	boss_bar_container.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	boss_bar_container.add_child(vbox)
	
	# Boss name
	boss_name_label = Label.new()
	boss_name_label.text = "SEIGNEUR DE LA FAILLE"
	boss_name_label.add_theme_font_size_override("font_size", 9)
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.modulate = Color(1.0, 0.4, 0.3)
	vbox.add_child(boss_name_label)
	
	# Bar background
	var bar_wrapper = Control.new()
	bar_wrapper.custom_minimum_size = Vector2(boss_bar_width, 10)
	vbox.add_child(bar_wrapper)
	
	boss_bar_bg = ColorRect.new()
	boss_bar_bg.color = Color(0.15, 0.05, 0.05)
	boss_bar_bg.position = Vector2.ZERO
	boss_bar_bg.size = Vector2(boss_bar_width, 10)
	bar_wrapper.add_child(boss_bar_bg)
	
	# Bar fill
	boss_bar_fill = ColorRect.new()
	boss_bar_fill.color = Color(0.8, 0.15, 0.1)
	boss_bar_fill.position = Vector2.ZERO
	boss_bar_fill.size = Vector2(boss_bar_width, 10)
	bar_wrapper.add_child(boss_bar_fill)
	
	# HP text overlay
	boss_hp_label = Label.new()
	boss_hp_label.add_theme_font_size_override("font_size", 8)
	boss_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_hp_label.position = Vector2(0, -1)
	boss_hp_label.size = Vector2(boss_bar_width, 12)
	bar_wrapper.add_child(boss_hp_label)
	
	$CanvasLayer.add_child(boss_bar_container)
	boss_bar_container.visible = false

func update_boss_hp(hp: int, max_hp: int) -> void:
	if not is_instance_valid(boss_bar_container):
		return
	boss_bar_container.visible = true
	var ratio = float(hp) / float(max_hp)
	boss_bar_fill.size.x = boss_bar_width * ratio
	boss_hp_label.text = "%s / %s" % [hp, max_hp]
	
	# Color shifts as HP drops
	if ratio > 0.5:
		boss_bar_fill.color = Color(0.8, 0.15, 0.1)
	elif ratio > 0.25:
		boss_bar_fill.color = Color(0.9, 0.4, 0.1)
	else:
		boss_bar_fill.color = Color(1.0, 0.7, 0.1)

func _show_boss_bar() -> void:
	boss_bar_container.visible = true
	boss_bar_fill.size.x = boss_bar_width
	boss_hp_label.text = ""
	
	# Boss name by wave
	var wave_tier = current_wave / 5
	var boss_names := [
		"Seigneur de la Faille",
		"Gardien des Ombres",
		"Roi des Morts",
		"Archonte Déchu",
		"Titan de l'Abîme",
	]
	boss_name_label.text = boss_names[min(wave_tier - 1, boss_names.size() - 1)]

func _hide_boss_bar() -> void:
	if is_instance_valid(boss_bar_container):
		boss_bar_container.visible = false

func on_boss_killed() -> void:
	boss_alive = false
	_hide_boss_bar()

# ==================== RADIO DISPLAY ====================

func _create_radio_display() -> void:
	radio_container = PanelContainer.new()
	radio_container.anchor_left = 0.1
	radio_container.anchor_right = 0.9
	radio_container.anchor_top = 0.78
	radio_container.anchor_bottom = 0.95
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.05, 0.85)
	style.border_color = Color(0.2, 0.4, 0.2, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	radio_container.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	radio_container.add_child(vbox)
	
	radio_callsign = Label.new()
	radio_callsign.add_theme_font_size_override("font_size", 9)
	radio_callsign.modulate = Color(0.3, 0.8, 0.3)
	vbox.add_child(radio_callsign)
	
	radio_label = Label.new()
	radio_label.add_theme_font_size_override("font_size", 11)
	radio_label.modulate = Color(0.7, 0.9, 0.7)
	radio_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(radio_label)
	
	$CanvasLayer.add_child(radio_container)
	radio_container.visible = false

func _show_radio_message(wave: int) -> void:
	var data : Dictionary
	
	if RADIO_MESSAGES.has(wave):
		data = RADIO_MESSAGES[wave]
	elif wave > 20:
		data = RADIO_LATE_GAME[(wave - 21) % RADIO_LATE_GAME.size()]
	else:
		return
	
	radio_callsign.text = "[RADIO — %s]" % data["from"]
	radio_label.text = ""
	radio_container.visible = true
	radio_container.modulate = Color(1, 1, 1, 0)
	radio_visible = true
	
	# Fade in
	if radio_tween:
		radio_tween.kill()
	radio_tween = create_tween()
	radio_tween.tween_property(radio_container, "modulate", Color(1, 1, 1, 1), 0.3)
	await radio_tween.finished
	
	# Typewriter effect
	var full_text = data["msg"]
	for i in full_text.length():
		if not radio_visible:
			break
		radio_label.text = full_text.substr(0, i + 1)
		
		var c = full_text[i]
		if c == "." or c == "!" or c == "?":
			await get_tree().create_timer(0.12).timeout
		elif c == "," or c == ":":
			await get_tree().create_timer(0.06).timeout
		elif c == "*":
			await get_tree().create_timer(0.04).timeout
		else:
			await get_tree().create_timer(0.02).timeout
	
	# Hold
	var hold_time = clamp(full_text.length() * 0.04, 2.5, 6.0)
	await get_tree().create_timer(hold_time).timeout
	
	# Fade out
	if is_instance_valid(radio_container) and radio_visible:
		radio_tween = create_tween()
		radio_tween.tween_property(radio_container, "modulate", Color(1, 1, 1, 0), 0.5)
		await radio_tween.finished
		if is_instance_valid(radio_container):
			radio_container.visible = false
			
	radio_visible = false

func _hide_radio() -> void:
	radio_visible = false
	
	if is_instance_valid(radio_container):
		radio_container.visible = false
	
	if radio_tween:
		radio_tween.kill()

# ==================== PAUSE MENU ====================

func _create_pause_menu() -> void:
	# Full-screen dark overlay
	pause_overlay = ColorRect.new()
	pause_overlay.color = Color(0.0, 0.0, 0.0, 0.6)
	pause_overlay.anchor_right = 1.0
	pause_overlay.anchor_bottom = 1.0
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	# Must keep processing while game is paused
	pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_overlay.visible = false
	$CanvasLayer.add_child(pause_overlay)
	
	# Dedicated input handler — only this node runs during pause
	var handler = Node.new()
	handler.name = "PauseHandler"
	handler.process_mode = Node.PROCESS_MODE_ALWAYS
	var script = GDScript.new()
	script.source_code = 'extends Node

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		var main = get_tree().current_scene
		if not main.is_game_over:
			main._toggle_pause()
'
	script.reload()
	handler.set_script(script)
	add_child(handler)
	
	# Centered container for menu items
	pause_container = VBoxContainer.new()
	pause_container.anchor_left = 0.5
	pause_container.anchor_right = 0.5
	pause_container.anchor_top = 0.3
	pause_container.offset_left = -80
	pause_container.offset_right = 80
	pause_container.add_theme_constant_override("separation", 10)
	pause_container.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_overlay.add_child(pause_container)
	
	# Title
	var title = Label.new()
	title.text = "PAUSE"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_container.add_child(title)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	pause_container.add_child(spacer)
	
	# Resume button
	var resume_btn = Button.new()
	resume_btn.text = "REPRENDRE"
	resume_btn.add_theme_font_size_override("font_size", 14)
	resume_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	resume_btn.pressed.connect(_toggle_pause)
	pause_container.add_child(resume_btn)
	
	# Quit to title button
	var quit_btn = Button.new()
	quit_btn.text = "MENU PRINCIPAL"
	quit_btn.add_theme_font_size_override("font_size", 14)
	quit_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	quit_btn.pressed.connect(_quit_to_title)
	pause_container.add_child(quit_btn)
	
	# Controls reminder
	var controls = Label.new()
	controls.text = "ZQSD - Move  |  LMB - Shoot  |  RMB - Grenade  |  ESC - Pause\nF - Mine  |  Space - Dash  |  B - Fire Mode  |  R - Rechargement\n1/2/3 - Weapons  |  G - Swap l'arme au sol  |  Molette - Cycle"
	controls.add_theme_font_size_override("font_size", 8)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.modulate = Color(1, 1, 1, 0.4)
	pause_container.add_child(controls)

func _toggle_pause() -> void:
	is_paused = not is_paused
	get_tree().paused = is_paused
	pause_overlay.visible = is_paused

func _quit_to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/Title/title.tscn")

# ==================== WAVE SYSTEM ====================

func _start_next_wave() -> void:
	current_wave += 1
	wave_active = true
	between_waves = false

	# Spawn guaranteed weapon drop if this wave has one scheduled
	if GUARANTEED_DROPS.has(current_wave):
		_spawn_guaranteed_drop(GUARANTEED_DROPS[current_wave])

	_show_wave_announcement()

	if current_wave % 5 == 0:
		enemies_to_spawn = 1
		boss_alive = true
	else:
		enemies_to_spawn = 5 + current_wave * 3

	spawn_interval         = max(0.3, 1.2 - current_wave * 0.05)
	$Timer.wait_time       = spawn_interval
	$Timer.start()

# ==================== WAVE ANNOUNCEMENT ====================

# Enemy types introduced per wave
const WAVE_INTRO := {
	2:  "Ennemis rapides en approche !",
	3:  "Les tanks arrivent.",
	4:  "Les shamans rejoignent la horde.",
	6:  "Volatiles détectés — gardez vos distances.",
	7:  "Les nécromanciens ressuscitent vos morts.",
	8:  "Spectres détectés — visez vite.",
}

# Displays a fullscreen wave title + subtitle for 2 seconds
func _show_wave_announcement() -> void:
	var is_boss_wave = current_wave % 5 == 0

	var container = PanelContainer.new()
	container.anchor_left  = 0.5; container.anchor_right = 0.5
	container.anchor_top   = 0.06
	container.offset_left  = -140; container.offset_right = 140
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.55)
	style.set_border_width_all(0); style.set_corner_radius_all(3)
	style.content_margin_left = 10; style.content_margin_right = 10
	style.content_margin_top = 5;  style.content_margin_bottom = 5
	container.add_theme_stylebox_override("panel", style)
	container.modulate = Color(1, 1, 1, 0)
	$CanvasLayer.add_child(container)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	container.add_child(vbox)

	# Wave title
	var title = Label.new()
	title.text = ("— VAGUE %d — BOSS" if is_boss_wave else "— VAGUE %d —") % current_wave
	title.add_theme_font_size_override("font_size", 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = Color(1.0, 0.35, 0.35) if is_boss_wave else Color(1, 1, 1)
	vbox.add_child(title)

	# Subtitle
	var subtitle = Label.new()
	if is_boss_wave:                   subtitle.text = "Un boss approche..."
	elif WAVE_INTRO.has(current_wave): subtitle.text = WAVE_INTRO[current_wave]
	else:                              subtitle.text = "La horde grossit."
	subtitle.add_theme_font_size_override("font_size", 9)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(0.8, 0.8, 0.8)
	vbox.add_child(subtitle)

	var tw = create_tween()
	tw.tween_property(container, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.6)
	tw.tween_property(container, "modulate:a", 0.0, 0.3)
	tw.tween_callback(container.queue_free)

func _start_intermission() -> void:
	between_waves = true
	await _show_radio_message(current_wave)
	
	if not is_game_over:
		await get_tree().create_timer(1.0).timeout
		_start_next_wave()

# ==================== GAME LOOP ====================

func _process(_delta) -> void:
	if is_game_over or is_paused:
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
	# Skip radio with Enter
	if radio_visible and event.is_action_pressed("ui_accept"):
		_hide_radio()
		return
	if is_game_over and event is InputEventKey and event.pressed:
		get_tree().change_scene_to_file("res://Scenes/Title/title.tscn")

func game_over() -> void:
	is_game_over = true
	_hide_boss_bar()
	is_paused = false
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
	if current_wave >= 2: types.append("fast")
	if current_wave >= 3: types.append("tank")
	if current_wave >= 4: types.append("shaman")
	if current_wave >= 6: types.append("volatile")
	if current_wave >= 7: types.append("necromancer")
	if current_wave >= 8: types.append("ghost")
	return types

func _pick_enemy_type() -> String:
	var types = _get_available_types()
	var weights := {"normal":30,"fast":25,"tank":10,"shaman":15,"necromancer":10,"volatile":12,"ghost":8}
	if types.size() > 4: weights["normal"] = 20
	if types.size() > 6: weights["normal"] = 15
	var pool := []; var total := 0.0
	for t in types: total += weights.get(t, 10); pool.append({"type": t, "cumulative": total})
	var roll = randf() * total
	for entry in pool:
		if roll <= entry["cumulative"]: return entry["type"]
	return "normal"

func _on_timer_timeout() -> void:
	if enemies_to_spawn <= 0: $Timer.stop(); return
	var enemy = enemy_scene.instantiate()
	if current_wave % 5 == 0:
		enemy.setup("boss"); enemies_to_spawn = 0; $Timer.stop(); _show_boss_bar()
	else:
		enemy.setup(_pick_enemy_type())
	var side   = randi() % 4
	var margin = 40.0
	match side:
		0: enemy.global_position = Vector2(randf() * map_size.x, margin)
		1: enemy.global_position = Vector2(randf() * map_size.x, map_size.y - margin)
		2: enemy.global_position = Vector2(margin,               randf() * map_size.y)
		3: enemy.global_position = Vector2(map_size.x - margin,  randf() * map_size.y)
	add_child(enemy); enemies_to_spawn -= 1; enemies_alive += 1
