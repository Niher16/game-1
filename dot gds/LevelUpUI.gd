# Enhanced LevelUpUI.gd - Handles new perk types
extends Control

# Keep your existing UI references
@onready var button1 = $VBoxContainer/Button1
@onready var button2 = $VBoxContainer/Button2  
@onready var button3 = $VBoxContainer/Button3

var buttons = []
var current_options = []

# Controller navigation (keep existing code)
var controller_navigation_enabled := false
var selected_button_index := 0

func _ready():
	"""Initialize UI - Godot 4.1+ best practice with safety checks"""
	# Safety checks prevent crashes for beginners
	if not button1 or not button2 or not button3:
		push_error("❌ LevelUpUI: Required buttons not found! Check node paths.")
		return

	buttons = [button1, button2, button3]
	visible = false

	# Do NOT connect button signals or player progression here
	# Wait until level up event triggers to connect and show UI

func _connect_button_signals():
	"""Connect button signals with safety checks - prevents crashes"""
	for i in buttons.size():
		if buttons[i]:
			# Disconnect if already connected (prevents double connections)
			if buttons[i].is_connected("pressed", _on_upgrade_button_pressed):
				buttons[i].disconnect("pressed", _on_upgrade_button_pressed)
			buttons[i].pressed.connect(_on_upgrade_button_pressed.bind(i))
		else:
			push_warning("⚠️ Button " + str(i) + " is null in LevelUpUI")

func _connect_to_player_progression():
	"""Find player and connect to progression signals - includes safety checks"""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		push_warning("⚠️ LevelUpUI: Player not found in 'player' group")
		return
	
	if not player.progression_component:
		push_warning("⚠️ LevelUpUI: Player has no progression_component")
		return
	
	# Connect to show level up choices signal
	if not player.progression_component.is_connected("show_level_up_choices", _on_show_level_up_choices):
		player.progression_component.show_level_up_choices.connect(_on_show_level_up_choices)
		print("✅ LevelUpUI connected to player progression")

func _on_show_level_up_choices(options: Array):
	"""Handle incoming upgrade options - displays them with icons and descriptions"""
	# Connect button signals and player progression only when level up UI is needed
	_connect_button_signals()
	_connect_to_player_progression()
	print("🎯 LevelUpUI received upgrade options: ", options)
	
	# Safety check - prevent crashes from bad data
	if options.is_empty():
		push_warning("⚠️ No upgrade options received")
		return
	
	current_options = options
	_display_upgrade_options(options)
	_show_ui()

func _display_upgrade_options(options: Array):
	"""Display upgrade options on buttons with proper formatting"""
	for i in range(min(options.size(), buttons.size())):
		if buttons[i] and i < options.size():
			var option = options[i]
			
			# Safety check - ensure option has required fields
			if not option.has("title") or not option.has("description"):
				buttons[i].text = "❓ Unknown Upgrade"
				continue
			
			# Format button text with title and description
			var button_text = option.title + "\n" + option.description
			buttons[i].text = button_text
			
			# Add special styling for high-tier upgrades (level 5+)
			if option.has("type"):
				_style_button_for_upgrade_type(buttons[i], option.type)
		else:
			# Hide unused buttons if fewer than 3 options
			if buttons[i]:
				buttons[i].visible = false

func _style_button_for_upgrade_type(button: Button, upgrade_type: String):
	"""Add visual styling based on upgrade type - makes UI more engaging"""
	# Reset to default style first
	button.modulate = Color(1, 1, 1, 1)
	
	# Color-code different upgrade types (optional but cool!)
	match upgrade_type:
		"health", "health_regen":
			button.modulate = Color(1.2, 0.8, 0.8, 1)  # Red tint for health
		"damage", "attack_speed", "crit_chance":
			button.modulate = Color(1.2, 1.0, 0.7, 1)  # Yellow tint for combat
		"speed", "dash_charges", "dash_cooldown":
			button.modulate = Color(0.8, 1.0, 1.2, 1)  # Blue tint for movement
		"minion_count":
			button.modulate = Color(0.9, 1.2, 0.9, 1)  # Green tint for allies
		"berserker", "dash_shield":
			button.modulate = Color(1.3, 0.9, 1.3, 1)  # Purple tint for special abilities

