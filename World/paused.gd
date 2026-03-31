extends Control
@export var scene_to_open: PackedScene  # Перетащите сцену в инспекторе



func _on_texture_button_pressed() -> void:
	
	queue_free()


func _on_texture_button_2_pressed() -> void:
	var new_scene_instance = scene_to_open.instantiate()
	add_child(new_scene_instance)


func _on_texture_button_3_pressed() -> void:
	get_tree().change_scene_to_file("res://world/menu.tscn")
