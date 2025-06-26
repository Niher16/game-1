extends StaticBody3D

@export var is_open: bool = false
@export var open_animation_time: float = 1.0

var player_in_range := false

func _ready():
	var area = $Area3D if has_node("Area3D") else null
	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)
	else:
		print("[JailDoor] Warning: Area3D node not found. Signals not connected.")

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false

func _process(_delta):
	if player_in_range and Input.is_action_just_pressed("interact") and not is_open:
		open_door()

func open_door():
	is_open = true
	$CollisionShape3D.disabled = true
