# BodyPartVariants.gd - FIXED VERSION
class_name BodyPartVariants
extends Resource

# =================================
# SKIN TONE VARIATIONS - FIXED NAMES
# =================================
static var skin_tones = [
	Color(0.95, 0.87, 0.73),  # Very light
	Color(0.92, 0.80, 0.65),  # Light
	Color(0.90, 0.72, 0.58),  # Light-medium
	Color(0.85, 0.65, 0.48),  # Medium
	Color(0.76, 0.57, 0.42),  # Medium-dark
	Color(0.65, 0.48, 0.35),  # Dark
	Color(0.45, 0.35, 0.25),  # Very dark
	Color(0.88, 0.74, 0.56),  # Warm tone
	Color(0.82, 0.68, 0.52),  # Olive tone
	Color(0.98, 0.85, 0.75),  # Porcelain
	Color(0.87, 0.67, 0.45),  # Golden
	Color(0.55, 0.42, 0.30),  # Deep bronze
	# --- Added realistic global skin tones with undertones ---
	Color(0.99, 0.92, 0.82),  # Light (peachy undertone)
	Color(0.96, 0.85, 0.78),  # Light (rosy undertone)
	Color(0.93, 0.80, 0.70),  # Light (yellow undertone)
	Color(0.80, 0.65, 0.55),  # Medium (neutral undertone)
	Color(0.72, 0.54, 0.40),  # Medium (warm undertone)
	Color(0.60, 0.44, 0.32),  # Medium-dark (cool undertone)
	Color(0.50, 0.36, 0.28),  # Dark (neutral undertone)
	Color(0.36, 0.24, 0.18),  # Deep (cool undertone)
]

# =================================
# BODY PROPORTIONS - FIXED TO ARRAYS
# =================================
static var body_types = ["capsule", "box", "tall", "wide", "slim"]
static var body_heights = [1.2, 1.35, 1.5, 1.65, 1.8]
static var body_widths = [0.22, 0.28, 0.3, 0.32, 0.38]

# Keep the variants dict for detailed info
static var BODY_VARIANTS = {
	"tiny": {"height": 1.2, "radius": 0.25, "name": "Tiny"},
	"short": {"height": 1.35, "radius": 0.28, "name": "Short"},
	"average": {"height": 1.5, "radius": 0.3, "name": "Average"},
	"tall": {"height": 1.65, "radius": 0.32, "name": "Tall"},
	"giant": {"height": 1.8, "radius": 0.35, "name": "Giant"},
	"thin": {"height": 1.5, "radius": 0.22, "name": "Thin"},
	"wide": {"height": 1.45, "radius": 0.38, "name": "Wide"},
	"stocky": {"height": 1.3, "radius": 0.35, "name": "Stocky"},
}

# =================================
# HAIR - FIXED ARRAYS
# =================================
static var hair_styles = [
	"bald", "buzz_cut", "short_messy", "medium_wavy", "long_straight",
	"curly_afro", "mohawk", "ponytail", "bun", "spiky", "side_part", "wild_crazy"
]

static var hair_colors = [
	Color(0.1, 0.05, 0.02),   # Black
	Color(0.3, 0.15, 0.05),   # Dark brown
	Color(0.45, 0.25, 0.1),   # Brown
	Color(0.6, 0.4, 0.2),     # Light brown
	Color(0.8, 0.6, 0.3),     # Dirty blonde
	Color(0.9, 0.8, 0.5),     # Blonde
	Color(0.95, 0.9, 0.8),    # Platinum blonde
	Color(0.7, 0.2, 0.1),     # Auburn
	Color(0.8, 0.3, 0.1),     # Ginger
	Color(0.5, 0.5, 0.5),     # Gray
	Color(0.9, 0.9, 0.9),     # White
]

# =================================
# FACIAL HAIR - FIXED ARRAYS
# =================================
static var facial_hair_styles = [
	"none", "stubble", "goatee", "full_beard", "mustache", "soul_patch",
	"chinstrap", "mutton_chops", "handlebar_mustache", "viking_beard", "pencil_mustache"
]

static var facial_hair_colors = hair_colors  # Same as hair colors

