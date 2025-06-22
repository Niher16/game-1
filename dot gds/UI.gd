# UI.gd - Fixed version with debug spam removed
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
	add_to_group('UI')
	print('✅ UI added to UI group')

	# Print all nodes in the UI group and their scripts
	await get_tree().process_frame
	var ui_nodes = get_tree().get_nodes_in_group('UI')
	print('🔍 UI Group contains: ', ui_nodes.size(), ' nodes')
	for node in ui_nodes:
		print('  - UI group node: ', node, ' name: ', node.name, ' script: ', node.get_script())

	# Test if call_group would work
	print('🧪 Testing call_group mechanism...')
	get_tree().call_group('UI', '_test_group_call')

	# Manual test call for XP update
	print('🧪 Manually calling _on_player_xp_changed for test')
	_on_player_xp_changed(42, 100, 2)

	_setup_ui()
	_find_references()
	_find_spawner_with_retry()



	add_to_group('UI')
	print('✅ UI added to UI group')

	# Verify group membership
	await get_tree().process_frame
	var ui_nodes_2 = get_tree().get_nodes_in_group('UI')
	print('🔍 UI Group contains: ', ui_nodes_2.size(), ' nodes')
	for node in ui_nodes_2:
		print('  - ', node.name, ' at path: ', node.get_path())

	# Test if call_group would work
	print('🧪 Testing call_group mechanism...')
	get_tree().call_group('UI', '_test_group_call')

	_setup_ui()
	_find_references()
	_find_spawner_with_retry()

func _test_group_call():
	print('✅ call_group test successful - UI can receive group calls')

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
	_create_speed_ui() # Add speed UI

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
	xp_bar = ProgressBar.new()
	xp_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	xp_bar.max_value = 100
	xp_bar.value = 0
	xp_bar.show_percentage = false
	panel.add_child(xp_bar)
	xp_label = Label.new()
	xp_label.text = "XP: 0/100 (Lv.1)"
	xp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xp_label.add_theme_font_size_override("font_size", 14)
	xp_label.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(xp_label)

func _create_unit_ui():
	var panel = _create_panel(Vector2(20, 270), Vector2(200, 50), Color.GREEN)
	unit_label = _create_label("🤝 Units: 0/3", panel)

func _create_speed_ui():
	var panel = _create_panel(Vector2(-220, 140), Vector2(200, 50), Color.SKY_BLUE) # moved down from y=80 to y=140
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	speed_label = _create_label("Speed: 0.0", panel)
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
		print("UI: Found player, connecting signals...")
		var allies = get_tree().get_nodes_in_group("allies")
		for ally in allies:
			if not ally.is_connected("ally_added", Callable(self, "_on_ally_added")):
				ally.connect("ally_added", Callable(self, "_on_ally_added"))
			if not ally.is_connected("ally_removed", Callable(self, "_on_ally_removed")):
				ally.connect("ally_removed", Callable(self, "_on_ally_removed"))
			# Connect ally_died signal for unit counter
			if ally.has_signal("ally_died") and not ally.is_connected("ally_died", Callable(self, "_on_ally_died")):
				ally.connect("ally_died", Callable(self, "_on_ally_died"))
		print("UI: Connected ally signals")
		# --- Force full UI update after UI is ready and player is found ---
		await get_tree().process_frame
		print('🟦 Calling force_full_ui_update from _find_references')
		force_full_ui_update()
		print('🟦 Returned from force_full_ui_update in _find_references')
	else:
		print("UI: Player not found!")
		await get_tree().create_timer(1.0).timeout
		_find_references()



	print("UI: Finding references...")
	player = get_tree().get_first_node_in_group("player")
	if player:
		print("UI: Found player, connecting signals...")
		var allies = get_tree().get_nodes_in_group("allies")
		for ally in allies:
			if not ally.is_connected("ally_added", Callable(self, "_on_ally_added")):
				ally.connect("ally_added", Callable(self, "_on_ally_added"))
			if not ally.is_connected("ally_removed", Callable(self, "_on_ally_removed")):
				ally.connect("ally_removed", Callable(self, "_on_ally_removed"))
			# Connect ally_died signal for unit counter
			if ally.has_signal("ally_died") and not ally.is_connected("ally_died", Callable(self, "_on_ally_died")):
				ally.connect("ally_died", Callable(self, "_on_ally_died"))
		print("UI: Connected ally signals")
	else:
		print("UI: Player not found!")
		await get_tree().create_timer(1.0).timeout
		_find_references()

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

