extends Control

# Для отладки: выводим ваш код в консоль при хосте
func _on_host_pressed() -> void:
	NetworkManager.host_game()
	
	# Пытаемся получить локальный IP для генерации кода
	var ip = IP.get_local_addresses()
	var my_ip = ""
	for a in ip:
		if a.count(".") == 3 and not a.begins_with("127"):
			my_ip = a
			break
	
	print("Ваш код комнаты: ", NetworkManager.encode_ip(my_ip))
	get_tree().change_scene_to_file("res://World/UI/lobby.tscn")

func _on_join_pressed() -> void:
	get_tree().change_scene_to_file("res://World/UI/join_room.tscn")

func _on_back_pressed() -> void:
	NetworkManager.disconnect_game()
	get_tree().change_scene_to_file("res://World/UI/menu.tscn")
