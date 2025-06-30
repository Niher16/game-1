extends Node

@export_group("Lighting Scenes")
@export var chandelier_scene: PackedScene
@export var brazier_scene: PackedScene
@export var mushroom_scene: PackedScene
@export var torch_scene: PackedScene

enum LightingTheme {
    GRAND_HALL,
    MYSTICAL_GROVE,
    BRAZIER_CHAMBER,
    TORCH_CORRIDOR,
    MIXED_AMBIANCE,
    DARK_CHAMBER,
    CEREMONIAL
}

var _lighting_scenes = {}

func _ready():
    _load_lighting_scenes()
    print("💡 LightingManager ready. Scenes cached.")

func _load_lighting_scenes():
    _lighting_scenes = {
        "chandelier": chandelier_scene,
        "brazier": brazier_scene,
        "mushroom": mushroom_scene,
        "torch": torch_scene
    }

func assign_lighting_theme(room: Rect2, room_shape: String, is_weapon_room: bool) -> LightingTheme:
    var area = room.size.x * room.size.y
    if is_weapon_room:
        return LightingTheme.CEREMONIAL
    if area >= 64:
        return LightingTheme.GRAND_HALL if room_shape in ["SQUARE", "RECTANGLE"] else LightingTheme.MIXED_AMBIANCE
    elif area >= 24:
        if room_shape in ["L_SHAPE", "T_SHAPE"]:
            return LightingTheme.MIXED_AMBIANCE
        return LightingTheme.BRAZIER_CHAMBER
    else:
        if room_shape == "LONG_HALL":
            return LightingTheme.TORCH_CORRIDOR
        return LightingTheme.MYSTICAL_GROVE

func apply_lighting_theme(room: Rect2, theme: LightingTheme, room_shape: String):
    print("🕯️ Applying lighting theme: %s to room at %s" % [str(theme), str(room.position)])
    match theme:
        LightingTheme.GRAND_HALL:
            _create_grand_hall_lighting(room)
        LightingTheme.MYSTICAL_GROVE:
            _create_mystical_grove_lighting(room, room_shape)
        LightingTheme.BRAZIER_CHAMBER:
            _create_brazier_chamber_lighting(room)
        LightingTheme.TORCH_CORRIDOR:
            _create_torch_corridor_lighting(room)
        LightingTheme.MIXED_AMBIANCE:
            _create_mixed_ambiance_lighting(room, room_shape)
        LightingTheme.DARK_CHAMBER:
            _create_dark_chamber_lighting(room)
        LightingTheme.CEREMONIAL:
            _create_ceremonial_lighting(room)

# --- Theme Implementations ---

func _create_grand_hall_lighting(room: Rect2):
    # Central chandelier
    var chandelier = _lighting_scenes["chandelier"].instantiate()
    chandelier.position = room.position + room.size / 2
    add_child(chandelier)
    chandelier.add_to_group("destructible_lights")
    # Braziers at corners/perimeter
    for i in range(4):
        var angle = PI/2 * i
        var offset = Vector2(cos(angle), sin(angle)) * (room.size / 2 * 0.8)
        var brazier = _lighting_scenes["brazier"].instantiate()
        brazier.position = room.position + room.size / 2 + offset
        add_child(brazier)
        brazier.add_to_group("braziers")
    _place_torches_along_walls(room, 4)

func _create_mystical_grove_lighting(room: Rect2, _room_shape: String):
    var corners = [
        room.position,
        room.position + Vector2(room.size.x, 0),
        room.position + Vector2(0, room.size.y),
        room.position + room.size
    ]
    for corner in corners:
        var mushroom = _lighting_scenes["mushroom"].instantiate()
        mushroom.position = corner + Vector2(randf_range(-1,1), randf_range(-1,1)) * 2
        add_child(mushroom)
        mushroom.add_to_group("natural_lights")
    for i in range(1, 4):
        var pos = room.position + Vector2(room.size.x * i/4, 0)
        var mushroom = _lighting_scenes["mushroom"].instantiate()
        mushroom.position = pos
        add_child(mushroom)
        mushroom.add_to_group("natural_lights")
    # Minimal torches if needed (optional)

func _create_brazier_chamber_lighting(room: Rect2):
    var count = clamp(int(room.size.x * room.size.y / 32), 1, 3)
    for i in range(count):
        var pos = room.position + Vector2(randf_range(0.2,0.8)*room.size.x, randf_range(0.2,0.8)*room.size.y)
        var brazier = _lighting_scenes["brazier"].instantiate()
        brazier.position = pos
        add_child(brazier)
        brazier.add_to_group("braziers")
    _place_torches_along_walls(room, 2)

func _create_torch_corridor_lighting(room: Rect2):
    _place_torches_along_walls(room, 6)

func _create_mixed_ambiance_lighting(room: Rect2, room_shape: String):
    _create_brazier_chamber_lighting(room)
    _create_mystical_grove_lighting(room, room_shape)

func _create_dark_chamber_lighting(_room: Rect2):
    # No lights or a single dim light for atmosphere
    pass

func _create_ceremonial_lighting(room: Rect2):
    var chandelier = _lighting_scenes["chandelier"].instantiate()
    chandelier.position = room.position + room.size / 2
    add_child(chandelier)
    chandelier.add_to_group("destructible_lights")
    for corner in [room.position, room.position + Vector2(room.size.x, 0), room.position + Vector2(0, room.size.y), room.position + room.size]:
        var mushroom = _lighting_scenes["mushroom"].instantiate()
        mushroom.position = corner
        add_child(mushroom)
        mushroom.add_to_group("natural_lights")
    var center = room.position + room.size / 2
    var radius = min(room.size.x, room.size.y) * 0.3
    for i in range(8):
        var angle = TAU * i / 8
        var pos = center + Vector2(cos(angle), sin(angle)) * radius
        var torch = _lighting_scenes["torch"].instantiate()
        torch.position = pos
        add_child(torch)
        torch.add_to_group("interactive_lights")

# --- Helper Functions ---

func _place_torches_along_walls(room: Rect2, count: int):
    for i in range(count):
        var pos = room.position + Vector2(room.size.x * i/(count-1), 0)
        var torch = _lighting_scenes["torch"].instantiate()
        torch.position = pos
        add_child(torch)
        torch.add_to_group("interactive_lights")

# --- Corridor Integration Stub ---

func connect_corridor_lighting_to_rooms(_corridor: Dictionary, _room_a_theme: LightingTheme, _room_b_theme: LightingTheme):
    # To be implemented: adapt corridor lighting based on room themes
    pass

# --- Dynamic Lighting Events Stubs ---

func toggle_theme_specific_lights(theme: LightingTheme):
    match theme:
        LightingTheme.GRAND_HALL:
            for light in get_tree().get_nodes_in_group("destructible_lights"):
                light.visible = !light.visible
        LightingTheme.MYSTICAL_GROVE:
            for light in get_tree().get_nodes_in_group("natural_lights"):
                light.visible = !light.visible
        # ...etc

func create_dramatic_lighting_event():
    # To be enhanced
    pass

func restore_all_lighting():
    # To be enhanced
    pass
