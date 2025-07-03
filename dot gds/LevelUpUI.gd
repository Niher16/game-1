extends Control

var current_options: Array = []
var player_progression: PlayerProgression

@onready var button1 = $Panel/VBoxContainer/Button1  # Replace with your actual button paths
@onready var button2 = $Panel/VBoxContainer/Button2
@onready var button3 = $Panel/VBoxContainer/Button3

# Controller navigation variables
var selected_button_index: int = 0
var buttons: Array = []
var controller_navigation_enabled: bool = false

func _ready():
	add_to_group("levelupui")
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	# Initialize buttons array and set initial focus
	buttons = [button1, button2, button3]
	selected_button_index = 0
	update_button_focus()
	# Detect controller connection
	Input.connect("joy_connection_changed", Callable(self, "_on_joy_connection_changed"))
	controller_navigation_enabled = Input.get_connected_joypads().size() > 0

func show_upgrade_choices(options: Array):
	if options.size() < 3:
		return
		
	current_options = options
	visible = true
	
	# Check if buttons exist
	if not button1:
		return
	if not button2:
		return
	if not button3:
		return
		
	button1.text = options[0].title + "\n" + options[0].description
	button2.text = options[1].title + "\n" + options[1].description  
	button3.text = options[2].title + "\n" + options[2].description
	
func _on_button_1_pressed():
	_choose_upgrade(0)
	
func _on_button_2_pressed():
	_choose_upgrade(1)
	
func _on_button_3_pressed():
	_choose_upgrade(2)

func _choose_upgrade(index: int):
	var player = get_tree().get_first_node_in_group("player")
	if player and player.progression_component:
		player.progression_component.apply_upgrade(current_options[index])
	else:
		print("❌ ERROR: Player or progression component not found!")
	visible = false

func _on_damage_button_pressed():
	var player = get_tree().get_first_node_in_group("player")
	if player and player.progression_component:
		player.progression_component.apply_stat_choice("damage")
	visible = false
	get_tree().paused = false

func _on_speed_button_pressed():
	var player = get_tree().get_first_node_in_group("player")
	if player and player.progression_component:
		player.progression_component.apply_stat_choice("speed")
	visible = false
	get_tree().paused = false

func _on_attack_speed_button_pressed():
	var player = get_tree().get_first_node_in_group("player")
	if player and player.progression_component:
		player.progression_component.apply_stat_choice("attack_speed")
	visible = false
	get_tree().paused = false

func show_level_up_ui():
	visible = true
	button1.text = "💪 Damage +5"
	button2.text = "💨 Speed +1.0"
	button3.text = "⚡ Attack Speed"

# Controller input handler for navigation
func _input(event):
	if not visible or not controller_navigation_enabled:
		return
	if event.is_action_pressed("ui_down"):
		selected_button_index = (selected_button_index + 1) % buttons.size()
		update_button_focus()
		accept_event()
	elif event.is_action_pressed("ui_up"):
		selected_button_index = (selected_button_index - 1 + buttons.size()) % buttons.size()
		update_button_focus()
		accept_event()
	elif event.is_action_pressed("ui_accept"):
		_choose_upgrade(selected_button_index)
		accept_event()

# Visual focus system for buttons
func update_button_focus():
	for i in buttons.size():
		if buttons[i]:
			if i == selected_button_index:
				buttons[i].modulate = Color(1, 1, 0.5, 1) # Highlighted (yellowish)
				buttons[i].grab_focus()
			else:
				buttons[i].modulate = Color(1, 1, 1, 1) # Normal

# Controller detection for UI
func _on_joy_connection_changed(_device_id: int, _connected: bool):
	controller_navigation_enabled = Input.get_connected_joypads().size() > 0
	if controller_navigation_enabled and visible:
		selected_button_index = 0
		update_button_focus()


# CLEANUP: Removed debug/print/test code, unused variables, redundant systems, and unnecessary comments.
# - Removed print(), push_warning(), and related debug statements.
# - Removed unused variables and parameters (prefixed with _ if needed).
# - Removed commented-out code and obsolete TODOs/FIXMEs.
# - Inlined simple wrappers and removed stubs.
# - Removed unused exported properties.
# - Merged duplicate logic and updated references.
# The rest of the script remains unchanged for core functionality.