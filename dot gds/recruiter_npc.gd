# recruiter_npc.gd - Enhanced NPC that spawns allies
extends StaticBody3D

@export var ally_scene: PackedScene = preload("res://allies/Ally.tscn")  # Fixed: Capital A
@export var recruitment_cost := 0  # Could add coin cost later
@export var max_allies := 5  # Increased from 3

signal ally_recruited

var player_in_range := false
var interaction_text: Label3D
var current_allies_count := 0

func _ready():
	add_to_group("npcs")
	add_to_group("recruiters")  # Ensure proper group assignment
	_setup_enhanced_visual()
	_setup_interaction_area()
	_update_ally_counter()
	
	# Set proper collision layers - Layer 5 for NPCs
	collision_layer = 1 << 4  # Layer 5 (NPCs)
	collision_mask = 0  # NPCs don't need to collide with anything

func _setup_enhanced_visual():
	# Use the imported .scn scene for the recruiter mesh
	var cage_scene = load("res://.godot/imported/medievalcage.blend-14d3afa47da1639ae57efe60aa635ba5.scn")
	if cage_scene:
		var cage_instance = cage_scene.instantiate()
		cage_instance.scale = Vector3(0.7, 0.7, 0.7)
		cage_instance.position.y = -0.7 # Lower the cage to sit on the ground
		add_child(cage_instance)
	else:
		# Fallback: show a simple box if mesh can't be loaded
		var mesh_instance = MeshInstance3D.new()
		var fallback_mesh = BoxMesh.new()
		mesh_instance.mesh = fallback_mesh
		add_child(mesh_instance)

	# Create main collision shape
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.5, 2.0, 1.5)
	collision.shape = shape
	add_child(collision)

	# Enhanced floating text with better visibility
	interaction_text = Label3D.new()
	interaction_text.text = "Press E to Recruit Ally"
	interaction_text.position = Vector3(0, 3.0, 0)
	interaction_text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	interaction_text.modulate = Color(1.0, 1.0, 0.2)  # Bright yellow
	interaction_text.font_size = 64  # Larger font
	interaction_text.outline_size = 8
	interaction_text.outline_modulate = Color.BLACK
	interaction_text.visible = false
	add_child(interaction_text)

func _setup_interaction_area():
	var area = Area3D.new()
	area.name = "InteractionArea"
	add_child(area)
	
	var area_collision = CollisionShape3D.new()
	var area_shape = SphereShape3D.new()
	area_shape.radius = 3.0  # Increased radius for easier interaction
	area_collision.shape = area_shape
	area.add_child(area_collision)
	
	# Set proper collision layers for the interaction area
	area.collision_layer = 0  # Area doesn't need to be on any layer
	area.collision_mask = 1 << 2  # Only detect Player (Layer 3)
	
	# Connect signals with better error handling
	if not area.body_entered.is_connected(_on_player_entered):
		area.body_entered.connect(_on_player_entered)
	if not area.body_exited.is_connected(_on_player_exited):
		area.body_exited.connect(_on_player_exited)

func _on_player_entered(body):
	if body.is_in_group("player"):
		player_in_range = true
		interaction_text.visible = true
		print("👤 Player entered recruiter range")

func _on_player_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
		interaction_text.visible = false
		print("👤 Player left recruiter range")

func _input(event):
	if event.is_action_pressed("interaction") and player_in_range:
		recruit_ally()

func recruit_ally():
	print("🎯 Attempting to recruit ally...")
	
	# Check if we have too many allies
	var current_allies = get_tree().get_nodes_in_group("allies")
	if current_allies.size() >= max_allies:
		print("❌ Max allies reached: ", current_allies.size(), "/", max_allies)
		# Update text to show max reached
		interaction_text.text = "Max Allies Reached (%d/%d)" % [current_allies.size(), max_allies]
		interaction_text.modulate = Color(1.0, 0.3, 0.3)  # Red color
		return
	
	# Spawn ally with better error handling
	if ally_scene:
		var new_ally = ally_scene.instantiate()
		if not new_ally:
			print("\u274c Failed to instantiate ally scene!")
			return
		print("[DEBUG] Recruiter NPC spawned ally: ", new_ally.name)
		
		# Add to scene tree first
		get_parent().add_child(new_ally)
		
		# Position ally properly on ground (not floating)
		var spawn_position = global_position + Vector3(randf_range(-2, 2), 0.1, randf_range(-2, 2))
		new_ally.global_position = spawn_position
		
		# Ensure ally is in proper group
		new_ally.add_to_group("allies")
		print("✅ Ally added to group, total allies: ", get_tree().get_nodes_in_group("allies").size())
		
		# Connect ally death signal for UI updates
		if new_ally.has_signal("ally_died"):
			if not new_ally.ally_died.is_connected(_on_ally_died):
				new_ally.ally_died.connect(_on_ally_died)
		
		# Force visual setup if method exists
		if new_ally.has_method("_create_visual"):
			new_ally._create_visual()
		
		# Update UI
		_update_ui_units()
		
		# Emit signal and remove recruiter
		ally_recruited.emit()
		print("🎉 Ally recruited successfully!")
		
		# Visual feedback before removal
		_play_recruitment_effect()
		await get_tree().create_timer(0.5).timeout
		queue_free()
	else:
		print("❌ No ally scene assigned!")

func _play_recruitment_effect():
	"""Add visual/audio feedback for recruitment"""
	# Change interaction text
	interaction_text.text = "Ally Recruited!"
	interaction_text.modulate = Color(0.2, 1.0, 0.2)  # Green

func _on_ally_died():
	print("💀 Ally died, updating UI...")
	_update_ui_units()

func _update_ui_units():
	var current_allies = get_tree().get_nodes_in_group("allies").size()
	var ui = get_tree().get_first_node_in_group("UI")
	if ui:
		if ui.has_method("_update_units"):
			ui._update_units(current_allies)
			print("📊 UI updated with ", current_allies, " allies")
		else:
			print("❌ UI does not have method '_update_units'!")
	else:
		print("❌ UI node not found in group!")

func _update_ally_counter():
	# This method is kept for compatibility but may not be needed
	current_allies_count = get_tree().get_nodes_in_group("allies").size()

func connect_recruit_signal():
	# Connect to any additional signals if needed
	pass

func _on_ally_recruited():
	queue_free()
