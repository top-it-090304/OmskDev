extends TextureButton
@export var scene_to_open: PackedScene

func _on_pressed() -> void:
	var new_scene_instance = scene_to_open.instantiate()
	get_parent().add_child(new_scene_instance) # Replace with function body.
	
	


func _on_player_child_exiting_tree(node: Node) -> void:
	if(get_parent().new_scene_instance==null):
		disabled=false
		visible=true 
