extends Node

# Тестовый скрипт для проверки сетевой функциональности
# Можно разместить в любой сцене для тестирования

func _ready() -> void:
	# Ждем немного, чтобы все инициализировалось
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	
	# Выводим информацию о текущем состоянии сети
	print("=== Сетевая информация ===")
print("Мультиплеер инициализирован: %s" % (NetworkManager.net_multiplayer != null))

  if NetworkManager.net_multiplayer:
      print("Уникальный ID: %d" % NetworkManager.net_multiplayer.get_unique_id())
      print("Состояние подключения: %d" % NetworkManager.net_multiplayer.get_connection_status())
	
	print("Состояние NetworkManager: %d" % NetworkManager.connection_state)
	print("Мой ID в NetworkManager: %d" % NetworkManager.my_id)
	
	# Если мы не подключены, предлагаем начать хостинг для теста
	if NetworkManager.connection_state == NetworkManager.ConnectionState.DISCONNECTED:
		print("Не подключено. Начинаем хостинг для теста...")
		NetworkManager.host_game()
	elif NetworkManager.connection_state == NetworkManager.ConnectionState.HOSTING:
		print("Мы хостим игру. Ожидаем подключения клиентов...")
	elif NetworkManager.connection_state == NetworkManager.ConnectionState.CONNECTED:
	print("Мы подключены как клиент к серверу ID: %d" % NetworkManager.my_id)

func _on_NetworkManager_connected_to_server() -> void:
	print("Подключено к серверу!")

func _on_NetworkManager_disconnected_from_server() -> void:
	print("Отключено от сервера")

func _on_NetworkManager_player_connected(player_id) -> void:
	print("Игрок %d подключился" % player_id)

func _on_NetworkManager_player_disconnected(player_id) -> void:
	print("Игрок %d отключился" % player_id)