# WeaponAnimationManager.gd - BARE BONES: Start simple and build up
extends Node

func play_attack_animation(weapon: WeaponResource, attacker: Node3D):
	"""Use the existing AnimationPlayer system for weapon animations"""
	if not weapon:
		print("❌ No weapon provided")
		return
	
	# Find the WeaponAnimationPlayer on the attacker
	var anim_player = attacker.get_node_or_null("WeaponAnimationPlayer")
	if not anim_player:
		print("❌ No WeaponAnimationPlayer found on ", attacker.name)
		return
	
	print("✅ Starting animation for ", weapon.weapon_name)
	
	# Choose animation based on weapon type
	var animation_name = ""
	match weapon.weapon_type:
		WeaponResource.WeaponType.SWORD:
			animation_name = "sword_slash"
		WeaponResource.WeaponType.BOW:
			animation_name = "Bow"  # Fixed case to match actual animation name
		WeaponResource.WeaponType.STAFF:
			animation_name = "staff_cast"  # Add this animation to player.tscn if needed
		_:
			animation_name = "punch"  # Fallback
	
	# Play the animation if it exists, otherwise fallback to punch
	if anim_player.has_animation(animation_name):
		anim_player.play(animation_name)
		print("✅ Playing ", animation_name, " animation")
	else:
		print("⚠️ No ", animation_name, " animation found, using punch")
		anim_player.play("punch")


# ...existing code...
# Disabled staff animation handling for now
# case WeaponResource.WeaponType.STAFF:
#     animation_name = "staff_cast"
# ...existing code...
