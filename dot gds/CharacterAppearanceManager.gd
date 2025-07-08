# CharacterAppearanceManager.gd - CLEANED VERSION
class_name CharacterAppearanceManager
extends Node

static func safe_set_material(mesh_instance: MeshInstance3D, material: Material) -> bool:
	if not mesh_instance:
		return false
	if not material:
		material = StandardMaterial3D.new()
	mesh_instance.material_override = material
	return true

static var SKIN_COLOR = Color(0.9, 0.7, 0.6)
static var EYE_COLOR = Color.BLACK
static var EYE_POSITION_HEIGHT: float = 0.3
static var EYE_SPACING: float = 0.26
static var PUPIL_SIZE: float = 0.6
static var SKIN_MATERIAL: StandardMaterial3D = null
static var EYE_MATERIAL: StandardMaterial3D = null
static var BODY_HEIGHT: float = 1.5
static var BODY_RADIUS: float = 0.3
static var EYE_SIZE: float = 0.07
static var HAND_SIZE: float = 0.08
static var FOOT_SIZE: Vector3 = Vector3(0.15, 0.06, 0.25)

static func _init_materials(skin_tone = null):
	SKIN_MATERIAL = StandardMaterial3D.new()
	if typeof(skin_tone) == TYPE_COLOR:
		SKIN_MATERIAL.albedo_color = skin_tone
	else:
		SKIN_MATERIAL.albedo_color = SKIN_COLOR
	SKIN_MATERIAL.metallic = 0.0
	SKIN_MATERIAL.roughness = 0.7
	SKIN_MATERIAL.clearcoat = 0.1
	SKIN_MATERIAL.rim = 0.3
	SKIN_MATERIAL.rim_tint = 0.5
	if EYE_MATERIAL == null:
		EYE_MATERIAL = StandardMaterial3D.new()
		EYE_MATERIAL.albedo_color = EYE_COLOR
		EYE_MATERIAL.metallic = 0.8
		EYE_MATERIAL.roughness = 0.1

static func create_player_appearance(character: CharacterBody3D, config := {}):
	var skin_material = SKIN_MATERIAL.duplicate() if SKIN_MATERIAL else StandardMaterial3D.new()
	if config.has("skin_tone"):
		skin_material.albedo_color = config["skin_tone"]
	else:
		skin_material.albedo_color = SKIN_COLOR
	_init_materials(config.get("skin_tone", null))
	_clear_existing_appearance(character)
	var body_type = config.get("body_type", "capsule")
	var body_height = config.get("body_height", BODY_HEIGHT)
	var body_radius = config.get("body_radius", BODY_RADIUS)
	var main_mesh = character.get_node("MeshInstance3D")
	_create_simple_body(main_mesh, body_type, body_height, body_radius, skin_material)
	var eyes_cfg = config.get("eyes", {})
	_create_eyes(character, eyes_cfg, main_mesh, body_radius)
	var mouth_cfg = config.get("mouth", {})
	_create_mouth(character, mouth_cfg, main_mesh, body_radius)
	var hands_cfg = config.get("hands", {})
	_create_hands(character, hands_cfg, skin_material)
	var feet_cfg = config.get("feet", {})
	_create_feet(character, feet_cfg, skin_material)
	return main_mesh

static func create_random_character(character: CharacterBody3D):
	var config = CharacterGenerator.generate_random_character_config()
	return create_player_appearance(character, config)

static func _clear_existing_appearance(character: CharacterBody3D):
	var parts_to_remove = [
		"LeftArm", "RightArm", "LeftLeg", "RightLeg",
		"LeftHand", "RightHand", "LeftFoot", "RightFoot", "Foot0", "Foot1",
		"LeftEye", "RightEye",
		"Mouth", "MouthSphere0", "MouthSphere1", "MouthSphere2",
		"Hair", "Mustache", "Goatee", "Beard"
	]
	for i in range(20):
		parts_to_remove.append("HairPart" + str(i))
		parts_to_remove.append("Curl" + str(i))
		parts_to_remove.append("Spike" + str(i))
	for part_name in parts_to_remove:
		var part = character.get_node_or_null(part_name)
		if part:
			part.queue_free()

