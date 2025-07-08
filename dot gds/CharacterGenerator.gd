# CharacterGenerator.gd - FIXED VERSION
class_name CharacterGenerator
extends Node

static func generate_random_character_config() -> Dictionary:
	"""Generate a completely random character configuration"""
	
	var config = {}
	
	# Basic body
	config["skin_tone"] = BodyPartVariants.skin_tones.pick_random()
	config["body_type"] = BodyPartVariants.body_types.pick_random()
	config["body_height"] = BodyPartVariants.body_heights.pick_random()
	config["body_radius"] = BodyPartVariants.body_widths.pick_random()
	
	# Eyes
	config["eyes"] = {
		"shape": BodyPartVariants.eye_shapes.pick_random(),
		"color": BodyPartVariants.eye_colors.pick_random(),
		"size": BodyPartVariants.eye_sizes.pick_random(),
		"spacing": BodyPartVariants.eye_spacings.pick_random()
	}
	
	# Nose
	config["nose"] = {
		"shape": BodyPartVariants.nose_shapes.pick_random(),
		"size": BodyPartVariants.nose_sizes.pick_random(),
		"projection": BodyPartVariants.nose_projections.pick_random()
	}
	
	# Mouth
	config["mouth"] = {
		"style": BodyPartVariants.mouth_styles.pick_random(),
		"width": BodyPartVariants.mouth_widths.pick_random()
	}
	
	# Ears
	config["ears"] = {
		"shape": BodyPartVariants.ear_shapes.pick_random(),
		"size": BodyPartVariants.ear_sizes.pick_random()
	}
	
	# Hair
	config["hair"] = {
		"style": BodyPartVariants.hair_styles.pick_random(),
		"color": BodyPartVariants.hair_colors.pick_random()
	}
	
	# Facial hair
	config["facial_hair"] = {
		"style": BodyPartVariants.facial_hair_styles.pick_random(),
		"color": BodyPartVariants.facial_hair_colors.pick_random()
	}
	
	# Hands and feet
	config["hands"] = {
		"size": BodyPartVariants.hand_sizes.pick_random()
	}
	
	config["feet"] = {
		"shape": BodyPartVariants.foot_shapes.pick_random()
	}
	
	return config

static func generate_character_with_seed(seed_value: int) -> Dictionary:
	"""Generate a character using a specific seed for reproducible results"""
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	
	var config = {}
	
	# Basic body - FIXED: Use proper array access
	config["skin_tone"] = BodyPartVariants.skin_tones[rng.randi() % BodyPartVariants.skin_tones.size()]
	config["body_type"] = BodyPartVariants.body_types[rng.randi() % BodyPartVariants.body_types.size()]
	config["body_height"] = BodyPartVariants.body_heights[rng.randi() % BodyPartVariants.body_heights.size()]
	config["body_radius"] = BodyPartVariants.body_widths[rng.randi() % BodyPartVariants.body_widths.size()]
	
	# Eyes - FIXED: Consistent with arrays
	config["eyes"] = {
		"shape": BodyPartVariants.eye_shapes[rng.randi() % BodyPartVariants.eye_shapes.size()],
		"color": BodyPartVariants.eye_colors[rng.randi() % BodyPartVariants.eye_colors.size()],
		"size": BodyPartVariants.eye_sizes[rng.randi() % BodyPartVariants.eye_sizes.size()],
		"spacing": BodyPartVariants.eye_spacings[rng.randi() % BodyPartVariants.eye_spacings.size()]
	}
	
	# Nose - FIXED: Consistent with arrays
	config["nose"] = {
		"shape": BodyPartVariants.nose_shapes[rng.randi() % BodyPartVariants.nose_shapes.size()],
		"size": BodyPartVariants.nose_sizes[rng.randi() % BodyPartVariants.nose_sizes.size()],
		"projection": BodyPartVariants.nose_projections[rng.randi() % BodyPartVariants.nose_projections.size()]
	}
	
	# Mouth - FIXED: Consistent with arrays
	config["mouth"] = {
		"style": BodyPartVariants.mouth_styles[rng.randi() % BodyPartVariants.mouth_styles.size()],
		"width": BodyPartVariants.mouth_widths[rng.randi() % BodyPartVariants.mouth_widths.size()]
	}
	
	# Ears - FIXED: Consistent with arrays
	config["ears"] = {
		"shape": BodyPartVariants.ear_shapes[rng.randi() % BodyPartVariants.ear_shapes.size()],
		"size": BodyPartVariants.ear_sizes[rng.randi() % BodyPartVariants.ear_sizes.size()]
	}
	
	# Hair - FIXED: Consistent with arrays
	config["hair"] = {
		"style": BodyPartVariants.hair_styles[rng.randi() % BodyPartVariants.hair_styles.size()],
		"color": BodyPartVariants.hair_colors[rng.randi() % BodyPartVariants.hair_colors.size()]
	}
	
	# Facial hair - FIXED: Consistent with arrays
	config["facial_hair"] = {
		"style": BodyPartVariants.facial_hair_styles[rng.randi() % BodyPartVariants.facial_hair_styles.size()],
		"color": BodyPartVariants.facial_hair_colors[rng.randi() % BodyPartVariants.facial_hair_colors.size()]
	}
	
	# Hands and feet - FIXED: Consistent with arrays
	config["hands"] = {
		"size": BodyPartVariants.hand_sizes[rng.randi() % BodyPartVariants.hand_sizes.size()]
	}
	
	config["feet"] = {
		"shape": BodyPartVariants.foot_shapes[rng.randi() % BodyPartVariants.foot_shapes.size()]
	}
	
	return config

