extends Node
class_name AllyPersonality

@export var boldness: float = 0.5
@export var caution: float = 0.5
@export var loyalty: float = 0.5
@export var curiosity: float = 0.5
@export var aggressiveness: float = 0.5

func _ready():
	randomize()
	boldness = randf_range(0.2, 1.0)
	caution = randf_range(0.0, 1.0)
	loyalty = randf_range(0.3, 1.0)
	curiosity = randf_range(0.0, 1.0)
	aggressiveness = randf_range(0.2, 1.0)

func get_trait_summary() -> String:
	return "Boldness: %.2f, Caution: %.2f, Loyalty: %.2f, Curiosity: %.2f, Aggressiveness: %.2f" % [boldness, caution, loyalty, curiosity, aggressiveness]
