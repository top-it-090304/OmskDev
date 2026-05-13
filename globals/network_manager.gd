extends Node

enum ConnectionState { DISCONNECTED, CONNECTING, CONNECTED, HOSTING }
var connection_state := ConnectionState.DISCONNECTED

const SERVER_ID = 1
var my_id: int = 0

## Кооп: забег завершён (кто-то умер) — без нового подключения не сбрасывается
var coop_run_finished: bool = false

## Сколько **гостей** может подключиться к хосту (ещё +1 сам хост в «комнате»).
const MAX_CLIENT_PEERS: int = 7
## HEX-код комнаты для лобби (хост задаёт из IP, гость — из ввода при входе).
var lobby_display_code: String = ""

const CONNECTION_TIMEOUT := 10.0
var connection_timer: Timer = null

signal connected_to_server
signal disconnected_from_server
signal connection_failed
signal player_connected(player_id)
signal player_disconnected(player_id)
signal game_started
## Клиент получил dungeon_state.dat от хоста и может вызывать load_dungeon_state()
signal dungeon_sync_received

func _ready() -> void:
	var mp := get_tree().get_multiplayer()
	mp.server_disconnected.connect(_on_disconnected)
	mp.connected_to_server.connect(_on_client_connected)
	mp.connection_failed.connect(_on_connection_failed)
	mp.peer_connected.connect(_on_peer_connected)
	mp.peer_disconnected.connect(_on_peer_disconnected)
	
	connection_timer = Timer.new()
	connection_timer.wait_time = CONNECTION_TIMEOUT
	connection_timer.one_shot = true
	connection_timer.timeout.connect(_on_connection_timeout)
	add_child(connection_timer)

func host_game(port: int = 4242) -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(port, MAX_CLIENT_PEERS) != OK:
		return
	get_tree().get_multiplayer().multiplayer_peer = peer
	connection_state = ConnectionState.HOSTING
	my_id = SERVER_ID
	reset_coop_run_state()
	_apply_network_rpc_authority()
	emit_signal("connected_to_server")

func join_game(address: String, port: int = 4242) -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(address, port) != OK:
		emit_signal("connection_failed")
		return
	get_tree().get_multiplayer().multiplayer_peer = peer
	connection_state = ConnectionState.CONNECTING
	reset_coop_run_state()
	connection_timer.start()
	_apply_network_rpc_authority()

func disconnect_game() -> void:
	get_tree().get_multiplayer().multiplayer_peer = null
	connection_state = ConnectionState.DISCONNECTED
	my_id = 0
	lobby_display_code = ""
	reset_coop_run_state()
	if not connection_timer.is_stopped():
		connection_timer.stop()


## RPC с mode "authority" может вызывать только peer с authority этой ноды — для автозагрузки всегда 1 (сервер)
func _apply_network_rpc_authority() -> void:
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer():
		set_multiplayer_authority(SERVER_ID)

func is_hosting() -> bool:
	return connection_state == ConnectionState.HOSTING

func is_multiplayer_active() -> bool:
	return connection_state != ConnectionState.DISCONNECTED

func is_server() -> bool:
	var mp := get_tree().get_multiplayer()
	return mp.has_multiplayer_peer() and mp.is_server()


func mark_coop_run_finished() -> void:
	coop_run_finished = true


func reset_coop_run_state() -> void:
	coop_run_finished = false

func is_client() -> bool:
	var mp := get_tree().get_multiplayer()
	return mp.has_multiplayer_peer() and not mp.is_server()

## После генерации/загрузки данжена на хосте — рассылаем клиентам тот же JSON, что в dungeon_state.dat
func host_publish_dungeon_state() -> void:
	if not is_hosting():
		return
	var data := SaveSystem.load_dungeon_data()
	if data.is_empty():
		push_warning("NetworkManager: dungeon data пустой, sync не отправлен")
		return
	rpc_receive_dungeon_state.rpc(data, GameConstants.CURRENT_FLOOR)


## Клиент (async): единая точка ожидания файла данжа — опрос кадрами + сигнал уже записанного состояния
func client_wait_dungeon_ready(max_wait_sec: float = 90.0) -> bool:
	var tree := get_tree()
	var deadline_ms := Time.get_ticks_msec() + int(max_wait_sec * 1000.0)
	while not SaveSystem.has_dungeon_state():
		if Time.get_ticks_msec() >= deadline_ms:
			return SaveSystem.has_dungeon_state()
		await tree.process_frame
	return true


@rpc("authority", "call_remote", "reliable")
func rpc_receive_dungeon_state(dungeon_data: Dictionary, current_floor: int) -> void:
	SaveSystem.save_dungeon_data(dungeon_data)
	GameConstants.CURRENT_FLOOR = current_floor
	dungeon_sync_received.emit()


## Клиент просит хост повторно выслать данж (гонка сцен / потерянный пакет)
@rpc("any_peer", "call_remote", "reliable")
func rpc_request_dungeon_resync() -> void:
	if not multiplayer.is_server():
		return
	host_publish_dungeon_state()


# --- Люк / следующий этаж в коопе: все пиры меняют сцену вместе ---
var _last_coop_floor_transition_ms: int = -9999999


@rpc("authority", "call_local", "reliable")
func rpc_coop_transition_next_floor() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_coop_floor_transition_ms < 2000:
		return
	_last_coop_floor_transition_ms = now
	SaveSystem.delete_dungeon_state()
	GameConstants.CURRENT_FLOOR += 1
	GameConstants.ROOMS_CLEARED = 0
	GameConstants.save_to_disk()
	get_tree().change_scene_to_file("res://World/layer.tscn")


