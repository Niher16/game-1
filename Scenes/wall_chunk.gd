# wall_chunk.gd - Projectile thrown by Demolition King boss
extends RigidBody3D

@export var damage = 10
@export var lifetime = 5.0

func _ready():
	# Enable collision detection
	body_entered.connect(_on_body_entered)
	
	# Auto-cleanup after lifetime expires
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		queue_free()

func throw(force: Vector3):
	"""Called by boss to launch this chunk"""
	linear_velocity = force
	angular_velocity = Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5))

func _on_body_entered(body):
	"""Handle collision with player or walls"""
	
	# Hit player - deal damage
	if body.is_in_group("player"):
		print("🪨 Wall chunk hit player!")
		if body.has_method("take_damage"):
			body.take_damage(damage, self)
		queue_free()
	
	# Hit wall or ground - just bounce naturally
	# RigidBody3D physics will handle this automatically
