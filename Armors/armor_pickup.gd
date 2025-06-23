# armor_pickup.gd - Enhanced armor pickup, structure matches weapon_pickup.gd
class_name armor_pickup
extends Area3D

# Preload the armor pickup scene for instancing
@export var armor_scene: PackedScene = preload("res://Scenes/armor_pickup.tscn")

static func safe_set_material(mesh_target: MeshInstance3D, material: Material) -> bool:
	if not mesh_target:
		push_warning("🚨 Mesh instance is null - cannot set material")
		return false
	if not material:
		push_warning("🚨 Material is null - creating default material")
		material = StandardMaterial3D.new()
	mesh_target.material_override = material
	return true

# Preloaded mesh constants for armor types
const HELM_MESH = preload("res://Armors/helm_iron.tres")
const CHEST_MESH = preload("res://Armors/chest_leather.tres")
const SHOULDERS_MESH = preload("res://Armors/shoulders_steel.tres")
const BOOTS_MESH = preload("res://Armors/boots_mythril.tres")

# Armor resource assigned to this pickup
@export var armor_resource: ArmorResource = null

# Enhanced visual settings
@export var glow_intensity: float = 1.5
@export var rotation_speed: float = 30.0
@export var bob_height: float = 0.15
@export var bob_speed: float = 2.0

@onready var mesh_instance: MeshInstance3D = get_node_or_null("MeshInstance3D")
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var floating_text: Label3D = null
var player_in_range: bool = false
var player: Node3D = null
var armor_material: StandardMaterial3D
var time_alive: float = 0.0
var armor_parts: Array[MeshInstance3D] = []

func _ready():
	print("🛡️ Armor Pickup Ready - armor_resource: ", armor_resource)
	if armor_resource:
		print("🛡️ Armor name: ", armor_resource.armor_name)
		print("🛡️ Armor type: ", armor_resource.armor_type)
	else:
		print("❌ No armor_resource assigned!")
	print("🛡️ Node children: ", get_children())
	print("🛡️ mesh_instance exists: ", mesh_instance != null)
	print("🛡️ mesh_instance path: ", str(mesh_instance.get_path()) if mesh_instance else "None")
	add_to_group("armor_pickup")
	collision_layer = 4
	collision_mask = 1
	if get_meta("from_physics", false):
		set_meta("pickup_disabled", true)
		_create_pickup_delay_effect(0.2)
	_find_player()
	_create_floating_text()
	call_deferred("_deferred_setup_visual")
	call_deferred("validate_scene_materials")

func validate_scene_materials():
	var mesh_nodes = find_children("*", "MeshInstance3D", true, false)
	for mesh_node in mesh_nodes:
		if not mesh_node.material_override:
			var default_mat = StandardMaterial3D.new()
			default_mat.albedo_color = Color.WHITE
			mesh_node.material_override = default_mat

func _deferred_setup_visual():
	if armor_resource:
		_setup_enhanced_visual()
	else:
		_create_default_armor_visual()

func _setup_enhanced_visual():
	if mesh_instance:
		mesh_instance.mesh = null
		mesh_instance.material_override = null
	if not armor_resource:
		_create_default_armor_visual()
		return
	_clear_armor_parts()
	match armor_resource.armor_type:
		HELM:
			_create_helm_visual()
		CHEST:
			_create_chest_visual()
		SHOULDERS:
			_create_shoulders_visual()
		BOOTS:
			_create_boots_visual()
		_:
			_create_default_armor_visual()
	var collision = SphereShape3D.new()
	collision.radius = 0.8
	collision_shape.shape = collision

func _clear_armor_parts():
	for part in armor_parts:
		if is_instance_valid(part) and part != mesh_instance:
			part.queue_free()
	armor_parts.clear()
	if mesh_instance:
		mesh_instance.mesh = null
		mesh_instance.material_override = null

func _create_helm_visual():
	_clear_armor_parts()
	var helm_mesh_instance = MeshInstance3D.new()
	helm_mesh_instance.mesh = HELM_MESH
	var helm_material = StandardMaterial3D.new()
	helm_material.albedo_color = Color(0.7, 0.7, 0.8)
	helm_material.metallic = 0.8
	helm_material.roughness = 0.2
	helm_material.emission_enabled = true
	helm_material.emission = Color(0.5, 0.7, 1.0) * glow_intensity
	helm_material.rim_enabled = true
	helm_material.rim = 0.7
	safe_set_material(helm_mesh_instance, helm_material)
	helm_mesh_instance.position = Vector3(0, 0.5, 0)
	helm_mesh_instance.scale = Vector3(0.7, 0.7, 0.7)
	add_child(helm_mesh_instance)
	armor_parts.append(helm_mesh_instance)

