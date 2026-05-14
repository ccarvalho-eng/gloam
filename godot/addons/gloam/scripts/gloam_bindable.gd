class_name GloamBindable
extends ColorRect

@export var gloam_id: String = ""
@export var gloam_kind: String = "location"
@export var interaction_type: String = "inspect"
@export var display_name: String = ""

func _ready() -> void:
	add_to_group("gloam_bindable")

func interaction_label() -> String:
	if display_name != "":
		return display_name

	return gloam_id.capitalize()

func interaction_position() -> Vector2:
	return global_position + size * 0.5
