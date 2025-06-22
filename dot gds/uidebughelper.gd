# UIDebugHelper.gd - Add this as a new script to test everything
# Attach this to any Node in your scene for testing

extends Node

func _ready():
	# Wait a moment for everything to initialize
	await get_tree().create_timer(2.0).timeout
	test_ui_system()

func _input(event):
	if event.is_action_pressed("ui_accept"):  # Spacebar or Enter
		test_ui_system()
	elif Input.is_action_just_pressed("ui_cancel"):  # Escape
		test_xp_and_coins()

func test_ui_system():
	print("\n🧪 === UI SYSTEM DEBUG TEST ===")
	
	# Test 1: Find UI node
	var ui_nodes = get_tree().get_nodes_in_group("UI")
	print("🔍 UI nodes found: ", ui_nodes.size())
	for ui_node in ui_nodes:
		print("  - UI Node: ", ui_node.name, " Type: ", ui_node.get_script())
		if ui_node.has_method("_on_player_xp_changed"):
			print("    ✅ Has _on_player_xp_changed method")
		else:
			print("    ❌ Missing _on_player_xp_changed method")
		
		# Check if UI elements exist
		if "xp_bar" in ui_node:
			print("    🔍 xp_bar: ", ui_node.xp_bar != null)
		if "xp_label" in ui_node:
			print("    🔍 xp_label: ", ui_node.xp_label != null)
		if "coin_label" in ui_node:
			print("    🔍 coin_label: ", ui_node.coin_label != null)
		if "health_label" in ui_node:
			print("    🔍 health_label: ", ui_node.health_label != null)
	
	# Test 2: Find Player
	var player = get_tree().get_first_node_in_group("player")
	if player:
		print("✅ Player found: ", player.name)
		print("  - Has get_currency: ", player.has_method("get_currency"))
		print("  - Has get_xp: ", player.has_method("get_xp"))
		print("  - Has get_health: ", player.has_method("get_health"))
		
		if player.has_method("debug_components"):
			player.debug_components()
	else:
		print("❌ Player not found!")
	
	# Test 3: Test call_group functionality
	print("\n🧪 Testing call_group signals...")
	get_tree().call_group("UI", "_on_player_xp_changed", 50, 100, 2)
	get_tree().call_group("UI", "_on_player_coin_collected", 150)
	get_tree().call_group("UI", "_on_player_health_changed", 85, 100)

func test_xp_and_coins():
	print("\n🧪 === TESTING XP AND COIN COLLECTION ===")
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("❌ No player found for testing!")
		return
	
	print("📊 Current Stats:")
	if player.has_method("get_currency"):
		print("  💰 Currency: ", player.get_currency())
	if player.has_method("get_xp"):
		print("  📈 XP: ", player.get_xp())
	if player.has_method("get_level"):
		print("  🏆 Level: ", player.get_level())
	
	# Test adding XP
	if player.progression_component:
		print("\n🧪 Adding 25 XP...")
		player.progression_component.add_xp(25)
		
		print("🧪 Adding 50 currency...")
		player.progression_component.add_currency(50)
	else:
		print("❌ No progression component found!")

func _on_ui_test_button_pressed():
	# You can connect this to a button for manual testing
	test_ui_system()