func _show_ui():
	"""Show the level-up UI and pause game - includes controller support"""
	visible = true
	get_tree().paused = true
	
	# Controller navigation setup
	controller_navigation_enabled = Input.get_connected_joypads().size() > 0
	if controller_navigation_enabled:
		selected_button_index = 0
		_update_button_focus()
	else:
		# Mouse users can click normally
		if buttons[0]:
			buttons[0].grab_focus()

func _on_upgrade_button_pressed(button_index: int):
	"""Handle upgrade selection - applies the chosen upgrade"""
	print("🎯 LevelUpUI: Button " + str(button_index) + " pressed")
	
	# Safety checks prevent crashes
	if button_index < 0 or button_index >= current_options.size():
		push_error("❌ Invalid button index: " + str(button_index))
		return
	
	if current_options.is_empty():
		push_error("❌ No current options available")
		return
	
	_choose_upgrade(button_index)

func _choose_upgrade(index: int):
	"""Apply the selected upgrade and close UI"""
	print("🎯 Selected upgrade: ", current_options[index])
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		push_error("❌ ERROR: Player not found!")
		return
	
	if not player.progression_component:
		push_error("❌ ERROR: Player progression component not found!")
		return
	
	print("🎯 Calling apply_upgrade on progression component...")
	player.progression_component.apply_upgrade(current_options[index])
	
	_hide_ui()

func _hide_ui():
	"""Hide the UI and unpause game"""
	visible = false
	get_tree().paused = false
	
	# Clear current options for safety
	current_options.clear()
	
	# Reset button visibility
	for button in buttons:
		if button:
			button.visible = true
			button.modulate = Color(1, 1, 1, 1)  # Reset color

# CONTROLLER NAVIGATION (keep your existing controller code but with improvements)

func _input(event):
	"""Handle controller input for navigation - improved for beginners"""
	if not visible or not controller_navigation_enabled:
		return
	
	if event.is_action_pressed("ui_down"):
		selected_button_index = (selected_button_index + 1) % buttons.size()
		_update_button_focus()
		accept_event()
	elif event.is_action_pressed("ui_up"):
		selected_button_index = (selected_button_index - 1 + buttons.size()) % buttons.size()
		_update_button_focus()
		accept_event()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		# Check if selected button is visible and valid
		if selected_button_index < buttons.size() and buttons[selected_button_index] and buttons[selected_button_index].visible:
			_choose_upgrade(selected_button_index)
		accept_event()

func _update_button_focus():
	"""Update visual focus for controller users - improved accessibility"""
	for i in buttons.size():
		if buttons[i] and buttons[i].visible:
			if i == selected_button_index:
				buttons[i].modulate = Color(1.5, 1.5, 0.5, 1)  # Bright highlight
				buttons[i].grab_focus()
			else:
				# Restore original color based on upgrade type
				if i < current_options.size() and current_options[i].has("type"):
					_style_button_for_upgrade_type(buttons[i], current_options[i].type)
				else:
					buttons[i].modulate = Color(1, 1, 1, 1)  # Default

func _on_joy_connection_changed(_device_id: int, _connected: bool):
	"""Handle controller connection changes - helps beginners with controller setup"""
	controller_navigation_enabled = Input.get_connected_joypads().size() > 0
	if controller_navigation_enabled and visible:
		selected_button_index = 0
		_update_button_focus()
		print("🎮 Controller detected - navigation enabled")
	else:
		print("🖱️ Using mouse/keyboard navigation")

# DEBUGGING FUNCTIONS (helpful for beginners)

func _print_debug_info():
	"""Debug function to help troubleshoot issues"""
	print("=== LevelUpUI Debug Info ===")
	print("Visible: ", visible)
	print("Current options count: ", current_options.size())
	print("Buttons found: ", buttons.size())
	print("Controller enabled: ", controller_navigation_enabled)
	for i in buttons.size():
		if buttons[i]:
			print("Button ", i, ": ", buttons[i].text)
		else:
			print("Button ", i, ": NULL")
	print("============================")

# Call this in _ready() or when testing: _print_debug_info()
