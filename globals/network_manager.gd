extends Node

enum ConnectionState { DISCONNECTED, CONNECTING, CONNECTED, HOSTING }
var connection_state := ConnectionState.DISCONNECTED

const SERVER_ID = 1
var my_id: int = 0

# Тайм-аут подключения в секундах
const CONNECTION_TIMEOUT := 10.0
var connection_timer: Timer = null

signal connected_to_server
signal disconnected_from_server
signal connection_failed
signal player_connected(player_id)
signal player_disconnected(player_id)
signal game_started

func _ready() -> void:
	var mp := get_tree().get_multiplayer()
	mp.server_disconnected.connect(_on_disconnected)
	mp.connected_to_server.connect(_on_client_connected)
	mp.connection_failed.connect(_on_connection_failed)
	mp.peer_connected.connect(_on_peer_connected)
	mp.peer_disconnected.connect(_on_peer_disconnected)
	
	# Инициализация таймера
	connection_timer = Timer.new()
	connection_timer.wait_time = CONNECTION_TIMEOUT
	connection_timer.one_shot = true
	connection_timer.timeout.connect(_on_connection_timeout)
	add_child(connection_timer)

func host_game(port: int = 4242) -> void:
	var peer := ENetMultiplayerPeer.new()
	var error = peer.create_server(port)
	if error != OK:
		push_error("Не удалось создать сервер: %d" % error)
		return
		
	get_tree().get_multiplayer().multiplayer_peer = peer
	connection_state = ConnectionState.HOSTING
	my_id = SERVER_ID
	emit_signal("connected_to_server")

func join_game(address: String, port: int = 4242) -> void:
	var peer := ENetMultiplayerPeer.new()
	var error = peer.create_client(address, port)
	if error != OK:
		push_error("Ошибка создания клиента: %d" % error)
		emit_signal("connection_failed")
		return
		
	get_tree().get_multiplayer().multiplayer_peer = peer
	connection_state = ConnectionState.CONNECTING
	connection_timer.start()

func disconnect_game() -> void:
	get_tree().get_multiplayer().multiplayer_peer = null
	connection_state = ConnectionState.DISCONNECTED
	my_id = 0
	if not connection_timer.is_stopped():
		connection_timer.stop()

func is_hosting() -> bool:
	return connection_state == ConnectionState.HOSTING

# Кодирование IP (192.168.1.1 -> C0A80101) - всегда 8 символов
func encode_ip(ip: String) -> String:
	var parts := ip.split(".")
	if parts.size() != 4:
		return ""
	var code := ""
	for part in parts:
		code += "%02X" % int(part)
	return code

# Декодирование (C0A80101 -> 192.168.1.1)
func decode_code(code: String) -> String:
	if code.length() != 8:
		return ""
	var ip_parts = []
	for i in range(4):
		var hex_part = code.substr(i * 2, 2)
		ip_parts.append(str(hex_part.hex_to_int()))
	return ".".join(ip_parts)

func _on_client_connected() -> void:
	my_id = get_tree().get_multiplayer().get_unique_id()
	connection_state = ConnectionState.CONNECTED
	if not connection_timer.is_stopped():
		connection_timer.stop()
	emit_signal("connected_to_server")

func _on_connection_timeout() -> void:
	if connection_state == ConnectionState.CONNECTING:
		disconnect_game()
		emit_signal("connection_failed")

func _on_disconnected() -> void:
	connection_state = ConnectionState.DISCONNECTED
	my_id = 0
	emit_signal("disconnected_from_server")

func _on_connection_failed() -> void:
	connection_state = ConnectionState.DISCONNECTED
	emit_signal("connection_failed")

func _on_peer_connected(id: int) -> void:
	emit_signal("player_connected", id)

func _on_peer_disconnected(id: int) -> void:
	emit_signal("player_disconnected", id)
