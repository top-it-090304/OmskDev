extends Control
@export var scene_to_open: PackedScene  # Перетащите сцену в инспекторе
@export var target_scene: PackedScene
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused=true

func _on_texture_button_pressed() -> void:
	get_tree().paused=false
	queue_free()


func _on_texture_button_2_pressed() -> void:
	var new_scene_instance = scene_to_open.instantiate()
	add_child(new_scene_instance)


func _on_texture_button_3_pressed() -> void:
	get_tree().paused=false
	if (target_scene):
		get_tree().change_scene_to_packed(target_scene)