func _create_chest_visual():
	_clear_armor_parts()
	var chest_mesh_instance = MeshInstance3D.new()
	chest_mesh_instance.mesh = CHEST_MESH
	var chest_material = StandardMaterial3D.new()
	chest_material.albedo_color = Color(0.8, 0.6, 0.4)
	chest_material.metallic = 0.5
	chest_material.roughness = 0.3
	chest_material.emission_enabled = true
	chest_material.emission = Color(0.8, 0.6, 0.4) * glow_intensity * 0.2
	chest_material.rim_enabled = true
	chest_material.rim = 0.6
	safe_set_material(chest_mesh_instance, chest_material)
	chest_mesh_instance.position = Vector3(0, 0.5, 0)
	chest_mesh_instance.scale = Vector3(0.7, 0.7, 0.7)
	add_child(chest_mesh_instance)
	armor_parts.append(chest_mesh_instance)

func _create_shoulders_visual():
	_clear_armor_parts()
	var shoulders_mesh_instance = MeshInstance3D.new()
	shoulders_mesh_instance.mesh = SHOULDERS_MESH
	var shoulders_material = StandardMaterial3D.new()
	shoulders_material.albedo_color = Color(0.7, 0.7, 0.7)
	shoulders_material.metallic = 0.7
	shoulders_material.roughness = 0.25
	shoulders_material.emission_enabled = true
	shoulders_material.emission = Color(0.7, 0.7, 0.7) * glow_intensity * 0.2
	shoulders_material.rim_enabled = true
	shoulders_material.rim = 0.7
	safe_set_material(shoulders_mesh_instance, shoulders_material)
	shoulders_mesh_instance.position = Vector3(0, 0.5, 0)
	shoulders_mesh_instance.scale = Vector3(0.7, 0.7, 0.7)
	add_child(shoulders_mesh_instance)
	armor_parts.append(shoulders_mesh_instance)

func _create_boots_visual():
	_clear_armor_parts()
	var boots_mesh_instance = MeshInstance3D.new()
	boots_mesh_instance.mesh = BOOTS_MESH
	var boots_material = StandardMaterial3D.new()
	boots_material.albedo_color = Color(0.6, 0.8, 0.7)
	boots_material.metallic = 0.6
	boots_material.roughness = 0.3
	boots_material.emission_enabled = true
	boots_material.emission = Color(0.6, 0.8, 0.7) * glow_intensity * 0.2
	boots_material.rim_enabled = true
	boots_material.rim = 0.6
	safe_set_material(boots_mesh_instance, boots_material)
	boots_mesh_instance.position = Vector3(0, 0.5, 0)
	boots_mesh_instance.scale = Vector3(0.7, 0.7, 0.7)
	add_child(boots_mesh_instance)
	armor_parts.append(boots_mesh_instance)

func _create_default_armor_visual():
	_clear_armor_parts()
	_create_helm_visual()

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

func _find_player():
	player = get_tree().get_first_node_in_group("player")

func _process(delta):
	time_alive += delta
	var bob_offset = sin(time_alive * bob_speed) * bob_height
	var base_y_offset = 1.0
	var rotation_y = rotation_speed * delta
	for part in armor_parts:
		if is_instance_valid(part) and part.get_parent() == self:
			part.rotation_degrees.y += rotation_y
			part.position.y = base_y_offset + bob_offset

func _input(_event):
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

func _update_interaction_text():
	if not armor_resource or not floating_text:
		return
	var armor_name = armor_resource.armor_name
	var player_has_armor = ArmorManager.equipped_armor[str(armor_resource.armor_type)] != null
	if player_has_armor:
		floating_text.text = "Press E to Swap for %s" % armor_name
		floating_text.modulate = Color(0.8, 0.8, 1.0, 0.9)
	else:
		floating_text.text = "Press E to Pick Up %s" % armor_name
		floating_text.modulate = Color(0.3, 1.0, 0.3, 0.9)

func _interact_with_armor():
	if not armor_resource:
		return
	if ArmorManager.equipped_armor[str(armor_resource.armor_type)] != null:
		swap_armor()
	else:
		pickup_armor()

func pickup_armor():
	ArmorManager.equip_armor(armor_resource, str(armor_resource.armor_type))
	print("🛡️ Picked up: ", armor_resource.armor_name)
	queue_free()

func swap_armor():
	var old_armor = ArmorManager.equipped_armor[str(armor_resource.armor_type)]
	ArmorManager.equip_armor(armor_resource, str(armor_resource.armor_type))
	print("🛡️ Swapped to: ", armor_resource.armor_name)
	if old_armor:
		set_armor_resource(old_armor)
		print("🛡️ Dropped: ", old_armor.armor_name)
	else:
		queue_free()

func set_armor_resource(new_resource):
	armor_resource = new_resource
	if armor_resource and "armor_name" in armor_resource:
		set_meta("armor_name", armor_resource.armor_name)
	if is_inside_tree():
		call_deferred("_deferred_setup_visual")
		if player_in_range:
			_update_interaction_text()

func _create_pickup_delay_effect(delay_time: float):
	for part in armor_parts:
		if is_instance_valid(part) and part.material_override:
			var material = part.material_override as StandardMaterial3D
			if material and material.emission_enabled:
				var tween = create_tween()
				tween.set_loops(int(delay_time * 2))
				var dim_emission = material.emission * 0.3
				var normal_emission = material.emission
				tween.tween_property(material, "emission", dim_emission, 0.25)
				tween.tween_property(material, "emission", normal_emission, 0.25)
