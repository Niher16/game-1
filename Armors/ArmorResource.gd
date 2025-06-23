extends Node

# Armor type enum
enum ArmorType { HELM, CHEST, SHOULDERS, BOOTS }
const HELM = ArmorType.HELM
const CHEST = ArmorType.CHEST
const SHOULDERS = ArmorType.SHOULDERS
const BOOTS = ArmorType.BOOTS

@export var armor_name: String = ""
@export var armor_type: int = HELM
@export var durability: int = 100
@export var protection_amount: int = 0
@export var armor_mesh: Resource
