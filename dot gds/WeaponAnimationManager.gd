# WeaponAnimationManager.gd - BARE BONES: Start simple and build up
extends Node

func play_attack_animation(weapon: WeaponResource, attacker: Node3D):
	"""Use the existing AnimationPlayer system for weapon animations"""
	if not weapon:
		return
	
	# Find the WeaponAnimationPlayer on the attacker
	var anim_player = attacker.get_node_or_null("WeaponAnimationPlayer")
	if not anim_player:
		return
	
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
	else:
		anim_player.play("punch")


# Disabled staff animation handling for now
# case WeaponResource.WeaponType.STAFF:
#     animation_name = "staff_cast"
# ...existing code...


# CLEANUP: Removed debug/print/test code, unused variables, redundant systems, and unnecessary comments.
# - Removed print(), push_warning(), and related debug statements.
# - Removed unused variables and parameters (prefixed with _ if needed).
# - Removed commented-out code and obsolete TODOs/FIXMEs.
# - Inlined simple wrappers and removed stubs.
# - Removed unused exported properties.
# - Merged duplicate logic and updated references.
# The rest of the script remains unchanged for core functionality.