func _on_player_xp_changed(xp: int, xp_to_next: int, level: int):
	print('🎯 UI XP Update: ', xp, '/', xp_to_next, ' Level: ', level)
	print('🟦 UI node name: ', name, ' path: ', get_path())
	if xp_bar:
		print('🟩 xp_bar exists, updating values')
		xp_bar.max_value = xp_to_next
		xp_bar.value = xp
	else:
		print('🟥 xp_bar is null!')
	if xp_label:
		print('🟩 xp_label exists, updating text')
		xp_label.text = "XP: %d/%d (Lv.%d)" % [xp, xp_to_next, level]
	else:
		print('🟥 xp_label is null!')
	_update_xp()
	print('🟦 _on_player_xp_changed finished')


	print('🎯 UI XP Update: ', xp, '/', xp_to_next, ' Level: ', level)
	if xp_bar:
		xp_bar.max_value = xp_to_next
		xp_bar.value = xp
	if xp_label:
		xp_label.text = "XP: %d/%d (Lv.%d)" % [xp, xp_to_next, level]
	_update_xp()



	print('🎯 UI DEBUG: _on_player_xp_changed called with: ', xp, '/', xp_to_next, ' Level: ', level)
	if xp_bar:
		xp_bar.max_value = xp_to_next
		xp_bar.value = xp
	if xp_label:
		xp_label.text = "XP: %d/%d (Lv.%d)" % [xp, xp_to_next, level]
	_update_xp()

func _on_player_coin_collected(amount: int):
	print("UI: coin_collected signal received - amount: ", amount)
	if player and coin_label and player.has_method("get_currency"):
		coin_label.text = "💰 Coins: " + str(player.get_currency())

func _on_player_health_changed(current: int, max_health: int):
	print('🎯 UI DEBUG: _on_player_health_changed called with: ', current, '/', max_health)
	if health_label:
		health_label.text = '❤️ Health: ' + str(current) + '/' + str(max_health)
		# Change color based on health percentage
		var health_percentage = float(current) / float(max_health) if max_health > 0 else 0.0
		if health_percentage <= 0.25:
			health_label.add_theme_color_override("font_color", Color.RED)
		elif health_percentage <= 0.5:
			health_label.add_theme_color_override("font_color", Color.ORANGE)
		else:
			health_label.add_theme_color_override("font_color", Color.WHITE)

func _process(_delta):
	if not player:
		return
	_update_wave()
	_update_dash()
	_update_speed()
	# Removed _update_health(), _update_coins(), _update_xp() - these use signals now

func _force_update_health():
	if player and health_label and player.has_method('get_health'):
		var current_health = player.get_health()
		var max_health = player.get_max_health()
		health_label.text = '❤️ Health: ' + str(current_health) + '/' + str(max_health)

func _force_update_coins():
	if player and coin_label and player.has_method('get_currency'):
		coin_label.text = '💰 Coins: ' + str(player.get_currency())

func _force_update_xp():
	if player and xp_bar and xp_label:
		if player.has_method('get_xp'):
			var current_xp = player.get_xp()
			var xp_needed = player.get_xp_to_next_level()
			var current_level = player.get_level()
			xp_bar.max_value = xp_needed
			xp_bar.value = current_xp
			xp_label.text = 'XP: %d/%d (Lv.%d)' % [current_xp, xp_needed, current_level]

func _update_health():
	if player.has_method("get_health"):
		var health = player.get_health()
		var max_health = player.get_max_health()
		health_label.text = "❤️ Health: " + str(health) + "/" + str(max_health)

func _update_coins():
	if player and coin_label and player.has_method("get_currency"):
		coin_label.text = "💰 Coins: " + str(player.get_currency())

func _update_wave():
	if spawner and spawner.has_method("get_wave_info"):
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
	else:
		if not spawner:
			wave_label.text = "⚔️ Wave: 1/5\n🚀 Spawning...\n(No spawner)"
		else:
			wave_label.text = "⚔️ Wave: 1/5\n🚀 Spawning...\n(No method)"

