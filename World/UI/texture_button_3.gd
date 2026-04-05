extends TextureButton
@export var scene_to_open: PackedScene  # Перетащите сцену в инспекторе

func _on_pressed() -> void:
	var new_scene_instance = scene_to_open.instantiate()
	get_parent().get_parent().add_child(new_scene_instance)
