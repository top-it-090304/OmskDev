extends Node

enum ConnectionState { DISCONNECTED, CONNECTING, CONNECTED, HOSTING }
var connection_state := ConnectionState.DISCONNECTED

const SERVER_ID = 1
var my_id: int = 0

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

func host_game(port: int = 4242) -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(port) != OK:
		push_error("Не удалось создать сервер на порту %d" % port)
		return
	get_tree().get_multiplayer().multiplayer_peer = peer
	connection_state = ConnectionState.HOSTING
	my_id = SERVER_ID
	emit_signal("connected_to_server")

func join_game(address: String, port: int = 4242) -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(address, port) != OK:
		push_error("Не удалось подключиться к %s:%d" % [address, port])
		emit_signal("connection_failed")
		return
	get_tree().get_multiplayer().multiplayer_peer = peer
	connection_state = ConnectionState.CONNECTING

func disconnect_game() -> void:
	get_tree().get_multiplayer().multiplayer_peer = null
	connection_state = ConnectionState.DISCONNECTED
	my_id = 0

func is_hosting() -> bool:
	return connection_state == ConnectionState.HOSTING

# Encode IP to 6-char code (e.g. 192.168.1.5 -> A3F7K2)
func encode_ip(ip: String) -> String:
	var parts := ip.split(".")
	if parts.size() != 4:
		return ""
	var code := ""
	for part in parts:
		var num := int(part)
		code += "%02X" % num  # Convert to hex (00-FF)
	return code.substr(0, 6)  # Take first 6 chars

# Decode 6-char code back to IP
func decode_code(code: String) -> String:
	if code.length() < 6:
		return ""
	var ip := ""
	for i in range(4):
		var hex := code.substr(i * 2, 2)
		var num := hex.hex_to_int()
		ip += str(num)
		if i < 3:
			ip += "."
	return ip

func _on_client_connected() -> void:
	my_id = get_tree().get_multiplayer().get_unique_id()
	connection_state = ConnectionState.CONNECTED
	emit_signal("connected_to_server")

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
