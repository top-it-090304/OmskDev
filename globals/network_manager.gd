extends Node

# Варианты подключения
enum ConnectionState { DISCONNECTED, CONNECTING, CONNECTED, HOSTING }
var connection_state = ConnectionState.DISCONNECTED
var net_multiplayer: MultiplayerAPI

# ID игрока
const SERVER_ID = 1
var my_id: int

# Сигналы
signal connected_to_server
signal disconnected_from_server
signal player_connected(player_id)
signal player_disconnected(player_id)

func _ready() -> void:
	net_multiplayer = get_tree().get_multiplayer()
	
	# Подключаем обработчики
	net_multiplayer.server_disconnected.connect(_on_disconnected)
	net_multiplayer.connected_to_server.connect(_on_connected)
	net_multiplayer.connection_failed.connect(_on_connection_failed)
	net_multiplayer.peer_connected.connect(_on_peer_connected)
	net_multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func host_game(port: int = 4242) -> void:
	var peer = ENetMultiplayerPeer.new()
	if peer.create_server(port) == OK:
		net_multiplayer.multiplayer_peer = peer
		connection_state = ConnectionState.HOSTING
		my_id = SERVER_ID
		print("Хостинг игры на порту %d" % port)
	else:
		push_error("Не удалось создать сервер")

func join_game(address: String, port: int = 4242) -> void:
	var peer = ENetMultiplayerPeer.new()
	if peer.create_client(address, port) == OK:
		net_multiplayer.multiplayer_peer = peer
		connection_state = ConnectionState.CONNECTING
		print("Подключение к %s:%d" % [address, port])
	else:
		push_error("Не удалось подключиться к серверу")

func _on_connected(id: int) -> void:
	my_id = id
	connection_state = ConnectionState.CONNECTED
	print("Подключено к серверу как клиент ID: %d" % id)
	emit_signal("connected_to_server")

func _on_disconnected() -> void:
	connection_state = ConnectionState.DISCONNECTED
	print("Отключено от сервера")
	emit_signal("disconnected_from_server")

func _on_connection_failed() -> void:
	connection_state = ConnectionState.DISCONNECTED
	push_error("Не удалось подключиться к серверу")

func _on_peer_connected(id: int) -> void:
	print("Игрок подключился: %d" % id)
	emit_signal("player_connected", id)

func _on_peer_disconnected(id: int) -> void:
	print("Игрок отключился: %d" % id)
	emit_signal("player_disconnected", id)
