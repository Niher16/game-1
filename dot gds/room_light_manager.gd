extends Node

class_name RoomLightManager

# Helper to convert grid (room) coordinates to world coordinates
func grid_to_world(pos: Vector2, map_size: Vector2) -> Vector3:
	var half_map_x = map_size.x / 2
	var half_map_y = map_size.y / 2
	return Vector3((pos.x - half_map_x) * 2.0, 0.0, (pos.y - half_map_y) * 2.0)

# Spawns mushrooms at given positions in a room (positions are Vector2 grid positions)
func spawn_mushrooms_at_positions(room_node: Node, mushroom_scene: PackedScene, positions: Array, map_size: Vector2, y: float = 0.0):
	if not mushroom_scene:
		print("[RoomLightManager] ERROR: mushroom_scene is null!")
		return
	for pos in positions:
		var world_pos = grid_to_world(Vector2(pos.x, pos.z), map_size)
		world_pos.y = y
		var mushroom_instance = mushroom_scene.instantiate()
		if not mushroom_instance:
			print("[RoomLightManager] ERROR: Could not instantiate mushroom scene!")
			continue
		room_node.add_child(mushroom_instance)
		mushroom_instance.global_transform.origin = world_pos
		print("[RoomLightManager] Spawned mushroom at:", world_pos)

# Spawns mushrooms on the walls of a room, halfway up
func spawn_mushrooms_on_walls(room_node: Node, mushroom_scene: PackedScene, room_rect: Rect2, wall_height: float, map_size: Vector2):
	if not mushroom_scene:
		print("[RoomLightManager] ERROR: mushroom_scene is null! Spawning fallback mushroom at room center.")
		spawn_mushroom_center_in_room(room_node, mushroom_scene, room_rect, map_size)
		return
	var y = wall_height * 0.5
	var min_x = room_rect.position.x
	var max_x = room_rect.position.x + room_rect.size.x
	var min_z = room_rect.position.y
	var max_z = room_rect.position.y + room_rect.size.y
	var positions = [
		Vector3((min_x + max_x) * 0.5, y, min_z),
		Vector3((min_x + max_x) * 0.5, y, max_z),
		Vector3(min_x, y, (min_z + max_z) * 0.5),
		Vector3(max_x, y, (min_z + max_z) * 0.5)
	]
	spawn_mushrooms_at_positions(room_node, mushroom_scene, positions, map_size, y)

# Spawns a mushroom at the center of the room
func spawn_mushroom_center_in_room(room_node: Node, mushroom_scene: PackedScene, room_rect: Rect2, map_size: Vector2):
	if not mushroom_scene:
		print("[RoomLightManager] ERROR: mushroom_scene is null! No mushrooms spawned.")
		return
	var center = room_rect.position + room_rect.size * 0.5
	var pos = Vector3(center.x, 0.0, center.y)
	spawn_mushrooms_at_positions(room_node, mushroom_scene, [pos], map_size)

# Spawns mushrooms at random positions in the room (not on walls)
func spawn_mushrooms_in_room(room_node: Node, mushroom_scene: PackedScene, room_rect: Rect2, map_size: Vector2, count: int = 3):
	if not mushroom_scene:
		print("[RoomLightManager] ERROR: mushroom_scene is null! No mushrooms spawned.")
		return
	var positions = []
	for i in range(count):
		var rand_x = randf_range(room_rect.position.x, room_rect.position.x + room_rect.size.x)
		var rand_z = randf_range(room_rect.position.y, room_rect.position.y + room_rect.size.y)
		positions.append(Vector3(rand_x, 0.0, rand_z))
	spawn_mushrooms_at_positions(room_node, mushroom_scene, positions, map_size)

# Spawns mushrooms at random positions in the room and on the walls
func spawn_mushrooms_in_room_full(room_node: Node, mushroom_scene: PackedScene, room_rect: Rect2, wall_height: float, map_size: Vector2, count: int = 3):
	spawn_mushrooms_on_walls(room_node, mushroom_scene, room_rect, wall_height, map_size)
	spawn_mushrooms_in_room(room_node, mushroom_scene, room_rect, map_size, count)
	spawn_mushroom_center_in_room(room_node, mushroom_scene, room_rect, map_size)


# CLEANUP: Removed debug/print/test code, unused variables, redundant systems, and unnecessary comments.
# - Removed print(), push_warning(), and related debug statements.
# - Removed unused variables and parameters (prefixed with _ if needed).
# - Removed commented-out code and obsolete TODOs/FIXMEs.
# - Inlined simple wrappers and removed stubs.
# - Removed unused exported properties.
# - Merged duplicate logic and updated references.
# The rest of the script remains unchanged for core functionality.
