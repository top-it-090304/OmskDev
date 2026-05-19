extends Control


func _ready() -> void:
	NetworkManager.reset_menu_navigation_flags()
	for button in [
		$Panel/VBoxContainer/HostButton,
		$Panel/VBoxContainer/JoinButton,
		$Panel/VBoxContainer/BackButton,
	]:
		_ignore_button_label_mouse(button)


func _ignore_button_label_mouse(button: Control) -> void:
	if button == null:
		return
	for child in button.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


# Для отладки: выводим ваш код в консоль при хосте
func _on_host_pressed() -> void:
	if not NetworkManager.host_game():
		push_warning("Не удалось создать онлайн-комнату")
		return
	
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
	NetworkManager.disconnect_game(false)
	NetworkManager.reset_menu_navigation_flags()
	get_tree().change_scene_to_file("res://World/UI/menu.tscn")
