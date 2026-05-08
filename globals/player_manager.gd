extends Node

# Хранилище игроков по их сетевому ID
var players: Dictionary = {}

# Сцена игрока для инстанцирования
@export var player_scene: PackedScene

# ID локального игрока (устанавливается при подключении)
var my_id: int

# Сигналы
signal player_connected(player_id, player_node)
signal player_disconnected(player_id)

func _ready() -> void:
	# Предзагружаем сцену игрока, если не установлена через экспорт
	if not player_scene:
		player_scene = preload("res://scene/game_objects/player/player.tscn")
	
	# Подписываемся на сигналы NetworkManager
	if NetworkManager:
		NetworkManager.player_connected.connect(_on_player_connected)
		NetworkManager.player_disconnected.connect(_on_player_disconnected)
		NetworkManager.connected_to_server.connect(_on_connected)
		NetworkManager.disconnected_from_server.connect(_on_disconnected)
	else:
		push_error("NetworkManager не найден в автозагрузке!")

func _on_player_connected(player_id: int) -> void:
	print("Игрок подключился: %d" % player_id)
	_spawn_player(player_id)

func _on_player_disconnected(player_id: int) -> void:
	print("Игрок отключился: %d" % player_id)
	_despawn_player(player_id)

func _on_connected() -> void:
	my_id = NetworkManager.net_multiplayer.get_unique_id()
	print("Мы подключены как игрок ID: %d" % my_id)
	# Если мы хостим, то мы уже создали своего игрока в _ready через групповое добавление?
	# Нет, мы создаем всех игроков через этот менеджер.
	# Поэтому создаем своего игрока тоже здесь.
	_spawn_player(my_id)

func _on_disconnected() -> void:
	my_id = -1
	# Удаляем всех игроков
	for player_id in players.keys():
		_despawn_player(player_id)
	players.clear()

func _spawn_player(player_id: int) -> void:
	if players.has(player_id):
		print("Игрок %d уже существует" % player_id)
		return
	
	var player_instance = player_scene.instantiate()
	# Устанавливаем уникальное имя, чтобы избежать конфликтов
	player_instance.name = "Player_%d" % player_id
	
	# Устанавливаем сетевую авторизацию
	player_instance.set_multiplayer_authority(player_id)
	
	# Добавляем в сцену (предполагаем, что текущая сцена - игровой мир)
	var game_world = get_tree().current_scene
	if game_world:
		game_world.add_child(player_instance)
	else:
		push_error("Не удалось найти текущую сцену для добавления игрока")
		return
	
	# Сохраняем ссылку
	players[player_id] = player_instance
	
	# Если это наш игрок, отмечаем его как локального
	if player_id == my_id:
		player_instance.is_local_player = true
		# Также можем установить камеру на этого игрока, если нужно
		# Например: get_viewport().camera_2d = player_instance.$Camera2D
	
	# Излучаем сигнал
	emit_signal("player_connected", player_id, player_instance)

func _despawn_player(player_id: int) -> void:
	if not players.has(player_id):
		print("Игрок %d не найден для удаления" % player_id)
		return
	
	var player_instance = players[player_id]
	player_instance.queue_free()
	players.erase(player_id)
	
	# Если это был наш игрок, сбрасываем my_id
	if player_id == my_id:
		my_id = -1
	
	emit_signal("player_disconnected", player_id)

# Получить игрока по ID
func get_player(player_id: int) -> Node:
	return players.get(player_id, null)

# Проверить, является ли игрок локальным
func is_local_player(player_id: int) -> bool:
	return player_id == my_id
