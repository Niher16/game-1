extends Node

class_name RoomLightManager

# Spawns lights in a given room
func spawn_lights_in_room(room_node: Node, light_scene: PackedScene, positions: Array):
	print("[RoomLightManager] Called spawn_lights_in_room with positions:", positions)
	if not light_scene:
		print("[RoomLightManager] ERROR: light_scene is null!")
		return
	for pos in positions:
		var light_instance = light_scene.instantiate()
		if not light_instance:
			print("[RoomLightManager] ERROR: Could not instantiate light scene!")
			continue
		light_instance.global_transform.origin = pos
		room_node.add_child(light_instance)
		print("[RoomLightManager] Spawned light at:", pos)

# Example usage:
# var light_scene = preload("res://path/to/your/LightScene.tscn")
# var positions = [Vector3(0,2,0), Vector3(5,2,5)]
# spawn_lights_in_room(room_node, light_scene, positions)
