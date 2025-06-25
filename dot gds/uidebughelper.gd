extends Node

func _ready():
	await get_tree().create_timer(2.0).timeout
	test_ui_system()

func _input(event):
	if event.is_action_pressed("ui_accept"):  # Spacebar or Enter
		test_ui_system()
	elif Input.is_action_just_pressed("ui_cancel"):  # Escape
		test_xp_and_coins()

func test_ui_system():
	# Test 1: Find UI node
	var ui_nodes = get_tree().get_nodes_in_group("UI")
	for ui_node in ui_nodes:
		if ui_node.has_method("_on_player_xp_changed"):
			pass
		
		# Check if UI elements exist
		if "xp_bar" in ui_node:
			pass
		if "xp_label" in ui_node:
			pass
		if "coin_label" in ui_node:
			pass
		if "health_label" in ui_node:
			pass
	
	# Test 2: Find Player
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if player.has_method("debug_components"):
			player.debug_components()
	
	# Test 3: Test call_group functionality
	get_tree().call_group("UI", "_on_player_xp_changed", 50, 100, 2)
	get_tree().call_group("UI", "_on_player_coin_collected", 150)
	get_tree().call_group("UI", "_on_player_health_changed", 85, 100)

func test_xp_and_coins():
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	# Test adding XP
	if player.progression_component:
		player.progression_component.add_xp(25)
		player.progression_component.add_currency(50)
	else:
		print("❌ No progression component found!")

func _on_ui_test_button_pressed():
	test_ui_system()
