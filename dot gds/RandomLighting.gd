extends DirectionalLight3D

# Randomizes sun position and brightness for a unique look every run
func _ready():
	# Fixed warm sunlight color
	light_color = Color(1.0, 0.95, 0.85) # soft warm white
	print("[RandomLighting] light_color (fixed):", light_color)

	randomize() # Ensure different random values each run

	# Randomize energy (brightness)
	light_energy = randf_range(2.0, 6.0)
	print("[RandomLighting] light_energy:", light_energy)

	# Randomize direction (rotation)
	rotation_degrees.x = randf_range(20, 70) # sun height
	rotation_degrees.y = randf_range(0, 360) # sun azimuth
	print("[RandomLighting] rotation_degrees:", rotation_degrees)

	# Optional: randomize shadow blur for softness
	shadow_blur = randf_range(0.05, 0.2)
	print("[RandomLighting] shadow_blur:", shadow_blur)
