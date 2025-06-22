# UI.gd - FIXED VERSION with proper signal handling
extends Control

var player: Node3D
var spawner: Node3D = null
var max_units := 3

# UI Elements
var health_label: Label
var coin_label: Label
var wave_label: Label
var dash_label: Label
var powerup_label: Label
var xp_bar: ProgressBar
var xp_label: Label
var unit_label: Label
var speed_label: Label

func _ready():
	add_to_group("UI")
	print("✅ UI node added to group 'UI'")
	_setup_ui()
	_find_references()
	_find_spawner_with_retry()

func _setup_ui():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_create_health_ui()
	_create_coin_ui()
	_create_wave_ui()
	_create_dash_ui()
	_create_powerup_ui()
	_create_xp_ui()
	_create_unit_ui()
	_create_speed_ui()
	
	# Debug: Verify UI elements were created
	print("🔍 UI Elements created - xp_bar: ", xp_bar != null, " xp_label: ", xp_label != null)

func _create_health_ui():
	var panel = _create_panel(Vector2(20, 20), Vector2(180, 50), Color.RED)
	health_label = _create_label("❤️ Health: 100/100", panel)

func _create_coin_ui():
	var panel = _create_panel(Vector2(20, 80), Vector2(180, 50), Color.GOLD)
	coin_label = _create_label("💰 Coins: 0", panel)

func _create_wave_ui():
	var panel = _create_panel(Vector2(-220, 20), Vector2(200, 100), Color.PURPLE)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	wave_label = _create_label("⚔️ Wave: 1/5", panel)

func _create_dash_ui():
	var panel = _create_panel(Vector2(-100, -75), Vector2(200, 50), Color.CYAN)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	dash_label = _create_label("⚡ Dash: Ready", panel)

func _create_powerup_ui():
	var panel = _create_panel(Vector2(20, 150), Vector2(200, 50), Color.ORANGE)
	powerup_label = _create_label("", panel)
	panel.visible = false

func _create_xp_ui():
	var panel = _create_panel(Vector2(20, 210), Vector2(200, 50), Color.SKY_BLUE)
	
	# Create XP Bar
	xp_bar = ProgressBar.new()
	xp_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	xp_bar.max_value = 100
	xp_bar.value = 0
	xp_bar.show_percentage = false
	panel.add_child(xp_bar)
	
	# Create XP Label
	xp_label = Label.new()
	xp_label.text = "XP: 0/100 (Lv.1)"
	xp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xp_label.add_theme_font_size_override("font_size", 14)
	xp_label.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(xp_label)
	
	print("✅ XP UI created - Bar: ", xp_bar != null, " Label: ", xp_label != null)

func _create_unit_ui():
	var panel = _create_panel(Vector2(20, 270), Vector2(200, 50), Color.GREEN)
	unit_label = _create_label("🤝 Units: 0/3", panel)

func _create_speed_ui():
	var panel = _create_panel(Vector2(-220, 140), Vector2(200, 50), Color.SKY_BLUE)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	speed_label = _create_label("⚡ Speed: 0.0", panel)
	speed_label.add_theme_font_size_override("font_size", 16)

@warning_ignore("shadowed_variable_base_class")
func _create_panel(pos: Vector2, size: Vector2, border_color: Color) -> Panel:
	var panel = Panel.new()
	panel.position = pos
	panel.size = size
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.8)
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	return panel

func _create_label(text: String, parent: Panel) -> Label:
	var label = Label.new()
	label.text = text
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color.WHITE)
	parent.add_child(label)
	return label

func _find_references():
	print("UI: Finding references...")
	player = get_tree().get_first_node_in_group("player")
	if player:
		print("UI: Found player!")
		# Don't try to connect signals directly - player uses call_group instead
		# Connect ally signals
		var allies = get_tree().get_nodes_in_group("allies")
		for ally in allies:
			_connect_ally_signals(ally)
		print("UI: Connected ally signals")
	else:
		print("UI: Player not found!")
		await get_tree().create_timer(1.0).timeout
		_find_references()

func _connect_ally_signals(ally):
	if ally.has_signal("ally_added") and not ally.is_connected("ally_added", Callable(self, "_on_ally_added")):
		ally.connect("ally_added", Callable(self, "_on_ally_added"))
	if ally.has_signal("ally_removed") and not ally.is_connected("ally_removed", Callable(self, "_on_ally_removed")):
		ally.connect("ally_removed", Callable(self, "_on_ally_removed"))
	if ally.has_signal("ally_died") and not ally.is_connected("ally_died", Callable(self, "_on_ally_died")):
		ally.connect("ally_died", Callable(self, "_on_ally_died"))

func _find_spawner_with_retry():
	spawner = get_tree().get_first_node_in_group("spawner")
	if spawner:
		print("✅ UI.gd: Spawner found!")
	else:
		print("🔄 UI.gd: Spawner not found, retrying in 0.5s...")
		var timer = Timer.new()
		timer.wait_time = 0.5
		timer.one_shot = true
		add_child(timer)
		timer.timeout.connect(_find_spawner_with_retry)
		timer.start()

