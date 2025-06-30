extends Resource
class_name ArmorItem

@export var item_name: String = ""
@export var armor_type: ArmorType
@export var defense_value: int = 0
@export var mesh_scene: PackedScene
@export var icon: Texture2D

enum ArmorType {
    HELM,
    CHEST,
    LEGS,
    BOOTS,
    GLOVES
}
