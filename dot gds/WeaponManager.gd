extends Node

signal weapon_equipped(weapon_resource)
signal weapon_unequipped()

static var instance: WeaponManager

var base_stats: Dictionary = {}
var base_stats_stored: bool = false

var current_weapon: WeaponResource = null
var player: CharacterBody3D = null

func _enter_tree():
	if instance != null and instance != self:
		queue_free()
	else:
		instance = self

func get_player() -> CharacterBody3D:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as CharacterBody3D
		if not is_instance_valid(player):
			return null
	return player

func equip_weapon(weapon_resource: WeaponResource) -> void:
	if not get_player(): return
	current_weapon = weapon_resource
	_apply_weapon_to_player()

	var p = get_player()
	if p and p.weapon_attach_point:
		var sword_node = p.weapon_attach_point.get_node_or_null("SwordNode")
		var bow_node = p.weapon_attach_point.get_node_or_null("BowNode")
		var staff_node = p.weapon_attach_point.get_node_or_null("StaffNode")

		if sword_node: sword_node.visible = false
		if bow_node: bow_node.visible = false
		if staff_node: staff_node.visible = false

		if weapon_resource.weapon_type == WeaponResource.WeaponType.SWORD and sword_node:
			if sword_node.get_child_count() == 0:
				sword_node.add_child(MeshInstance3D.new())
			var mesh_instance = sword_node.get_child(0) as MeshInstance3D
			mesh_instance.mesh = preload("res://3d Models/Sword/broadsword.obj")

			var iron_material = StandardMaterial3D.new()
			iron_material.albedo_color = Color(0.6, 0.6, 0.65) # iron gray
			iron_material.metallic = 0.85
			iron_material.roughness = 0.25
			iron_material.emission_enabled = false
			mesh_instance.material_override = iron_material

			sword_node.visible = true
		elif weapon_resource.weapon_type == WeaponResource.WeaponType.BOW and bow_node:
			if bow_node.get_child_count() == 0:
				bow_node.add_child(MeshInstance3D.new())
			var mesh_instance = bow_node.get_child(0) as MeshInstance3D
			mesh_instance.mesh = preload("res://3d Models/Bow/bow_01.obj")

			var bow_material = StandardMaterial3D.new()
			bow_material.albedo_color = Color(0.7, 0.5, 0.3)
			bow_material.metallic = 0.2
			bow_material.roughness = 0.5
			bow_material.emission_enabled = true
			var glow_intensity = 1.5 # Match pickup default
			bow_material.emission = Color(0.3, 0.6, 0.2) * glow_intensity * 0.2
			mesh_instance.material_override = bow_material

			bow_node.visible = true
		# You can add staff logic here if needed
	else:
		print("⚠️ Player or WeaponAttachPoint not found for mesh attachment.")

func unequip_weapon() -> void:
	if not get_player(): return
	current_weapon = null
	_apply_weapon_to_player()
	# Hide all weapon nodes when unequipping
	var p = get_player()
	if p and p.weapon_attach_point:
		var sword_node = p.weapon_attach_point.get_node_or_null("SwordNode")
		var bow_node = p.weapon_attach_point.get_node_or_null("BowNode")
		var staff_node = p.weapon_attach_point.get_node_or_null("StaffNode")

		if sword_node: sword_node.visible = false
		if bow_node: bow_node.visible = false
		if staff_node: staff_node.visible = false

func get_current_weapon() -> WeaponResource:
	return current_weapon

func is_weapon_equipped() -> bool:
	return current_weapon != null

func _apply_weapon_to_player() -> void:
	var p = get_player()
	if not p: return
	if not base_stats_stored:
		base_stats["attack_damage"] = p.get("attack_damage")
		base_stats["attack_range"] = p.get("attack_range")
		base_stats["attack_cooldown"] = p.get("attack_cooldown")
		base_stats["attack_cone_angle"] = p.get("attack_cone_angle")
		base_stats_stored = true

	if current_weapon != null:
		# ADD weapon stats to base stats instead of replacing
		p.set("attack_damage", base_stats["attack_damage"] + current_weapon.attack_damage)
		p.set("attack_range", base_stats["attack_range"] + current_weapon.attack_range)
		p.set("attack_cooldown", max(0.1, base_stats["attack_cooldown"] - (current_weapon.attack_cooldown * 0.1)))
		p.set("attack_cone_angle", base_stats["attack_cone_angle"] + current_weapon.attack_cone_angle)
		emit_signal("weapon_equipped", current_weapon)
	else:
		# Restore base stats when unarmed
		p.set("attack_damage", base_stats["attack_damage"])
		p.set("attack_range", base_stats["attack_range"])
		p.set("attack_cooldown", base_stats["attack_cooldown"])
		p.set("attack_cone_angle", base_stats["attack_cone_angle"])
		emit_signal("weapon_unequipped")