static func _create_simple_body(mesh_instance: MeshInstance3D, body_type: String, height: float, radius: float, skin_material: StandardMaterial3D):
	if body_type == "box":
		var box = BoxMesh.new()
		box.size = Vector3(radius * 2, height, radius * 2)
		mesh_instance.mesh = box
		mesh_instance.position = Vector3(0, 0, 0)
	else:
		var capsule_mesh = CapsuleMesh.new()
		capsule_mesh.radius = radius
		capsule_mesh.height = height
		mesh_instance.mesh = capsule_mesh
		mesh_instance.position = Vector3(0, 0, 0)
	mesh_instance.material_override = skin_material

static func _create_hands(character: CharacterBody3D, cfg := {}, skin_material: StandardMaterial3D = null):
	var _shape = cfg.get("shape", "fist")
	var size = cfg.get("size", HAND_SIZE)
	var right_anchor = character.get_node_or_null("RightHandAnchor")
	var left_anchor = character.get_node_or_null("LeftHandAnchor")
	if not right_anchor or not left_anchor:
		_create_hands_old_way(character, cfg, skin_material)
		return
	for i in [-1, 1]:
		var hand = MeshInstance3D.new()
		var anchor = right_anchor if i > 0 else left_anchor
		hand.name = "RightHand" if i > 0 else "LeftHand"
		var mesh = BoxMesh.new()
		mesh.size = Vector3(size * 2.5, size * 1.5, size * 2.5)
		hand.mesh = mesh
		hand.position = Vector3.ZERO
		hand.rotation_degrees = Vector3(0, 0, 90)
		hand.material_override = skin_material if skin_material else SKIN_MATERIAL
		anchor.add_child(hand)

static func _create_hands_old_way(character: CharacterBody3D, cfg := {}, skin_material: StandardMaterial3D = null):
	var _shape = cfg.get("shape", "fist")
	var size = cfg.get("size", HAND_SIZE)
	var _dist = cfg.get("distance", 0.44)
	var _height = cfg.get("height", -0.20)
	for i in [-1, 1]:
		var hand = MeshInstance3D.new()
		hand.name = "LeftHand" if i < 0 else "RightHand"
		var mesh = BoxMesh.new()
		mesh.size = Vector3(size * 2.5, size * 1.5, size * 2.5)
		hand.mesh = mesh
		hand.position = Vector3(i * -_dist, _height, 0)
		hand.rotation_degrees = Vector3(0, 0, 90)
		hand.material_override = skin_material if skin_material else SKIN_MATERIAL
		character.add_child(hand)

static func _create_feet(character: CharacterBody3D, cfg := {}, skin_material: StandardMaterial3D = null):
	var shape = cfg.get("shape", "bare")
	var size = cfg.get("size", FOOT_SIZE)
	var dist = cfg.get("distance", 0.25)
	var height = cfg.get("height", -1.05) + 0.2 - 0.05
	var scale_vec = Vector3(0.85 * 0.75, 0.85, 0.85)
	for i in [-1, 1]:
		var foot = MeshInstance3D.new()
		var foot_name = "LeftFoot" if i < 0 else "RightFoot"
		foot.name = foot_name
		var mesh = BoxMesh.new()
		match shape:
			"bare":
				mesh.size = Vector3(size.x * 1.7, size.y * 2.5, size.z * 1.7)
				foot.scale = scale_vec
			"boot":
				mesh.size = Vector3(size.x * 1.8, size.y * 2.5, size.z * 1.9)
				foot.scale = scale_vec
			"small":
				mesh.size = Vector3(size.x * 1.2, size.y * 2.2, size.z * 1.2)
				foot.scale = scale_vec
			"wide":
				mesh.size = Vector3(size.x * 2.2, size.y * 2.5, size.z * 2.2)
				foot.scale = scale_vec
			_:
				mesh.size = Vector3(size.x * 1.2, size.y * 2.2, size.z * 1.2)
				foot.scale = scale_vec
		foot.mesh = mesh
		foot.position = Vector3(i * dist, height, 0)
		foot.material_override = skin_material if skin_material else SKIN_MATERIAL
		character.add_child(foot)

