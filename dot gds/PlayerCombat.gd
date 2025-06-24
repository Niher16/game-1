extends Node

class_name PlayerCombat

# Handles player combat logic
@export var controller: CharacterBody3D  # Properly typed controller reference
signal attack_performed

var attack_damage := 10
var attack_cooldown := 1.0
var can_attack := true

func initialize(new_controller: CharacterBody3D) -> void:
	if not new_controller:  # Null safety check
		push_error("PlayerCombat: Controller cannot be null")
		return
	controller = new_controller  # Now properly typed assignment
	print("✅ PlayerCombat: Controller initialized successfully")

func perform_attack():
	if can_attack:
		attack_performed.emit()
		can_attack = false
		# Start cooldown timer
		var timer = Timer.new()
		timer.wait_time = attack_cooldown
		timer.one_shot = true
		add_child(timer)
		timer.timeout.connect(_on_attack_cooldown_finished)
		timer.start()

func _on_attack_cooldown_finished():
	can_attack = true
