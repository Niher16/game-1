extends Node
class_name AllyHealth

signal health_changed(current: int, maximum: int)
signal ally_died
signal health_depleted

var ally_ref
var current_health: int
var max_health: int
var invuln_timer := 0.0
var invuln_duration := 0.5

func setup(ally, max_hp: int):
	ally_ref = ally
	max_health = max_hp
	current_health = max_health
	health_changed.emit(current_health, max_health)

func _process(delta):
	if invuln_timer > 0:
		invuln_timer -= delta

func take_damage(amount: int, attacker: Node = null):
	if current_health <= 0 or invuln_timer > 0:
		return
	invuln_timer = invuln_duration
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	if attacker and current_health > 0:
		_apply_knockback(attacker)
	if current_health <= 0:
		ally_died.emit()
		health_depleted.emit()

func _apply_knockback(attacker: Node):
	if ally_ref and ally_ref.has_method("apply_knockback_from_attacker"):
		ally_ref.apply_knockback_from_attacker(attacker)

func heal(amount: int):
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)

func _die():
	queue_free()