static func get_eye_z_position(body_radius: float) -> float:
	var min_radius = 0.15
	var max_radius = 0.4
	var min_z = -0.15
	var max_z = -0.4
	var t = clamp((body_radius - min_radius) / (max_radius - min_radius), 0, 1)
	return lerp(min_z, max_z, t)

static func _clear_existing_eyes(character: CharacterBody3D):
	var mesh_instance = character.get_node_or_null("MeshInstance3D")
	if not mesh_instance:
		return
	for eye_name in ["LeftEye", "RightEye"]:
		var eye_node = mesh_instance.get_node_or_null(eye_name)
		if eye_node:
			eye_node.queue_free()

static func _create_eyes(_character: CharacterBody3D, cfg := {}, mesh_instance: MeshInstance3D = null, body_radius: float = BODY_RADIUS):
	if not mesh_instance:
		return
	_clear_existing_eyes(_character)
	var eye_color = cfg.get("color", Color.WHITE)
	var eye_size = cfg.get("size", EYE_SIZE)
	var eye_spacing = cfg.get("spacing", EYE_SPACING)
	var pupil_color = cfg.get("pupil_color", Color.BLACK)
	var eye_height = cfg.get("height", EYE_POSITION_HEIGHT)
	var base_z_offset = -.05
	var adjustment_factor = -0.7
	var eye_z = base_z_offset + (body_radius * adjustment_factor)
	var eye_material = StandardMaterial3D.new()
	eye_material.albedo_color = eye_color
	eye_material.metallic = 0.1
	eye_material.roughness = 0.3
	eye_material.clearcoat = 0.8
	eye_material.clearcoat_roughness = 0.1
	var pupil_material = StandardMaterial3D.new()
	pupil_material.albedo_color = pupil_color
	pupil_material.metallic = 0.9
	pupil_material.roughness = 0.1
	pupil_material.emission_enabled = true
	pupil_material.emission = Color(0.1, 0.1, 0.2) * 0.3
	for i in [-1, 1]:
		var eye_container = Node3D.new()
		eye_container.name = "LeftEye" if i < 0 else "RightEye"
		mesh_instance.add_child(eye_container)
		eye_container.position = Vector3(i * eye_spacing / 2, eye_height, eye_z)
		var eyeball = MeshInstance3D.new()
		eyeball.name = "Eyeball"
		var eye_sphere = SphereMesh.new()
		eye_sphere.radius = eye_size
		eye_sphere.height = eye_size * 2
		eyeball.mesh = eye_sphere
		eyeball.material_override = eye_material
		eye_container.add_child(eyeball)
		var pupil = MeshInstance3D.new()
		pupil.name = "Pupil"
		var pupil_sphere = SphereMesh.new()
		pupil_sphere.radius = eye_size * PUPIL_SIZE
		pupil_sphere.height = eye_size * PUPIL_SIZE * 2
		pupil.mesh = pupil_sphere
		pupil.material_override = pupil_material
		pupil.position = Vector3(0, 0, eye_size * 0.3)
		eyeball.add_child(pupil)
		var highlight = MeshInstance3D.new()
		highlight.name = "Highlight"
		var highlight_sphere = SphereMesh.new()
		highlight_sphere.radius = eye_size * 0.2
		highlight_sphere.height = eye_size * 0.2 * 2
		highlight.mesh = highlight_sphere
		var highlight_material = StandardMaterial3D.new()
		highlight_material.albedo_color = Color.WHITE
		highlight_material.emission_enabled = true
		highlight_material.emission = Color.WHITE * 0.8
		highlight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		highlight_material.albedo_color.a = 0.9
		highlight.material_override = highlight_material
		highlight.position = Vector3(eye_size * 0.15, eye_size * 0.15, eye_size * 0.4)
		eyeball.add_child(highlight)