# =================================
# EYES - FIXED ARRAYS
# =================================
static var eye_shapes = ["sphere", "flat", "large", "small", "narrow", "wide", "sleepy"]
static var eye_colors = [
	Color(0.1, 0.05, 0.0),    # Dark brown
	Color(0.3, 0.15, 0.05),   # Brown
	Color(0.4, 0.25, 0.1),    # Light brown
	Color(0.2, 0.4, 0.1),     # Hazel
	Color(0.1, 0.3, 0.6),     # Blue
	Color(0.0, 0.5, 0.2),     # Green
	Color(0.3, 0.3, 0.3),     # Gray
	Color(0.15, 0.35, 0.4),   # Blue-green
	Color(0.4, 0.2, 0.3),     # Violet (rare)
]
static var eye_sizes = [0.06, 0.075, 0.09, 0.11, 0.13]
static var eye_spacings = [0.2, 0.26, 0.32]

# Keep the detailed variants
static var EYE_VARIANTS = {
	"tiny": {"size": 0.06, "name": "Tiny Eyes"},
	"small": {"size": 0.075, "name": "Small Eyes"},
	"normal": {"size": 0.09, "name": "Normal Eyes"},
	"large": {"size": 0.11, "name": "Large Eyes"},
	"huge": {"size": 0.13, "name": "Huge Eyes"},
	"narrow": {"size": 0.09, "scale": Vector3(1.3, 0.6, 1.0), "name": "Narrow Eyes"},
	"wide": {"size": 0.09, "scale": Vector3(0.8, 1.4, 1.0), "name": "Wide Eyes"},
	"sleepy": {"size": 0.08, "scale": Vector3(1.0, 0.5, 1.0), "name": "Sleepy Eyes"},
}

# =================================
# NOSE - FIXED ARRAYS
# =================================
static var nose_shapes = ["sphere", "cylinder", "flat", "none"]
static var nose_sizes = [0.06, 0.075, 0.09, 0.11]
static var nose_projections = [0.15, 0.18, 0.22, 0.26, 0.28]

static var NOSE_VARIANTS = {
	"button": {"shape": "sphere", "size": 0.06, "projection": 0.15, "name": "Button Nose"},
	"small": {"shape": "sphere", "size": 0.075, "projection": 0.18, "name": "Small Nose"},
	"normal": {"shape": "sphere", "size": 0.09, "projection": 0.22, "name": "Normal Nose"},
	"large": {"shape": "sphere", "size": 0.11, "projection": 0.26, "name": "Large Nose"},
	"roman": {"shape": "cylinder", "size": 0.09, "projection": 0.24, "name": "Roman Nose"},
	"flat": {"shape": "flat", "size": 0.08, "projection": 0.12, "name": "Flat Nose"},
	"aquiline": {"shape": "cylinder", "size": 0.08, "projection": 0.28, "name": "Aquiline Nose"},
	"none": {"shape": "none", "name": "No Nose"},
}

# =================================
# MOUTH - FIXED ARRAYS
# =================================
static var mouth_styles = ["flat", "smile", "frown", "line", "open", "grin"]
static var mouth_widths = [0.04, 0.05, 0.06, 0.07, 0.08]
static var mouth_expressions = ["neutral", "smile", "frown", "surprise", "talking"]

static var MOUTH_VARIANTS = {
	"tiny": {"style": "flat", "width": 0.04, "name": "Tiny Mouth"},
	"small": {"style": "flat", "width": 0.05, "name": "Small Mouth"},
	"normal": {"style": "flat", "width": 0.06, "name": "Normal Mouth"},
	"wide": {"style": "flat", "width": 0.08, "name": "Wide Mouth"},
	"smile": {"style": "smile", "width": 0.06, "name": "Smiling"},
	"frown": {"style": "frown", "width": 0.06, "name": "Frowning"},
	"grin": {"style": "grin", "width": 0.07, "name": "Big Grin"},
	"open": {"style": "open", "width": 0.05, "name": "Open Mouth"},
	"line": {"style": "line", "width": 0.06, "name": "Straight Line"},
}

# =================================
# EARS - FIXED ARRAYS
# =================================
static var ear_shapes = ["round", "pointed", "large", "small", "none"]
static var ear_sizes = [0.035, 0.04, 0.05, 0.06, 0.08]

