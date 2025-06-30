extends RigidBody3D
class_name HelmPickup

@export var armor_data: Resource = null
@export var interaction_range: float = 2.0

var interaction_area: Area3D
var mesh_instance: MeshInstance3D
var can_be_picked_up: bool = true
var player_in_range: Node = null

func _ready():
    # Setup mesh
    if armor_data and armor_data.mesh_scene:
        mesh_instance = armor_data.mesh_scene.instantiate()
        add_child(mesh_instance)
    # Setup interaction area
    interaction_area = Area3D.new()
    var shape = SphereShape3D.new()
    shape.radius = interaction_range
    var collision_shape = CollisionShape3D.new()
    collision_shape.shape = shape
    interaction_area.add_child(collision_shape)
    add_child(interaction_area)
    interaction_area.body_entered.connect(_on_body_entered)
    interaction_area.body_exited.connect(_on_body_exited)
    add_to_group("pickups")
    add_to_group("interactables")

func _on_body_entered(body):
    if body.is_in_group("player"):
        player_in_range = body
        # Optionally: Show interaction prompt

func _on_body_exited(body):
    if body == player_in_range:
        player_in_range = null
        # Optionally: Hide interaction prompt

func interact():
    if can_be_picked_up and player_in_range:
        if player_in_range.has_method("pickup_armor"):
            player_in_range.pickup_armor(armor_data)
            queue_free()