static func _create_mouth(_character: CharacterBody3D, cfg := {}, mesh_instance: MeshInstance3D = null, body_radius: float = BODY_RADIUS):
	if not mesh_instance:
		return
	var old_mouth = mesh_instance.get_node_or_null("Mouth")
	if old_mouth:
		old_mouth.queue_free()
	var mouth_color = cfg.get("color", Color(0.1, 0.08, 0.07))
	var mouth_size = cfg.get("size", body_radius * 0.18)
	var mouth_spacing = cfg.get("spacing", body_radius * 0.18)
	var _eye_spacing = cfg.get("eye_spacing", EYE_SPACING)
	var eye_height = cfg.get("eye_height", EYE_POSITION_HEIGHT)
	var min_mouth_eye_distance = 0.33 * body_radius + 0.14
	var default_mouth_offset = 0.38 * body_radius
	var mouth_height = eye_height - max(min_mouth_eye_distance, default_mouth_offset)
	if mouth_height > eye_height - min_mouth_eye_distance:
		mouth_height = eye_height - min_mouth_eye_distance
	var mouth_z = cfg.get("z_offset", -body_radius * 0.92)
	var mouth_material = StandardMaterial3D.new()
	mouth_material.albedo_color = mouth_color
	mouth_material.metallic = 0.7
	mouth_material.roughness = 0.15
	mouth_material.emission_enabled = true
	mouth_material.emission = mouth_color * 0.2
	var mouth = Node3D.new()
	mouth.name = "Mouth"
	mesh_instance.add_child(mouth)
	mouth.position = Vector3(0, mouth_height, mouth_z)
	var positions = [
		Vector3(-mouth_spacing, 0, 0),
		Vector3(0, 0, 0),
		Vector3(mouth_spacing, 0, 0)
	]
	for i in range(3):
		var part = MeshInstance3D.new()
		part.name = "MouthSphere%d" % i
		var sphere = SphereMesh.new()
		sphere.radius = mouth_size
		sphere.height = mouth_size * 2
		part.mesh = sphere
		part.material_override = mouth_material
		part.position = positions[i]
		mouth.add_child(part)
	mouth.set_meta("neutral_positions", positions)
	mouth.set_meta("mouth_size", mouth_size)
	mouth.set_meta("mouth_spacing", mouth_spacing)
	set_mouth_neutral(mesh_instance, 0.0)

static func set_mouth_neutral(mesh_instance: MeshInstance3D, duration := 0.18):
	var mouth = mesh_instance.get_node_or_null("Mouth")
	if not mouth: return
	var _spacing = mouth.get_meta("mouth_spacing")
	var positions = [
		Vector3(-_spacing, 0, 0),
		Vector3(0, 0, 0),
		Vector3(_spacing, 0, 0)
	]
	CharacterAppearanceManager._tween_mouth_spheres(mouth, positions, duration)

static func set_mouth_smile(mesh_instance: MeshInstance3D, duration := 0.18):
	var mouth = mesh_instance.get_node_or_null("Mouth")
	if not mouth: return
	var _spacing = mouth.get_meta("mouth_spacing")
	var mouth_size = mouth.get_meta("mouth_size")
	var smile_y = mouth_size * 0.7
	var positions = [
		Vector3(-_spacing, smile_y, 0),
		Vector3(0, 0, 0),
		Vector3(_spacing, smile_y, 0)
	]
	CharacterAppearanceManager._tween_mouth_spheres(mouth, positions, duration)

static func set_mouth_frown(mesh_instance: MeshInstance3D, duration := 0.18):
	var mouth = mesh_instance.get_node_or_null("Mouth")
	if not mouth: return
	var _spacing = mouth.get_meta("mouth_spacing")
	var mouth_size = mouth.get_meta("mouth_size")
	var frown_y = -mouth_size * 0.7
	var positions = [
		Vector3(-_spacing, frown_y, 0),
		Vector3(0, 0, 0),
		Vector3(_spacing, frown_y, 0)
	]
	CharacterAppearanceManager._tween_mouth_spheres(mouth, positions, duration)