# ===== SIGNAL HANDLERS (Called via call_group from player) =====
func _on_player_xp_changed(xp: int, xp_to_next: int, level: int):
	print("🎯 UI XP Update: ", xp, "/", xp_to_next, " Level: ", level)
	if xp_bar:
		xp_bar.max_value = xp_to_next
		xp_bar.value = xp
		print("✅ XP bar updated: ", xp, "/", xp_to_next)
	else:
		print("🟥 xp_bar is null!")
	
	if xp_label:
		xp_label.text = "XP: %d/%d (Lv.%d)" % [xp, xp_to_next, level]
		print("✅ XP label updated: ", xp_label.text)
	else:
		print("🟥 xp_label is null!")

func _on_player_coin_collected(amount: int):
	print("🎯 UI Coin Update: ", amount)
	_update_coins()

func _on_player_health_changed(current: int, max_health: int):
	print("🎯 UI Health Update: ", current, "/", max_health)
	if health_label:
		health_label.text = "❤️ Health: " + str(current) + "/" + str(max_health)
		# Change color based on health percentage
		var health_percentage = float(current) / float(max_health) if max_health > 0 else 0.0
		if health_percentage <= 0.25:
			health_label.add_theme_color_override("font_color", Color.RED)
		elif health_percentage <= 0.5:
			health_label.add_theme_color_override("font_color", Color.ORANGE)
		else:
			health_label.add_theme_color_override("font_color", Color.WHITE)
		print("✅ Health label updated: ", health_label.text)

# ===== FRAME-BASED UPDATES (Only for non-signal data) =====
func _process(_delta):
	if not player:
		return
	_update_coins()
	_update_wave()
	_update_dash()
	_update_speed()

func _update_coins():
	if player and coin_label and player.has_method("get_currency"):
		coin_label.text = "💰 Coins: " + str(player.get_currency())

func _update_wave():
	if not spawner or not wave_label:
		return
		
	if spawner.has_method("get_wave_info"):
		var info = spawner.get_wave_info()
		var current = info.get("current_wave", 1)
		var max_waves = info.get("max_waves", 5)
		var current_enemies = info.get("current_enemies", 0)
		var enemies_spawned = info.get("enemies_spawned", 0)
		var total_enemies_for_wave = info.get("total_enemies_for_wave", 0)
		var wave_active = info.get("wave_active", false)
		var is_spawning = info.get("is_spawning", false)
		
		var wave_text = "⚔️ Wave: " + str(current) + "/" + str(max_waves) + "\n"
		if total_enemies_for_wave == 0 and not wave_active and current == 1:
			wave_text += "🚀 Spawning...\n🚀 Get ready!"
		elif wave_active or (total_enemies_for_wave > 0):
			wave_text += "👹 Remaining: " + str(current_enemies) + "\n"
			if is_spawning and total_enemies_for_wave > 0:
				wave_text += "📊 Spawned: " + str(enemies_spawned) + "/" + str(total_enemies_for_wave)
			else:
				wave_text += "🎯 Defeat all enemies!" if current_enemies > 0 else "✅ Wave Complete!"
		else:
			if current > max_waves:
				wave_text += "🏆 ALL WAVES\n🏆 COMPLETE!"
			else:
				wave_text += "⏳ Next wave\n⏳ incoming..."
		wave_label.text = wave_text

func _update_dash():
	if not player or not dash_label:
		return
	if player.has_method("get_dash_charges"):
		var charges = player.get_dash_charges()
		var max_charges = player.get_max_dash_charges()
		dash_label.text = "⚡ Dash: Ready" if charges >= max_charges else "⚡ Dash: Charging..."

func _update_speed():
	if not player or not speed_label:
		return
	# Try to get speed from stats_component first
	var stats_component = player.get("stats_component")
	if stats_component and stats_component.has_method("get_speed"):
		speed_label.text = "⚡ Speed: %.1f" % stats_component.get_speed()
	# Fallback to direct speed property
	elif "speed" in player:
		speed_label.text = "⚡ Speed: %.1f" % player.speed
	else:
		speed_label.text = "⚡ Speed: 0.0"

# ===== ALLY SIGNAL HANDLERS =====
func _on_ally_added():
	print("✅ Received ally_added signal.")
	_update_units(get_tree().get_nodes_in_group("allies").size())

func _on_ally_removed():
	print("✅ Received ally_removed signal.")
	_update_units(get_tree().get_nodes_in_group("allies").size())

func _on_ally_died():
	print("✅ Received ally_died signal.")
	_update_units(get_tree().get_nodes_in_group("allies").size())

func _update_units(current_units: int):
	if unit_label:
		unit_label.text = "🤝 Units: %d/%d" % [current_units, max_units]
		print("✅ Unit counter updated: ", current_units, " / ", max_units)
