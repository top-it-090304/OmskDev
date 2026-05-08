extends Control

# Ссылки на UI элементы (можно также получить через $, но для четкости оставляем)
# Мы будем получать узлы по пути в методах

func _ready() -> void:
	# Убедимся, что менеджер сети доступен
	if not NetworkManager:
		push_error("NetworkManager не загружен! Проверьте autoload.")
		return

func _on_host_pressed() -> void:
	# Начать хостинг игры
	NetworkManager.host_game()
	# Переключиться на сцену ожидания или сразу в игру
	# Для простоты, мы сразу переходим в основную сцену игры
	# Но лучше показать экран ожидания игроков
	get_tree().change_scene_to_file("res://World/layer.tscn")  # Или ваша основная сцена

func _on_join_pressed() -> void:
	# В реальной игре здесь должен быть диалог ввода IP и порта
	# Для демонстрации используем localhost
	var address = "127.0.0.1"  # Это можно заменить на input field
	var port = 4242
	NetworkManager.join_game(address, port)
	# После подключения переходим в игру
	get_tree().change_scene_to_file("res://World/layer.tscn")

func _on_back_pressed() -> void:
	# Возвращаемся в главное меню
	get_tree().change_scene_to_file("res://World/UI/menu.tscn")