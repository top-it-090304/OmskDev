extends Control

func _on_host_pressed() -> void:
	NetworkManager.host_game()
	get_tree().change_scene_to_file("res://World/UI/lobby.tscn")

func _on_join_pressed() -> void:
	get_tree().change_scene_to_file("res://World/UI/join_room.tscn")

func _on_back_pressed() -> void:
	NetworkManager.disconnect_game()
	get_tree().change_scene_to_file("res://World/UI/menu.tscn")