static var EAR_VARIANTS = {
	"tiny": {"shape": "round", "size": 0.035, "name": "Tiny Ears"},
	"small": {"shape": "small", "size": 0.04, "name": "Small Ears"},
	"normal": {"shape": "round", "size": 0.05, "name": "Normal Ears"},
	"large": {"shape": "large", "size": 0.06, "name": "Large Ears"},
	"pointed": {"shape": "pointed", "size": 0.05, "name": "Pointed Ears"},
	"dumbo": {"shape": "large", "size": 0.08, "name": "Dumbo Ears"},
	"none": {"shape": "none", "name": "No Ears"},
}

# =================================
# HANDS - FIXED ARRAYS
# =================================
static var hand_sizes = [0.06, 0.07, 0.08, 0.09, 0.11]

static var HAND_VARIANTS = {
	"tiny": {"size": 0.06, "name": "Tiny Hands"},
	"small": {"size": 0.07, "name": "Small Hands"},
	"normal": {"size": 0.08, "name": "Normal Hands"},
	"large": {"size": 0.09, "name": "Large Hands"},
	"huge": {"size": 0.11, "name": "Huge Hands"},
}

# =================================
# FEET - FIXED ARRAYS
# =================================
static var foot_shapes = ["bare", "boot", "small"]  # Removed "big"

static var FOOT_VARIANTS = {
	"tiny": {"shape": "bare", "size": Vector3(0.12, 0.05, 0.2), "name": "Tiny Feet"},
	"small": {"shape": "small", "size": Vector3(0.13, 0.055, 0.22), "name": "Small Feet"},
	"normal": {"shape": "bare", "size": Vector3(0.15, 0.06, 0.25), "name": "Normal Feet"},
	"large": {"shape": "bare", "size": Vector3(0.17, 0.065, 0.28), "name": "Large Feet"},
	"wide": {"shape": "bare", "size": Vector3(0.22, 0.07, 0.28), "name": "Wide Feet"},  # Replaces "clown", uses box shape
	"boots": {"shape": "boot", "size": Vector3(0.16, 0.07, 0.26), "name": "Boots"},
}

# =================================
# UTILITY FUNCTIONS
# =================================
static func get_random_variant(variant_dict: Dictionary) -> Dictionary:
	var keys = variant_dict.keys()
	var random_key = keys[randi() % keys.size()]
	var variant = variant_dict[random_key].duplicate()
	variant["key"] = random_key
	return variant

static func get_random_from_array(array: Array):
	return array[randi() % array.size()]

static func get_variant_by_key(variant_dict: Dictionary, key: String) -> Dictionary:
	if variant_dict.has(key):
		var variant = variant_dict[key].duplicate()
		variant["key"] = key
		return variant
	else:
		return get_random_variant(variant_dict)

static func get_random_color_variation(base_color: Color, variation: float = 0.1) -> Color:
	var hue_var = randf_range(-variation, variation)
	var sat_var = randf_range(-variation, variation)
	var val_var = randf_range(-variation, variation)
	return Color.from_hsv(
		fmod(base_color.h + hue_var + 1.0, 1.0),
		clamp(base_color.s + sat_var, 0.0, 1.0),
		clamp(base_color.v + val_var, 0.0, 1.0)
	)

static func get_complementary_color(color: Color) -> Color:
	return Color.from_hsv(fmod(color.h + 0.5, 1.0), color.s, color.v)

static func blend_colors(color1: Color, color2: Color, weight: float = 0.5) -> Color:
	return color1.lerp(color2, weight)

# Helper: Get skin tone by category
static func get_skin_tone_by_category(category: String) -> Color:
	var tones = skin_tones
	match category.to_lower():
		"light":
			return tones[randi() % 6] # First 6 are lightest
		"medium":
			return tones[5 + randi() % 6] # Next 6 are medium
		"dark":
			return tones[11 + randi() % 7] # Last 7 are darkest
		"warm":
			return tones[7] if tones.size() > 7 else tones[0]
		"cool":
			return tones[17] if tones.size() > 17 else tones[-1]
		"random":
			return tones[randi() % tones.size()]
		_:
			return tones[randi() % tones.size()]
