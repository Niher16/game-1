extends Node3D

@export var map_size: Vector2 = Vector2(60, 60)
@export var auto_generate_on_start := true
@export var max_rooms := 10
@export var room_min_size := Vector2(4, 4)
@export var room_max_size := Vector2(10, 10)

var rooms := []

func _ready():
	if auto_generate_on_start:
		generate_optimized_terrain()

func generate_optimized_terrain():
	clear_existing_rooms()
	rooms.clear()

	var attempts := 0
	while rooms.size() < max_rooms and attempts < max_rooms * 5:
		var size := Vector2(
			int(randi_range(int(room_min_size.x), int(room_max_size.x))),
			int(randi_range(int(room_min_size.y), int(room_max_size.y)))
		)

		var pos := Vector2(
			int(randi_range(0, int(map_size.x - size.x))),
			int(randi_range(0, int(map_size.y - size.y)))
		)

		var new_room := _create_room_shape(pos, size)
		if _room_overlaps(new_room):
			attempts += 1
			continue

		rooms.append(new_room)
		_spawn_room_visual(new_room)
		attempts += 1

func _create_room_shape(pos: Vector2, size: Vector2) -> Dictionary:
	var room := {
		"pos": pos,
		"size": size,
		"type": randi_range(0, 2)  # 0 = rect, 1 = L-shape, 2 = T-shape
	}
	return room

func _room_overlaps(new_room: Dictionary) -> bool:
	for room in rooms:
		var r1 = Rect2(new_room.pos, new_room.size)
		var r2 = Rect2(room.pos, room.size)
		if r1.grow(1).intersects(r2):  # Add spacing
			return true
	return false

func _spawn_room_visual(room: Dictionary):
	var pos = room["pos"]
	var size = room["size"]
	var shape_type = room["type"]

	for x in int(size.x):
		for y in int(size.y):
			var should_place := false

			match shape_type:
				0:  # Rectangle
					should_place = true
				1:  # L-shape
					should_place = (x < size.x / 2 or y < size.y / 2)
				2:  # T-shape
					should_place = (y == 0 or (x > size.x / 3 and x < 2 * size.x / 3))

			if should_place:
				var block := MeshInstance3D.new()
				block.mesh = BoxMesh.new()
				block.scale = Vector3(2, 1, 2)
				block.translation = Vector3(
					(pos.x + x - map_size.x / 2) * 2,
					0,
					(pos.y + y - map_size.y / 2) * 2
				)
				add_child(block)

func clear_existing_rooms():
	for child in get_children():
		if child is MeshInstance3D:
			child.queue_free()

func get_room_center(index: int) -> Vector3:
	if index >= 0 and index < rooms.size():
		var room = rooms[index]
		var center = room.pos + room.size / 2
		return Vector3(
			(center.x - map_size.x / 2) * 2,
			0,
			(center.y - map_size.y / 2) * 2
		)
	return Vector3.ZERO
