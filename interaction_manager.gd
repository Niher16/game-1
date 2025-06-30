extends Node
class_name InteractionManager

var current_interactable: Node = null
var interaction_ui_label: Label = null  # Assign in the editor or via code

func _input(event):
    if event.is_action_pressed("interact"):
        if current_interactable and current_interactable.has_method("interact"):
            current_interactable.interact()

func set_interactable(object: Node):
    current_interactable = object
    if interaction_ui_label:
        if object:
            interaction_ui_label.text = "Press E to interact"
            interaction_ui_label.visible = true
        else:
            interaction_ui_label.visible = false
