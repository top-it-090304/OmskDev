extends TextureButton

func _on_pressed() -> void:
	var inventory = get_tree().get_first_node_in_group("inventory_screen")
	if inventory:
		inventory.toggle()