func _update_dash():
	if player.has_method("get_dash_charges"):
		var charges = player.get_dash_charges()
		var max_charges = player.get_max_dash_charges()
		dash_label.text = "⚡ Dash: Ready" if charges >= max_charges else "⚡ Dash: Charging..."

func _update_xp():
	if player and xp_bar and xp_label:
		var current_xp = player.get_xp() if player.has_method("get_xp") else 0
		var xp_needed = player.get_xp_to_next_level() if player.has_method("get_xp_to_next_level") else 100
		var current_level = player.get_level() if player.has_method("get_level") else 1
		xp_bar.max_value = xp_needed
		xp_bar.value = current_xp
		xp_label.text = "XP: %d/%d (Lv.%d)" % [current_xp, xp_needed, current_level]

func _update_units(current_units: int):
	if unit_label:
		unit_label.text = "🤝 Units: %d/%d" % [current_units, max_units]
		print("✅ Unit counter updated: ", current_units, " / ", max_units)
	else:
		print("❌ Unit label not found!")

func _update_speed():
	if not player or not speed_label:
		return
	# Try to get speed from stats_component first
	var stats_component = player.get("stats_component")
	if stats_component and stats_component.has_method("get_speed"):
		update_speed_display(stats_component.get_speed())
	# Fallback to direct speed property
	elif "speed" in player:
		update_speed_display(player.speed)
	else:
		update_speed_display(0.0)

func update_speed_display(speed: float):
	if speed_label:
		speed_label.text = "⚡ Speed: %.1f" % speed

func _on_ally_added():
	print("✅ Received ally_added signal.")
	_update_units(get_tree().get_nodes_in_group("allies").size())
	print("✅ Ally added, UI updated.")

func _on_ally_removed():
	print("✅ Received ally_removed signal.")
	_update_units(get_tree().get_nodes_in_group("allies").size())
	print("✅ Ally removed, UI updated.")

func _on_ally_died():
	var current_units = get_tree().get_nodes_in_group("allies").size()
	_update_units(current_units)
	print("✅ Ally died, UI unit counter updated: ", current_units)

# --- Temporary Feedback Message ---
var _message_label: Label = null

func show_message(text: String):
	if _message_label:
		_message_label.queue_free()
	_message_label = Label.new()
	_message_label.text = text
	_message_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_message_label.add_theme_font_size_override("font_size", 20)
	_message_label.add_theme_color_override("font_color", Color.YELLOW)
	_message_label.position = Vector2(0, 10)
	_message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message_label.size_flags_vertical = Control.SIZE_FILL
	add_child(_message_label)
	var tween = create_tween()
	tween.tween_property(_message_label, "modulate:a", 0.0, 2.0)
	tween.tween_callback(Callable(_message_label, "queue_free"))


func force_full_ui_update():
	print('🟦 force_full_ui_update called')
	print('🟦 player:', player)
	print('🟦 xp_bar:', xp_bar)
	print('🟦 xp_label:', xp_label)
	if player:
		print('🟦 player.has_method(get_xp):', player.has_method('get_xp'))
		print('🟦 player.has_method(get_xp_to_next_level):', player.has_method('get_xp_to_next_level'))
		print('🟦 player.has_method(get_level):', player.has_method('get_level'))
	if player and xp_bar and xp_label and player.has_method('get_xp') and player.has_method('get_xp_to_next_level') and player.has_method('get_level'):
		print('🟦 Forcing XP UI update from force_full_ui_update')
		_on_player_xp_changed(player.get_xp(), player.get_xp_to_next_level(), player.get_level())
	else:
		print('🟥 XP UI update conditions not met')
	if player and health_label and player.has_method('get_health') and player.has_method('get_max_health'):
		print('🟦 Forcing health UI update from force_full_ui_update')
		_on_player_health_changed(player.get_health(), player.get_max_health())
	if player and coin_label and player.has_method('get_currency'):
		print('🟦 Forcing coin UI update from force_full_ui_update')
		_on_player_coin_collected(player.get_currency())
