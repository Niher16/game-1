# DashEffectsManager.gd - Handles all dash visual effects
extends Node

func play_dash_effects(character: Node3D, dash_direction: Vector3):
	"""Main entry point - creates both wind trail and speed lines"""
	_create_dash_wind_trail(character, dash_direction)
	_create_dash_speed_lines(character)

func _create_dash_wind_trail(character: Node3D, direction: Vector3):
	"""Create wind trail particles behind character"""
	for i in range(8):
		var wind_particle = MeshInstance3D.new()
		character.get_parent().add_child(wind_particle)
		
		# Create wind streak mesh
		var streak_mesh = BoxMesh.new()
		streak_mesh.size = Vector3(0.1, 0.05, 0.6)
		wind_particle.mesh = streak_mesh
		
		# Position behind character with spread
		var offset = Vector3(
			randf_range(-0.5, 0.5),
			randf_range(-0.2, 0.5),
			randf_range(-0.3, 0.3)
		)
		wind_particle.global_position = character.global_position + offset - (direction * 0.5)
		
		# Align with dash direction
		if direction.length() > 0:
			wind_particle.look_at(wind_particle.global_position + direction, Vector3.UP)
		
		# Wind material with transparency
		var wind_material = StandardMaterial3D.new()
		wind_material.albedo_color = Color(0.8, 0.9, 1.0, 0.6)
		wind_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wind_material.emission_enabled = true
		wind_material.emission = Color(0.6, 0.8, 1.0) * 0.5
		wind_particle.material_override = wind_material
		
		# Animate wind trail
		var tween = character.create_tween()
		tween.set_parallel(true)
		
		var end_pos = wind_particle.global_position - (direction * 3.0)
		tween.tween_property(wind_particle, "global_position", end_pos, 0.4)
		tween.tween_property(wind_particle, "scale", Vector3(0.1, 0.1, 2.0), 0.4)
		
		# Simple fade using scale instead of alpha
		tween.tween_property(wind_particle, "scale", Vector3.ZERO, 0.3).set_delay(0.1)
		tween.tween_callback(wind_particle.queue_free).set_delay(0.4)

func _create_dash_speed_lines(character: Node3D):
	"""Create speed lines converging on character"""
	for i in range(6):
		var speed_line = MeshInstance3D.new()
		character.get_parent().add_child(speed_line)
		
		# Create speed line mesh
		var line_mesh = BoxMesh.new()
		line_mesh.size = Vector3(0.02, 0.02, 1.2)
		speed_line.mesh = line_mesh
		
		# Position around character in circle
		var angle = (float(i) / 6.0) * TAU
		var radius = 1.5
		var line_pos = character.global_position + Vector3(
			cos(angle) * radius,
			randf_range(-0.5, 1.0),
			sin(angle) * radius
		)
		speed_line.global_position = line_pos
		speed_line.look_at(character.global_position, Vector3.UP)
		
		# Speed line material
		var line_material = StandardMaterial3D.new()
		line_material.albedo_color = Color.WHITE
		line_material.emission_enabled = true
		line_material.emission = Color.WHITE * 0.8
		speed_line.material_override = line_material
		
		# Animate speed lines
		var tween = character.create_tween()
		tween.set_parallel(true)
		
		tween.tween_property(speed_line, "global_position", character.global_position, 0.25)
		tween.tween_property(speed_line, "scale", Vector3(0.1, 0.1, 0.1), 0.25)
		tween.tween_callback(speed_line.queue_free).set_delay(0.25)
