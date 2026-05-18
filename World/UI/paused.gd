extends Control
@export var scene_to_open: PackedScene  # Перетащите сцену в инспекторе
@export var target_scene = "res://World/UI/menu.tscn"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if NetworkManager.is_game_offline():
		get_tree().paused = true

func _on_texture_button_pressed() -> void:
	# Продолжить игру
	if NetworkManager.is_game_online():
		NetworkManager.close_coop_pause()
	else:
		get_tree().paused = false
		queue_free()

func _on_texture_button_2_pressed() -> void:
	# Настройки
	var new_scene_instance = scene_to_open.instantiate()
	add_child(new_scene_instance)

func _on_texture_button_3_pressed() -> void:
	# Выход в главное меню
	print("=== ВЫХОД В ГЛАВНОЕ МЕНЮ ===")

	# ПРОВЕРКА: если игрок в незачищенной комнате — телепортируем в безопасную зону
	var map_manager = get_tree().get_first_node_in_group("map_manager")
	if map_manager and map_manager.has_method("teleport_player_to_safe_room"):
		# Проверяем текущую комнату на наличие врагов
		var current_pos = map_manager.current_room_grid_pos
		for room_data in map_manager.spawned_rooms:
			if room_data["grid_pos"] == current_pos:
				var room_node = room_data["node"]
				var enemys_node = room_node.find_child("Enemys")
				if enemys_node and enemys_node.get_child_count() > 0:
					print("Комната не зачищена! Принудительный телепорт в стартовую комнату.")
					map_manager.teleport_player_to_safe_room()
					break

	# Сохраняем игру перед выходом
	SaveSystem.save_game()

	# Сохраняем состояние данжена
	if map_manager and map_manager.has_method("save_dungeon_state"):
		map_manager.save_dungeon_state()

	# Сохраняем текущую позицию и комнату игрока
	var player = get_tree().get_first_node_in_group("player")
	if player and "global_position" in player:
		SaveSystem.saved_player_position = player.global_position

	if NetworkManager.is_game_online() and NetworkManager.is_server():
		NetworkManager.host_leave_session_to_menu()
	else:
		NetworkManager.return_to_main_menu()