# NEW: Helper function to generate characters by archetype
static func generate_character_by_type(character_type: String) -> Dictionary:
	"""Generate characters with certain tendencies based on type"""
	var config = generate_random_character_config()
	
	match character_type:
		"warrior":
			# Tend toward larger, more intimidating features
			config["body_height"] = BodyPartVariants.body_heights[-1]  # Tallest
			config["body_radius"] = BodyPartVariants.body_widths[-1]   # Widest
			config["mouth"]["style"] = "frown"
			config["ears"]["shape"] = "small"  # Battle-hardened
			
		"scholar":
			# Tend toward smaller, more refined features
			config["body_height"] = BodyPartVariants.body_heights[1]   # Shorter
			config["body_radius"] = BodyPartVariants.body_widths[0]    # Thinner
			config["eyes"]["size"] = BodyPartVariants.eye_sizes[-1]    # Large eyes
			config["nose"]["shape"] = "flat"
			
		"rogue":
			# Tend toward average build, sharp features
			config["body_height"] = BodyPartVariants.body_heights[2]   # Average
			config["eyes"]["shape"] = "narrow"
			config["facial_hair"]["style"] = "goatee"
			
		"merchant":
			# Tend toward well-fed, friendly appearance
			config["body_radius"] = BodyPartVariants.body_widths[-2]   # Wide
			config["mouth"]["style"] = "smile"
			config["facial_hair"]["style"] = "full_beard"
	
	return config

# Apply a skin tone to an ally using CharacterAppearanceManager
static func apply_skin_tone_to_ally(character: CharacterBody3D, skin_tone: Color):
	var config = generate_random_character_config()
	config["skin_tone"] = skin_tone
	CharacterAppearanceManager.create_player_appearance(character, config)

# Generate a team with unique skin tones
static func generate_team_with_skin_variety(team_size: int) -> Array:
	var rng = RandomNumberGenerator.new()
	var used_indices = []
	var configs = []
	var tones = BodyPartVariants.skin_tones
	var max_unique = min(team_size, tones.size())
	for i in range(max_unique):
		var idx = i
		used_indices.append(idx)
	for i in range(team_size):
		var config = generate_random_character_config()
		if i < max_unique:
			config["skin_tone"] = tones[used_indices[i]]
		else:
			config["skin_tone"] = tones[rng.randi() % tones.size()]
		configs.append(config)
	return configs
