extends Node

class_name PlayerCombat

# Handles player combat logic
var controller
signal attack_performed

var attack_damage := 10
var attack_cooldown := 1.0
var can_attack := true

func initialize(new_controller):
	self.controller = new_controller

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
