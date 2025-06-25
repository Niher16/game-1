# recruiter_npc.gd - Simple NPC that spawns allies
extends StaticBody3D

@export var ally_scene: PackedScene = preload("res://allies/ally.tscn")
@export var recruitment_cost := 0  # Could add coin cost later
@export var max_allies := 3

signal ally_recruited

var player_in_range := false
var interaction_text: Label3D
var current_allies_count := 0

func _ready():
	add_to_group("npcs")
	_setup_visual()
	_setup_interaction_area()
	_update_ally_counter()

func _setup_visual():
	# Create NPC body (taller than ally, different color)
	var mesh_instance = MeshInstance3D.new()
	var body_mesh = CapsuleMesh.new()
	body_mesh.radius = 0.3
	body_mesh.height = 1.8
	mesh_instance.mesh = body_mesh
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.5, 0.2)  # Brown/tan color
	material.roughness = 0.8
	mesh_instance.material_override = material
	add_child(mesh_instance)
	
	# Create collision
	var collision = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.8
	collision.shape = shape
	add_child(collision)
	
	# Create floating text
	interaction_text = Label3D.new()
	interaction_text.text = "Press E to Recruit Ally"
	interaction_text.position = Vector3(0, 2.5, 0)
	interaction_text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	interaction_text.modulate = Color(0.2, 1.0, 0.2)
	interaction_text.font_size = 48
	interaction_text.visible = false
	add_child(interaction_text)

func _setup_interaction_area():
	var area = Area3D.new()
	area.name = "InteractionArea"
	add_child(area)
	
	var area_collision = CollisionShape3D.new()
	var area_shape = SphereShape3D.new()
	area_shape.radius = 2.0
	area_collision.shape = area_shape
	area.add_child(area_collision)
	
	# Connect signals
	area.body_entered.connect(_on_player_entered)
	area.body_exited.connect(_on_player_exited)

func _on_player_entered(body):
	if body.is_in_group("player"):
		player_in_range = true
		interaction_text.visible = true

func _on_player_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
		interaction_text.visible = false

func _input(event):
	if event.is_action_pressed("interaction") and player_in_range:
		recruit_ally()

func recruit_ally():
	# Check if we have too many allies
	var current_allies = get_tree().get_nodes_in_group("allies")
	if current_allies.size() >= max_allies:
		return
	
	# Spawn ally
	if ally_scene:
		var new_ally = ally_scene.instantiate()
		get_parent().add_child(new_ally)
		
		# Position ally next to recruiter
		new_ally.global_position = global_position + Vector3(randf_range(-2, 2), 5.0, randf_range(-2, 2))

		# Ensure visual setup
		if new_ally.has_method("_create_visual"):
			new_ally._create_visual()

		# Fix: connect to correct signal
		new_ally.ally_died.connect(_on_ally_died)
		_update_ui_units()
		# Emit signal and queue_free recruiter
		ally_recruited.emit()
		queue_free()
	else:
		print("❌ No ally scene assigned!")

func _on_ally_died():
	_update_ui_units()

func _update_ui_units():
	var current_allies = get_tree().get_nodes_in_group("allies").size()
	var ui = get_tree().get_first_node_in_group("UI")
	if ui:
		if ui.has_method("_update_units"):
			ui._update_units(current_allies)
		else:
			print("❌ UI does not have method '_update_units'!")
	else:
		print("❌ UI node not found in group!")

func _update_ally_counter():
	if has_node("../UI/AllyCounter"):
		var counter_label = get_node("../UI/AllyCounter")
		counter_label.text = str(current_allies_count, " / ", max_allies)

func connect_recruit_signal():
	ally_recruited.connect(_on_ally_recruited)

func _on_ally_recruited():
	queue_free()
