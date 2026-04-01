extends TextureButton
@export var scene_to_open: PackedScene

func _on_pressed() -> void:
	var new_scene_instance = scene_to_open.instantiate()
	get_parent().add_child(new_scene_instance) # Replace with function body.
	disabled=true
	visible=false 
	


func _on_player_child_exiting_tree(node: Node) -> void:
	
	disabled=false
	visible=true 
	
