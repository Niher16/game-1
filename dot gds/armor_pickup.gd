extends Node

class_name armor_pickup

# armor_pickup.gd - Enhanced armor pickup with swap logic matching weapon_pickup
extends Area3D

@export var armor_resource: ArmorResource = null

var floating_text: Label3D = null
var player_in_range: bool = false
var player: Node3D = null
var time_alive: float = 0.0
var armor_visual: MeshInstance3D = null

func _ready():
	add_to_group("armor_pickup")
	collision_layer = 4
	collision_mask = 1
	_find_player()
	_create_floating_text()
	call_deferred("_setup_visual")

func _find_player():
	player = get_tree().get_first_node_in_group("player")

func _process(delta):
	time_alive += delta
	if armor_visual:
		armor_visual.rotation_degrees.y += 30 * delta
		armor_visual.position.y = 1.0 + sin(time_alive * 2.0) * 0.15

func _input(event):
	if Input.is_action_just_pressed("interaction") and player_in_range and not get_meta("pickup_disabled", false):
		_interact_with_armor()

func _on_area_entered(area: Area3D):
	if area.get_parent() and area.get_parent().is_in_group("player"):
		player_in_range = true
		_update_interaction_text()
		if floating_text:
			floating_text.visible = true

func _on_area_exited(area: Area3D):
	if area.get_parent() and area.get_parent().is_in_group("player"):
		player_in_range = false
		if floating_text:
			floating_text.visible = false

func _create_floating_text():
	floating_text = Label3D.new()
	floating_text.name = "FloatingText"
	floating_text.text = "Press E to Pick Up"
	floating_text.position = Vector3(0, 1.5, 0)
	floating_text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	floating_text.no_depth_test = true
	floating_text.modulate = Color(1.0, 1.0, 0.4, 0.9)
	floating_text.outline_modulate = Color(0.2, 0.2, 0.0, 1.0)
	floating_text.font_size = 36
	floating_text.outline_size = 6
	floating_text.visible = false
	add_child(floating_text)

func _update_interaction_text():
	if not armor_resource or not floating_text:
		return
	var armor_name = armor_resource.armor_name
	var player_has_armor = ArmorManager.is_armor_equipped()
	if player_has_armor:
		floating_text.text = "Press E to Swap for %s" % armor_name
		floating_text.modulate = Color(0.8, 0.8, 1.0, 0.9)
	else:
		floating_text.text = "Press E to Pick Up %s" % armor_name
		floating_text.modulate = Color(0.3, 1.0, 0.3, 0.9)

func _interact_with_armor():
	if not armor_resource:
		return
	if ArmorManager.is_armor_equipped():
		_swap_armor()
	else:
		_pickup_armor()

func _pickup_armor():
	ArmorManager.equip_armor(armor_resource)
	queue_free()

func _swap_armor():
	var old_armor = ArmorManager.get_current_armor()
	ArmorManager.equip_armor(armor_resource)
	if old_armor:
		set_armor_resource(old_armor)
	else:
		queue_free()

func set_armor_resource(new_resource: ArmorResource):
	armor_resource = new_resource
	if armor_resource and "armor_name" in armor_resource:
		set_meta("armor_name", armor_resource.armor_name)
	if is_inside_tree():
		call_deferred("_setup_visual")
		if player_in_range:
			_update_interaction_text()

func _setup_visual():
	if armor_visual:
		armor_visual.queue_free()
	if not armor_resource:
		return
	armor_visual = MeshInstance3D.new()
	# For demo: use a simple box mesh, replace with actual armor mesh as needed
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.5, 0.5, 0.2)
	armor_visual.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.7, 1.0)
	mat.metallic = 0.5
	mat.roughness = 0.2
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.5, 1.0) * 0.5
	armor_visual.material_override = mat
	armor_visual.position = Vector3(0, 1.0, 0)
	armor_visual.scale = Vector3(0.7, 0.7, 0.7)
	add_child(armor_visual)