static func set_mouth_surprise(mesh_instance: MeshInstance3D, duration := 0.18):
	var mouth = mesh_instance.get_node_or_null("Mouth")
	if not mouth: return
	var mouth_size = mouth.get_meta("mouth_size")
	var _spacing = mouth.get_meta("mouth_spacing")
	var vertical = mouth_size * 0.7
	var positions = [
		Vector3(0, vertical, 0),
		Vector3(0, 0, 0),
		Vector3(0, -vertical, 0)
	]
	CharacterAppearanceManager._tween_mouth_spheres(mouth, positions, duration)

static func _tween_mouth_spheres(mouth: Node3D, target_positions: Array, duration: float):
	if not mouth:
		return
	var tween = mouth.create_tween()
	tween.set_parallel(true)
	for i in range(3):
		var part = mouth.get_node_or_null("MouthSphere%d" % i)
		if part:
			tween.tween_property(part, "position", target_positions[i], duration)

static func animate_eyes_look_at(character: CharacterBody3D, target_position: Vector3):
	var mesh_instance = character.get_node_or_null("MeshInstance3D")
	if not mesh_instance:
		return
	var left_eye = mesh_instance.get_node_or_null("LeftEye")
	var right_eye = mesh_instance.get_node_or_null("RightEye")
	if not left_eye or not right_eye:
		return
	for eye in [left_eye, right_eye]:
		var eyeball = eye.get_node_or_null("Eyeball")
		if not eyeball:
			continue
		var eye_global_pos = eye.global_position
		var direction = (target_position - eye_global_pos).normalized()
		var max_angle = deg_to_rad(30)
		var forward = Vector3(0, 0, 1)
		var angle = forward.angle_to(direction)
		if angle > max_angle:
			direction = forward.slerp(direction, max_angle / angle)
		eyeball.look_at(eye_global_pos + direction, Vector3.UP)

static func blink_eyes(character: CharacterBody3D, blink_duration: float = 0.15):
	var mesh_instance = character.get_node_or_null("MeshInstance3D")
	if not mesh_instance:
		return
	var left_eye = mesh_instance.get_node_or_null("LeftEye/Eyeball")
	var right_eye = mesh_instance.get_node_or_null("RightEye/Eyeball")
	if not left_eye or not right_eye:
		return
	var original_scale = Vector3.ONE
	var blink_scale = Vector3(1.0, 0.1, 1.0)
	var tween = character.create_tween()
	tween.set_parallel(true)
	tween.tween_property(left_eye, "scale", blink_scale, blink_duration / 2)
	tween.tween_property(right_eye, "scale", blink_scale, blink_duration / 2)
	tween.tween_property(left_eye, "scale", original_scale, blink_duration / 2).set_delay(blink_duration / 2)
	tween.tween_property(right_eye, "scale", original_scale, blink_duration / 2).set_delay(blink_duration / 2)

static func animate_feet_walk(left_foot: MeshInstance3D, right_foot: MeshInstance3D, left_foot_origin: Vector3, right_foot_origin: Vector3, anim_time: float, velocity: Vector3, delta: float):
	if not left_foot or not right_foot:
		return
	var speed = velocity.length()
	if speed < 0.05:
		left_foot.position = left_foot_origin
		right_foot.position = right_foot_origin
		return
	var walk_cycle_speed = clamp(speed * 4.0, 6.0, 12.0)
	var stride = 0.28
	var lift = 0.09
	var phase = anim_time * walk_cycle_speed
	var left_offset_z = sin(phase) * stride
	var left_offset_y = abs(sin(phase)) * lift
	var left_target = left_foot_origin + Vector3(0, left_offset_y, left_offset_z)
	var right_offset_z = sin(phase + PI) * stride
	var right_offset_y = abs(sin(phase + PI)) * lift
	var right_target = right_foot_origin + Vector3(0, right_offset_y, right_offset_z)
	var interp_speed = clamp(delta * 16.0, 0.0, 1.0)
	left_foot.position = left_foot.position.lerp(left_target, interp_speed)
	right_foot.position = right_foot.position.lerp(right_target, interp_speed)

func create_safe_material(base_color: Color = Color.WHITE, emission_color: Color = Color.BLACK) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	if not material:
		return null
	material.albedo_color = base_color
	if emission_color != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission_color
	return material