@rpc("any_peer", "call_remote", "reliable")
func rpc_request_coop_next_floor() -> void:
	if not is_server():
		return
	rpc_coop_transition_next_floor.rpc()


func encode_ip(ip: String) -> String:
	var parts := ip.split(".")
	if parts.size() != 4: return ""
	var code := ""
	for part in parts:
		code += "%02X" % int(part)
	return code

func decode_code(code: String) -> String:
	var clean = code.strip_edges().to_upper()
	if clean.length() != 8: return ""
	var parts = []
	for i in range(4):
		parts.append(str(clean.substr(i * 2, 2).hex_to_int()))
	return ".".join(parts)

func _on_client_connected() -> void:
	my_id = get_tree().get_multiplayer().get_unique_id()
	connection_state = ConnectionState.CONNECTED
	reset_coop_run_state()
	_apply_network_rpc_authority()
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
	reset_coop_run_state()
	emit_signal("disconnected_from_server")

func _on_connection_failed() -> void:
	connection_state = ConnectionState.DISCONNECTED
	reset_coop_run_state()
	emit_signal("connection_failed")

func _on_peer_connected(id: int) -> void:
	emit_signal("player_connected", id)

func _on_peer_disconnected(id: int) -> void:
	emit_signal("player_disconnected", id)


# --- Артефакты в коопе (один экземпляр на этаж) ---

func _find_artefact_pickup_node(resource_path: String, room: Vector2i) -> Node:
	var mm := get_tree().get_first_node_in_group("map_manager")
	if mm == null:
		return null
	for room_data in mm.spawned_rooms:
		if room_data["grid_pos"] != room:
			continue
		var room_node: Node = room_data["node"]
		for c in room_node.get_children():
			if c.scene_file_path == resource_path and c.has_method("server_run_pickup_effects"):
				return c
	return null


@rpc("any_peer", "call_remote", "reliable")
func rpc_request_artefact_pickup_from_client(resource_path: String, room_x: int, room_y: int, picker_peer_id: int) -> void:
	if not is_server():
		return
	if multiplayer.get_remote_sender_id() != picker_peer_id:
		return
	var node := _find_artefact_pickup_node(resource_path, Vector2i(room_x, room_y))
	if node == null:
		return
	if node.has_method("server_consume_world_only_for_remote_client_pickup"):
		node.server_consume_world_only_for_remote_client_pickup()
	else:
		node.queue_free()
	rpc_client_mirror_artefact_pickup.rpc(resource_path, room_x, room_y, picker_peer_id)


@rpc("authority", "call_remote", "reliable")
func rpc_client_mirror_artefact_pickup(resource_path: String, room_x: int, room_y: int, picker_peer_id: int) -> void:
	if is_server():
		return
	var room := Vector2i(room_x, room_y)
	SaveSystem.mark_treasure_collected(room)
	var n := _find_artefact_pickup_node(resource_path, room)
	if n:
		n.queue_free()
	if multiplayer.get_unique_id() != picker_peer_id:
		return
	var res := load(resource_path)
	if res == null:
		return
	var pickup = res.instantiate()
	if pickup.has_method("apply_effects"):
		pickup.apply_effects()
	if pickup.has_method("add_to_backpack"):
		pickup.add_to_backpack()
	if pickup.has_method("show_stat_popup"):
		pickup.show_stat_popup()
	pickup.queue_free()


@rpc("authority", "call_local", "reliable")
func rpc_cleanup_cleared_room(grid_x: int, grid_y: int) -> void:
	var mm := get_tree().get_first_node_in_group("map_manager")
	if mm and mm.has_method("apply_room_cleared_for_network"):
		mm.apply_room_cleared_for_network(Vector2i(grid_x, grid_y))


@rpc("any_peer", "call_remote", "reliable")
func rpc_request_room_cleared(grid_x: int, grid_y: int) -> void:
	if not is_server():
		return
	rpc_cleanup_cleared_room.rpc(grid_x, grid_y)


@rpc("any_peer", "call_remote", "reliable")
func rpc_report_player_death() -> void:
	if not is_server():
		return
	var sid := multiplayer.get_remote_sender_id()
	if sid <= 0:
		return
	rpc_coop_game_over.rpc(sid)


@rpc("authority", "call_local", "reliable")
func rpc_coop_game_over(victim_peer_id: int) -> void:
	var mp := get_tree().get_multiplayer()
	if not mp.has_multiplayer_peer():
		return
	if coop_run_finished:
		return
	if mp.get_unique_id() == victim_peer_id:
		return
	mark_coop_run_finished()
	PlayerManager.show_coop_game_over_survivor()


@rpc("authority", "call_local", "reliable")
func rpc_sync_coop_room(grid_x: int, grid_y: int, entered_peer_id: int) -> void:
	var mm := get_tree().get_first_node_in_group("map_manager")
	if mm and mm.has_method("apply_coop_room_sync_all"):
		mm.apply_coop_room_sync_all(Vector2i(grid_x, grid_y), entered_peer_id)


@rpc("any_peer", "call_remote", "reliable")
func rpc_report_room_enter_to_server(grid_x: int, grid_y: int, entering_peer_id: int) -> void:
	if not is_server():
		return
	if entering_peer_id <= 0:
		return
	var mm := get_tree().get_first_node_in_group("map_manager")
	if mm and mm.has_method("server_handle_coop_room_enter"):
		mm.server_handle_coop_room_enter(Vector2i(grid_x, grid_y), entering_peer_id)
