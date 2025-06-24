extends Control

var current_options: Array = []
var player_progression: PlayerProgression

@onready var button1 = $Panel/VBoxContainer/Button1
@onready var button2 = $Panel/VBoxContainer/Button2
@onready var button3 = $Panel/VBoxContainer/Button3

# Controller navigation variables
var selected_button_index: int = 0
var buttons: Array = []
var controller_navigation_enabled: bool = false

func _ready():
	print("🎯 LevelUpUI: Initializing with safety checks...")
	add_to_group("levelupui")
	
	# CRITICAL: Hide immediately to prevent startup visibility
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	print("🎯 LevelUpUI: Hidden on startup")
	
	# Wait for nodes to be fully ready before accessing buttons
	call_deferred("_initialize_buttons")
	
	# Detect controller connection
	if Input.is_connected("joy_connection_changed", _on_joy_connection_changed):
		Input.disconnect("joy_connection_changed", _on_joy_connection_changed)
	Input.connect("joy_connection_changed", _on_joy_connection_changed)
	controller_navigation_enabled = Input.get_connected_joypads().size() > 0
	print("🎯 LevelUpUI: Initialization complete")

func _initialize_buttons():
	"""Initialize buttons safely after scene is ready - prevents startup errors"""
	# Safety check: ensure all buttons exist before using them
	if not button1 or not button2 or not button3:
		push_error("❌ LevelUpUI: Required buttons not found! Check node paths.")
		return
	
	# Initialize buttons array only after confirming they exist
	buttons = [button1, button2, button3]
	selected_button_index = 0
	
	# Only update focus if we have valid buttons
	if buttons.size() > 0 and buttons[0] != null:
		update_button_focus()
		print("✅ LevelUpUI: Buttons initialized successfully")
	else:
		print("❌ LevelUpUI: Button initialization failed")

func show_upgrade_choices(options: Array):
	print("🎯 LevelUpUI: show_upgrade_choices called")
	print("📋 Received options: ", options)
	print("📋 Options count: ", options.size())
	
	if options.size() < 3:
		print("❌ ERROR: Not enough options received!")
		return
		
	# Safety check: ensure buttons exist before using them
	if not button1 or not button2 or not button3:
		print("❌ ERROR: Buttons not ready! Cannot show upgrade choices.")
		return
		
	current_options = options
	visible = true
	print("👁️ UI made visible")
		
	print("✅ All buttons found, updating text...")
	button1.text = options[0].title + "\n" + options[0].description
	button2.text = options[1].title + "\n" + options[1].description  
	button3.text = options[2].title + "\n" + options[2].description
	print("✅ Button texts updated successfully")
	
	# Update controller focus if using controller
	if controller_navigation_enabled:
		selected_button_index = 0
		update_button_focus()
	
func _on_button_1_pressed():
	_choose_upgrade(0)
	
func _on_button_2_pressed():
	_choose_upgrade(1)
	
func _on_button_3_pressed():
	_choose_upgrade(2)

func _choose_upgrade(index: int):
	print("🎯 LevelUpUI: Button ", index, " pressed!")
	
	# Safety check: ensure we have valid options
	if current_options.size() <= index:
		print("❌ ERROR: Invalid upgrade index!")
		return
		
	print("🎯 Selected upgrade: ", current_options[index])
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("get") and player.get("progression_component"):
		print("🎯 Calling apply_upgrade on progression component...")
		player.progression_component.apply_upgrade(current_options[index])
	else:
		print("❌ ERROR: Player or progression component not found!")
	
	# Hide UI and unpause
	visible = false
	get_tree().paused = false

# REMOVED DUPLICATE/OLD FUNCTIONS - Clean implementation only

# Controller input handler for navigation
func _input(event):
	if not visible or not controller_navigation_enabled:
		return
		
	# Safety check: ensure buttons exist
	if buttons.size() == 0 or not buttons[0]:
		return
		
	if event.is_action_pressed("ui_down"):
		selected_button_index = (selected_button_index + 1) % buttons.size()
		update_button_focus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		selected_button_index = (selected_button_index - 1 + buttons.size()) % buttons.size()
		update_button_focus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_choose_upgrade(selected_button_index)
		get_viewport().set_input_as_handled()

# Visual focus system for buttons with safety checks
func update_button_focus():
	# Safety check: ensure buttons array is valid
	if buttons.size() == 0:
		return
		
	for i in buttons.size():
		if buttons[i] and is_instance_valid(buttons[i]):
			if i == selected_button_index:
				buttons[i].modulate = Color(1, 1, 0.5, 1) # Highlighted (yellowish)
				buttons[i].grab_focus()
			else:
				buttons[i].modulate = Color(1, 1, 1, 1) # Normal

# Controller detection for UI
func _on_joy_connection_changed(_device_id: int, _connected: bool):
	controller_navigation_enabled = Input.get_connected_joypads().size() > 0
	if controller_navigation_enabled and visible and buttons.size() > 0:
		selected_button_index = 0
		update_button_focus()
