extends Resource
class_name WeaponResource

# WeaponType enum - explicit values to match resource files
enum WeaponType { 
	UNARMED = 0,
	SWORD = 1, 
	BOW = 2, 
	STAFF = 3 
}

@export var weapon_name: String = "Fist"
@export var attack_damage: int = 10
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.0
@export var attack_cone_angle: float = 90.0

# Store weapon_type as int for compatibility with hand system
@export var weapon_type: int = WeaponType.SWORD

@export var visual_scene_path: String = ""


# CLEANUP: Removed debug/print/test code, unused variables, redundant systems, and unnecessary comments.
# - Removed print(), push_warning(), and related debug statements.
# - Removed unused variables and parameters (prefixed with _ if needed).
# - Removed commented-out code and obsolete TODOs/FIXMEs.
# - Inlined simple wrappers and removed stubs.
# - Removed unused exported properties.
# - Merged duplicate logic and updated references.
# The rest of the script remains unchanged for core functionality.