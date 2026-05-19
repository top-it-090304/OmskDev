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
const MAIN_MENU_SCENE := "res://World/UI/menu.tscn"
const PAUSED_SCENE := preload("res://World/UI/paused.tscn")
var connection_timer: Timer = null
var _returning_to_menu: bool = false
var _destroying_online_session: bool = false
var coop_pause_active: bool = false
var _coop_pause_menu: Node = null

signal connected_to_server
signal disconnected_from_server
signal connection_failed
signal player_connected(player_id)
signal player_disconnected(player_id)
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

func host_game(port: int = 4242) -> bool:
	_prepare_new_online_session()
	_returning_to_menu = false
	_destroying_online_session = false
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(port, MAX_CLIENT_PEERS) != OK:
		disconnect_game(false)
		emit_signal("connection_failed")
		return false
	get_tree().get_multiplayer().multiplayer_peer = peer
	connection_state = ConnectionState.HOSTING
	my_id = SERVER_ID
	reset_coop_run_state()
	_apply_network_rpc_authority()
	emit_signal("connected_to_server")
	return true

func join_game(address: String, port: int = 4242) -> bool:
	_prepare_new_online_session()
	_returning_to_menu = false
	_destroying_online_session = false
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(address, port) != OK:
		emit_signal("connection_failed")
		return false
	get_tree().get_multiplayer().multiplayer_peer = peer
	connection_state = ConnectionState.CONNECTING
	reset_coop_run_state()
	connection_timer.start()
	_apply_network_rpc_authority()
	return true


func _prepare_new_online_session() -> void:
	_force_close_coop_pause()
	if get_tree().get_multiplayer().has_multiplayer_peer() or connection_state != ConnectionState.DISCONNECTED:
		disconnect_game(false)
	else:
		_clear_online_runtime_state()
	lobby_display_code = ""
	reset_coop_run_state()
	SaveSystem.delete_dungeon_state()


func _clear_online_runtime_state() -> void:
	if PlayerManager != null and PlayerManager.has_method("reset_multiplayer_runtime_state"):
		PlayerManager.reset_multiplayer_runtime_state()

func disconnect_game(emit_disconnected_signal: bool = true) -> void:
	var mp := get_tree().get_multiplayer()
	var was_active := connection_state != ConnectionState.DISCONNECTED or mp.has_multiplayer_peer()
	_force_close_coop_pause()
	var old_peer := mp.multiplayer_peer
	if old_peer is ENetMultiplayerPeer:
		(old_peer as ENetMultiplayerPeer).close()
	mp.multiplayer_peer = null
	connection_state = ConnectionState.DISCONNECTED
	my_id = 0
	lobby_display_code = ""
	_destroying_online_session = false
	reset_coop_run_state()
	if not connection_timer.is_stopped():
		connection_timer.stop()
	_clear_online_runtime_state()
	if was_active and emit_disconnected_signal:
		emit_signal("disconnected_from_server")


## Хост завершил сессию — уведомить гостей и выйти в главное меню.
func host_leave_session_to_menu() -> void:
	destroy_online_session_to_menu()


## Любой выход из онлайна уничтожает комнату целиком. Так новый запуск не наследует старых peer/state.
func destroy_online_session_to_menu() -> void:
	if _destroying_online_session:
		return
	_destroying_online_session = true
	if is_game_online() and is_server():
		var peers := get_tree().get_multiplayer().get_peers()
		if not peers.is_empty():
			rpc_notify_session_ended.rpc()
	return_to_main_menu()


## Сброс флагов навигации (соло и кооп). Не использовать SceneTree.scene_changed — в 4.4 его нет.
func reset_menu_navigation_flags() -> void:
	_returning_to_menu = false
	_destroying_online_session = false


func reset_menu_transition_flags() -> void:
	reset_menu_navigation_flags()


## Главное меню: снять паузу, отключиться, сменить сцену.
func return_to_main_menu() -> void:
	_force_close_coop_pause()
	reset_menu_navigation_flags()
	var tree := get_tree()
	if tree == null:
		return
	tree.paused = false
	AudioManager.stop_music()
	disconnect_game(false)
	var current := tree.current_scene
	if current != null and current.scene_file_path == MAIN_MENU_SCENE:
		return
	tree.call_deferred("change_scene_to_file", MAIN_MENU_SCENE)


@rpc("authority", "call_remote", "reliable")
func rpc_notify_session_ended() -> void:
	_destroying_online_session = true
	return_to_main_menu()


## Кооп: пауза у всех, если один открыл меню паузы.
func open_coop_pause() -> void:
	if not is_game_online():
		_apply_coop_pause_local(true)
		return
	if coop_pause_active:
		return
	if is_server():
		rpc_sync_coop_pause.rpc(true)
	else:
		rpc_request_coop_pause.rpc_id(SERVER_ID)


func close_coop_pause() -> void:
	if not is_game_online():
		_apply_coop_pause_local(false)
		return
	if not coop_pause_active:
		return
	if is_server():
		rpc_sync_coop_pause.rpc(false)
	else:
		rpc_request_coop_unpause.rpc_id(SERVER_ID)


@rpc("any_peer", "call_remote", "reliable")
func rpc_request_coop_pause() -> void:
	if not is_server():
		return
	rpc_sync_coop_pause.rpc(true)


@rpc("any_peer", "call_remote", "reliable")
func rpc_request_coop_unpause() -> void:
	if not is_server():
		return
	rpc_sync_coop_pause.rpc(false)


@rpc("authority", "call_local", "reliable")
func rpc_sync_coop_pause(active: bool) -> void:
	_apply_coop_pause_local(active)


func _apply_coop_pause_local(active: bool) -> void:
	coop_pause_active = active
	var tree := get_tree()
	if tree != null:
		tree.paused = active
	if active:
		_open_pause_menu_local()
	else:
		_close_pause_menu_local()


func _open_pause_menu_local() -> void:
	if _coop_pause_menu != null and is_instance_valid(_coop_pause_menu):
		return
	var local_p := get_tree().get_first_node_in_group("local_player")
	if local_p == null:
		return
	_coop_pause_menu = PAUSED_SCENE.instantiate()
	local_p.add_child(_coop_pause_menu)


func _close_pause_menu_local() -> void:
	if _coop_pause_menu != null and is_instance_valid(_coop_pause_menu):
		_coop_pause_menu.queue_free()
	_coop_pause_menu = null


func _force_close_coop_pause() -> void:
	coop_pause_active = false
	var tree := get_tree()
	if tree != null:
		tree.paused = false
	_close_pause_menu_local()


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


## Поднят ENet (или иной) peer — сессия **онлайн**: RPC, хост/клиент, кооп.
func is_game_online() -> bool:
	return get_tree().get_multiplayer().has_multiplayer_peer()


## Нет peer — **офлайн / одиночка**: только локальные вызовы, без сетевой репликации.
func is_game_offline() -> bool:
	return not is_game_online()


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
	AudioManager.play_sfx("люк_переход")
	var player = get_tree().get_first_node_in_group("local_player")
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if player != null and "health_int" in player:
		SaveSystem.saved_player_health = int(player.health_int)
		SaveSystem.should_restore_player = true
	SaveSystem.set_boss_hatch_opened(false)
	GameConstants.CURRENT_FLOOR += 1
	GameConstants.ROOMS_CLEARED = 0
	SaveSystem.save_game()
	SaveSystem.delete_dungeon_state()
	GameConstants.save_to_disk()
	# Сразу после RPC/сигналов смена сцены даёт «Trying to assign invalid previously freed instance»
	# (Tween/экспорты/ссылки на старое дерево) — откладываем на следующий кадр.
	call_deferred("_deferred_coop_change_floor_scene")


func _deferred_coop_change_floor_scene() -> void:
	if not is_inside_tree():
		return
	_change_to_floor_scene(GameConstants.get_current_floor_scene_path())


## Если следующий этаж использует тот же .tscn, change_scene_to_file может не перезагрузить дерево.
func _change_to_floor_scene(path: String) -> void:
	var cs := get_tree().current_scene
	if cs != null and cs.scene_file_path == path:
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file(path)


@rpc("authority", "call_local", "reliable")
func rpc_coop_floor_spawn_positions(spawn_data: Dictionary) -> void:
	PlayerManager.apply_coop_floor_spawn_positions(spawn_data)


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
	var was_online_client := connection_state == ConnectionState.CONNECTED
	get_tree().get_multiplayer().multiplayer_peer = null
	connection_state = ConnectionState.DISCONNECTED
	my_id = 0
	lobby_display_code = ""
	_destroying_online_session = false
	reset_coop_run_state()
	if not connection_timer.is_stopped():
		connection_timer.stop()
	emit_signal("disconnected_from_server")
	# Хост вышел / оборвалось соединение — гость всегда выходит из лобби/данжа в меню.
	if was_online_client and not _returning_to_menu:
		call_deferred("return_to_main_menu")


func _is_in_dungeon_session() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	return tree.get_first_node_in_group("map_manager") != null

func _on_connection_failed() -> void:
	connection_state = ConnectionState.DISCONNECTED
	reset_coop_run_state()
	emit_signal("connection_failed")

func _on_peer_connected(id: int) -> void:
	emit_signal("player_connected", id)

func _on_peer_disconnected(id: int) -> void:
	emit_signal("player_disconnected", id)
	if is_server() and not _destroying_online_session:
		call_deferred("_destroy_session_after_peer_left")


func _destroy_session_after_peer_left() -> void:
	if not is_server() or _destroying_online_session:
		return
	destroy_online_session_to_menu()


# --- Артефакты в коопе (один экземпляр на этаж) ---

func _artefact_network_dict_from_pickup(pickup: Node) -> Dictionary:
	if not is_instance_valid(pickup):
		return {}
	var nm: String = str(pickup.get("artefact_name")) if pickup.get("artefact_name") != null else "?"
	var desc: String = str(pickup.get("artefact_description")) if pickup.get("artefact_description") != null else ""
	var icp := ""
	var ic: Variant = pickup.get("artefact_icon")
	if ic != null and ic is Texture2D:
		icp = (ic as Texture2D).resource_path
	return {"name": nm, "description": desc, "icon_path": icp}


func _resolve_node_by_path_for_damage(path_str: String) -> Node:
	var n := get_tree().root.get_node_or_null(NodePath(path_str))
	if n != null and is_instance_valid(n):
		return n
	var mm := get_tree().get_first_node_in_group("map_manager")
	if mm == null:
		return null
	var key := "MapManager/"
	var idx := path_str.find(key)
	if idx == -1:
		return null
	var rel := path_str.substr(idx + key.length())
	n = mm.get_node_or_null(NodePath(rel))
	if n != null and is_instance_valid(n):
		return n
	return null


func _find_artefact_by_network_id(artefact_id: String) -> Node:
	if artefact_id.is_empty():
		return null
	var tree := get_tree()
	if tree == null:
		return null
	for n in tree.get_nodes_in_group("artefact"):
		if not is_instance_valid(n) or not n.has_method("server_run_pickup_effects"):
			continue
		if str(n.get_meta(&"_net_world_artefact_id", "")) == artefact_id:
			return n
	return null


func _find_artefact_in_room(room: Vector2i, preferred_scene_path: String = "", artefact_id: String = "") -> Node:
	var by_id := _find_artefact_by_network_id(artefact_id)
	if by_id != null:
		return by_id
	var mm := get_tree().get_first_node_in_group("map_manager")
	if mm == null:
		return null
	var fallback: Node = null
	for room_data in mm.spawned_rooms:
		if room_data["grid_pos"] != room:
			continue
		var room_node: Node = room_data["node"]
		for c in room_node.get_children():
			if not is_instance_valid(c) or not c.has_method("server_run_pickup_effects"):
				continue
			if fallback == null:
				fallback = c
			if preferred_scene_path != "" and str(c.scene_file_path) == preferred_scene_path:
				return c
	return fallback


@rpc("any_peer", "call_remote", "reliable")
func rpc_request_artefact_pickup_from_client(resource_path: String, room_x: int, room_y: int, picker_peer_id: int, artefact_id: String = "") -> void:
	if not is_server():
		return
	if int(multiplayer.get_remote_sender_id()) != int(picker_peer_id):
		return
	var room := Vector2i(room_x, room_y)
	var node := _find_artefact_in_room(room, resource_path, artefact_id)
	if node == null:
		return
	var actual_path := str(node.scene_file_path)
	if node.has_method("server_consume_world_only_for_remote_client_pickup"):
		node.server_consume_world_only_for_remote_client_pickup()
	else:
		if is_instance_valid(node):
			node.queue_free()
	rpc_client_mirror_artefact_pickup.rpc(actual_path, room_x, room_y, picker_peer_id, artefact_id)


@rpc("authority", "call_remote", "reliable")
func rpc_client_mirror_artefact_pickup(resource_path: String, room_x: int, room_y: int, picker_peer_id: int, artefact_id: String = "") -> void:
	if is_server():
		return
	var room := Vector2i(room_x, room_y)
	if room.x >= 0 and room.y >= 0:
		SaveSystem.mark_treasure_collected(room)
	var n := _find_artefact_in_room(room, resource_path, artefact_id)
	if n != null and is_instance_valid(n):
		n.queue_free()
	var my_pid: int = int(multiplayer.get_unique_id())
	if my_pid != int(picker_peer_id):
		return
	# apply_effects/show_stat_popup и @onready у артефакта рассчитаны на узел в дереве
	call_deferred("_deferred_client_apply_artefact_pickup", resource_path)


func _deferred_client_apply_artefact_pickup(resource_path: String) -> void:
	_run_client_artefact_pickup_apply(resource_path)


func _run_client_artefact_pickup_apply(resource_path: String) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var res := load(resource_path) as PackedScene
	if res == null:
		return
	var root := tree.current_scene
	if root == null:
		return
	var pickup: Node = res.instantiate()
	pickup.process_mode = Node.PROCESS_MODE_DISABLED
	if pickup is Node2D:
		(pickup as Node2D).global_position = Vector2(-1e5, -1e5)
	pickup.visible = false
	root.add_child(pickup)
	await tree.process_frame
	if not is_instance_valid(pickup):
		return
	if pickup.has_method("apply_effects"):
		pickup.call("apply_effects")
	if pickup.has_method("show_stat_popup"):
		pickup.call("show_stat_popup")
	var info := _artefact_network_dict_from_pickup(pickup)
	if is_instance_valid(pickup):
		pickup.queue_free()
	var backpack: Node = tree.get_first_node_in_group("backpack")
	if backpack == null:
		backpack = root.find_child("Backpack", true, false)
	if backpack != null and backpack.has_method("add_artefact_from_network"):
		backpack.add_artefact_from_network(info)


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
	server_broadcast_coop_game_over(sid)


## Кооп: смерть любого — у союзника тот же game over (оба «проиграли»).
func server_broadcast_coop_game_over(victim_peer_id: int) -> void:
	if is_game_offline() or not is_server():
		return
	# На хосте нельзя одновременно call_local и call_remote в @rpc (Godot 4.4) — сначала локально выживший.
	_coop_apply_survivor_game_over(victim_peer_id)
	rpc_coop_game_over_to_clients.rpc(victim_peer_id)


@rpc("authority", "call_remote", "reliable")
func rpc_coop_game_over_to_clients(victim_peer_id: int) -> void:
	_coop_apply_survivor_game_over(victim_peer_id)


func _coop_apply_survivor_game_over(victim_peer_id: int) -> void:
	if is_game_offline():
		return
	var mp := get_tree().get_multiplayer()
	if mp.get_unique_id() == victim_peer_id:
		return
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p):
			continue
		if p.get("is_dead"):
			continue
		if not p.is_multiplayer_authority():
			continue
		if p.has_method("die_from_coop_partner_death"):
			p.die_from_coop_partner_death()


const _META_NET_ENEMY_VALID := &"net_enemy_sync_valid"
const _META_NET_ENEMY_POS := &"net_enemy_sync_pos"
const _META_NET_ENEMY_VEL := &"net_enemy_sync_vel"
const _META_NET_ENEMY_SPR := &"net_enemy_sync_spr"
const _META_NET_ENEMY_SPR_FRAME := &"net_enemy_sync_spr_frame"
const _META_NET_ENEMY_AP := &"net_enemy_sync_ap"
const _META_NET_ENEMY_AP_POS := &"net_enemy_sync_ap_pos"
const _META_NET_ENEMY_RECEIVED_MS := &"net_enemy_sync_received_ms"


func enemy_mp_is_network_client() -> bool:
	if is_game_offline():
		return false
	return not get_tree().get_multiplayer().is_server()


func get_enemy_sync_max_hp(enemy: Node, fallback_hp: int = 1) -> int:
	if enemy == null or not is_instance_valid(enemy):
		return maxi(fallback_hp, 1)
	var explicit_max = enemy.get("max_hp")
	if explicit_max != null:
		return maxi(int(explicit_max), 1)
	var bar := enemy.get_node_or_null("TextureProgressBar") as TextureProgressBar
	if bar != null and bar.max_value > 0.0:
		return maxi(int(round(bar.max_value)), 1)
	return maxi(fallback_hp, 1)


func enemy_client_interpolate_if_needed(enemy: CharacterBody2D, delta: float) -> bool:
	if not enemy_mp_is_network_client():
		return false
	if not is_instance_valid(enemy):
		return true
	if not _enemy_in_local_client_sync_region(enemy):
		enemy.velocity = Vector2.ZERO
		return true
	if not enemy.get_meta(_META_NET_ENEMY_VALID, false):
		enemy.velocity = Vector2.ZERO
		return true
	var tgt: Vector2 = enemy.get_meta(_META_NET_ENEMY_POS, enemy.global_position)
	var vel: Vector2 = enemy.get_meta(_META_NET_ENEMY_VEL, Vector2.ZERO)
	var received_ms := int(enemy.get_meta(_META_NET_ENEMY_RECEIVED_MS, Time.get_ticks_msec()))
	var age_sec := clampf(float(Time.get_ticks_msec() - received_ms) / 1000.0, 0.0, 0.12)
	var predicted_tgt := tgt + vel * age_sec
	# Только позиция с хоста: move_and_slide на клиенте упирался в стены и «ломал» синхрон.
	var dist_sq := enemy.global_position.distance_squared_to(predicted_tgt)
	if dist_sq > 40000.0:
		enemy.global_position = predicted_tgt
	else:
		enemy.global_position = enemy.global_position.lerp(predicted_tgt, minf(1.0, 72.0 * delta))
	enemy.velocity = vel
	_apply_net_enemy_visual_from_meta(enemy)
	return true


func _enemy_in_local_client_sync_region(enemy: Node) -> bool:
	var mm := get_tree().get_first_node_in_group("map_manager")
	if mm == null or not mm.has_method("room_in_local_enemy_net_sync_region"):
		return true
	if not enemy.has_meta(&"_spawn_room"):
		return true
	var room_grid: Vector2i = enemy.get_meta(&"_spawn_room")
	return mm.room_in_local_enemy_net_sync_region(room_grid)


func _apply_net_enemy_visual_from_meta(ch: Node) -> void:
	if not is_instance_valid(ch):
		return
	var spr: String = str(ch.get_meta(_META_NET_ENEMY_SPR, ""))
	var spr_frame: int = int(ch.get_meta(_META_NET_ENEMY_SPR_FRAME, -1))
	var ap: String = str(ch.get_meta(_META_NET_ENEMY_AP, ""))
	var ap_pos: float = float(ch.get_meta(_META_NET_ENEMY_AP_POS, -1.0))
	const _META_VIS_SIG := &"net_enemy_visual_sig"
	var sig := "%s|%d|%s|%.2f" % [spr, spr_frame, ap, ap_pos]
	if str(ch.get_meta(_META_VIS_SIG, "")) == sig:
		return
	ch.set_meta(_META_VIS_SIG, sig)
	var spr_node := ch.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if spr_node != null and spr_node.sprite_frames != null and spr != "":
		if spr_node.sprite_frames.has_animation(spr) and spr_node.animation != spr:
			spr_node.play(spr)
		if spr_frame >= 0 and spr_node.frame != spr_frame and abs(spr_node.frame - spr_frame) > 1:
			spr_node.frame = spr_frame
	var ap_node := ch.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap_node != null and ap != "":
		if ap_node.current_animation != ap or not ap_node.is_playing():
			ap_node.play(ap)
			if ap_pos >= 0.0:
				ap_node.seek(ap_pos, true)


@rpc("authority", "call_remote", "unreliable_ordered")
func rpc_sync_enemy_transform(path_str: String, pos: Vector2, vel: Vector2, spr_anim: String, ap_anim: String, enemy_key: String = "") -> void:
	var n := _resolve_enemy_for_sync(path_str, enemy_key)
	if n == null or not is_instance_valid(n) or not n is CharacterBody2D:
		return
	var ch := n as CharacterBody2D
	_apply_enemy_sync_state(ch, pos, vel, spr_anim, 0, ap_anim, -1.0, -1, -1, false)


@rpc("authority", "call_remote", "unreliable_ordered")
func rpc_sync_enemy_batch(states: Array) -> void:
	for raw in states:
		if not raw is Dictionary:
			continue
		var state := raw as Dictionary
		var n := _resolve_enemy_for_sync(str(state.get("path", "")), str(state.get("key", "")))
		if n == null or not is_instance_valid(n) or not n is CharacterBody2D:
			continue
		_apply_enemy_sync_state(
			n as CharacterBody2D,
			state.get("pos", (n as CharacterBody2D).global_position) as Vector2,
			state.get("vel", Vector2.ZERO) as Vector2,
			str(state.get("spr", "")),
			int(state.get("spr_frame", -1)),
			str(state.get("ap", "")),
			float(state.get("ap_pos", -1.0)),
			int(state.get("hp", -1)),
			int(state.get("max_hp", -1)),
			GameConstants.variant_to_bool(state.get("dead", false))
		)


func _apply_enemy_sync_state(
	ch: CharacterBody2D,
	pos: Vector2,
	vel: Vector2,
	spr_anim: String,
	spr_frame: int,
	ap_anim: String,
	ap_pos: float,
	hp_val: int,
	max_hp_val: int,
	dead: bool
) -> void:
	ch.set_meta(_META_NET_ENEMY_VALID, true)
	ch.set_meta(_META_NET_ENEMY_POS, pos)
	ch.set_meta(_META_NET_ENEMY_VEL, vel)
	ch.set_meta(_META_NET_ENEMY_SPR, spr_anim)
	ch.set_meta(_META_NET_ENEMY_SPR_FRAME, spr_frame)
	ch.set_meta(_META_NET_ENEMY_AP, ap_anim)
	ch.set_meta(_META_NET_ENEMY_AP_POS, ap_pos)
	ch.set_meta(_META_NET_ENEMY_RECEIVED_MS, Time.get_ticks_msec())
	if hp_val >= 0:
		if ch.get("hp") != null:
			ch.set("hp", hp_val)
		var bar := ch.get_node_or_null("TextureProgressBar")
		if bar and bar.has_method("update_hp"):
			bar.call("update_hp", hp_val, max_hp_val)
	if dead:
		_apply_synced_enemy_death(ch)


func _resolve_enemy_for_sync(path_str: String, enemy_key: String = "") -> Node:
	if not enemy_key.is_empty():
		var mm := get_tree().get_first_node_in_group("map_manager")
		if mm != null and mm.has_method("get_enemy_by_net_key"):
			var by_key: Node = mm.get_enemy_by_net_key(enemy_key)
			if by_key != null and is_instance_valid(by_key):
				return by_key
	return _resolve_node_by_path_for_damage(path_str)


func server_apply_damage_to_player_from_enemy(player: Node, amount: int) -> void:
	if not is_instance_valid(player) or not player.is_in_group("player"):
		return
	if not player.has_method("apply_damage_direct") and not player.has_method("take_damage"):
		return
	if is_game_offline():
		if player.has_method("apply_damage_direct"):
			player.call("apply_damage_direct", amount)
		else:
			player.call("take_damage", amount)
		return
	var mp := get_tree().get_multiplayer()
	if mp.is_server():
		_online_server_apply_damage_to_player(player, amount)
	elif player.is_multiplayer_authority():
		rpc_request_player_damage_from_enemy.rpc_id(SERVER_ID, amount)


@rpc("any_peer", "call_remote", "reliable")
func rpc_request_player_damage_from_enemy(amount: int) -> void:
	if not is_server():
		return
	var sender := int(multiplayer.get_remote_sender_id())
	if sender <= 0:
		return
	var player := PlayerManager.get_player_by_peer_id(sender)
	if player == null or not is_instance_valid(player):
		return
	_online_server_apply_damage_to_player(player, amount)


## Онлайн: хост применяет урон на своей симуляции и уведомляет владельца персонажа.
func _online_server_apply_damage_to_player(player: Node, amount: int) -> void:
	var mp := get_tree().get_multiplayer()
	if not mp.is_server():
		return
	var resolved := amount
	if player.has_method("resolve_incoming_damage"):
		resolved = int(player.call("resolve_incoming_damage", amount))
	elif player.has_method("take_damage"):
		player.call("take_damage", amount)
		return
	if resolved <= 0:
		return
	if player.has_method("apply_damage_direct"):
		player.call("apply_damage_direct", resolved, true)
	else:
		player.call("take_damage", resolved)
		return
	var auth := int(player.get_multiplayer_authority())
	if auth != int(mp.get_unique_id()):
		if player.has_method("rpc_take_damage_from_server"):
			player.rpc_take_damage_from_server.rpc_id(auth, resolved)
	elif not mp.get_peers().is_empty():
		_sync_player_health_to_clients(player)


func get_player_sync_max_hp(player: Node, fallback_hp: int = 1) -> int:
	if player == null or not is_instance_valid(player):
		return maxi(fallback_hp, 1)
	if player.has_method("_get_max_health"):
		return maxi(int(player.call("_get_max_health")), 1)
	var explicit_max = player.get("max_hp")
	if explicit_max != null:
		return maxi(int(explicit_max), 1)
	if player.get("last_known_max_health") != null:
		return maxi(int(player.last_known_max_health), 1)
	return maxi(fallback_hp, 1)


func _sync_player_health_to_clients(player: Node) -> void:
	if not is_instance_valid(player) or player.get("health_int") == null:
		return
	var mp := get_tree().get_multiplayer()
	if mp.get_peers().is_empty():
		return
	var hp := maxi(0, int(player.health_int))
	var max_hp := get_player_sync_max_hp(player, hp)
	rpc_apply_player_health.rpc(int(player.get_multiplayer_authority()), hp, max_hp)


@rpc("authority", "call_remote", "reliable")
func rpc_apply_player_health(peer_id: int, hp: int, max_hp: int) -> void:
	if is_server():
		return
	var player := PlayerManager.get_player_by_peer_id(peer_id)
	if player == null or not is_instance_valid(player):
		return
	if player.get("health_int") == null:
		return
	player.set("health_int", hp)


func server_apply_poison_to_player_from_enemy(player: Node, duration: float, damage_per_tick: int, tick_rate: float) -> void:
	if not is_instance_valid(player) or not player.is_in_group("player"):
		return
	if not player.has_method("apply_poison"):
		return
	if is_game_offline():
		player.call("apply_poison", duration, damage_per_tick, tick_rate)
		return
	_online_server_apply_poison_to_player(player, duration, damage_per_tick, tick_rate)


func _online_server_apply_poison_to_player(player: Node, duration: float, damage_per_tick: int, tick_rate: float) -> void:
	var mp := get_tree().get_multiplayer()
	if not mp.is_server():
		return
	var auth := player.get_multiplayer_authority()
	if auth == mp.get_unique_id():
		player.call("apply_poison", duration, damage_per_tick, tick_rate)
	elif player.has_method("rpc_apply_poison_from_server"):
		player.rpc_apply_poison_from_server.rpc_id(auth, duration, damage_per_tick, tick_rate)


func server_apply_knockback_to_player_from_enemy(player: Node, source_world: Vector2, force: float) -> void:
	if not is_instance_valid(player) or not player.is_in_group("player"):
		return
	if not player.has_method("apply_knockback"):
		return
	if is_game_offline():
		player.call("apply_knockback", source_world, force)
		return
	_online_server_apply_knockback_to_player(player, source_world, force)


func _online_server_apply_knockback_to_player(player: Node, source_world: Vector2, force: float) -> void:
	var mp := get_tree().get_multiplayer()
	if not mp.is_server():
		return
	var auth := player.get_multiplayer_authority()
	if auth == mp.get_unique_id():
		player.call("apply_knockback", source_world, force)
	elif player.has_method("rpc_apply_knockback_from_server"):
		player.rpc_apply_knockback_from_server.rpc_id(auth, source_world.x, source_world.y, force)


@rpc("authority", "call_remote", "unreliable")
func rpc_mirror_host_projectile(scene_path: String, global_pos: Vector2, direction: Vector2) -> void:
	var ps := load(scene_path) as PackedScene
	if ps == null:
		return
	var inst: Node = ps.instantiate()
	get_tree().current_scene.add_child(inst)
	if inst is Node2D:
		(inst as Node2D).global_position = global_pos
	if "direction" in inst:
		inst.direction = direction.normalized()
	if inst is Area2D:
		(inst as Area2D).monitoring = false
		(inst as Area2D).monitorable = false


func host_mirror_projectile_if_coop(scene_path: String, global_pos: Vector2, direction: Vector2) -> void:
	if is_game_offline():
		return
	var mp := get_tree().get_multiplayer()
	if mp.is_server() and mp.get_peers().size() > 0:
		rpc_mirror_host_projectile.rpc(scene_path, global_pos, direction)


## Урон по врагу от атаки игрока: офлайн — только локально; онлайн — хост + реплика или RPC с клиента.
func apply_melee_damage_to_enemy_from_player(enemy: Node, amount: int) -> void:
	if not is_instance_valid(enemy):
		return
	if is_game_offline():
		_offline_apply_melee_damage_to_enemy(enemy, amount)
		return
	_online_apply_melee_damage_to_enemy(enemy, amount)


func _offline_apply_melee_damage_to_enemy(enemy: Node, amount: int) -> void:
	if enemy.has_method("take_damage"):
		enemy.call("take_damage", amount)


func _online_apply_melee_damage_to_enemy(enemy: Node, amount: int) -> void:
	var mp := get_tree().get_multiplayer()
	if mp.is_server():
		if enemy.has_method("take_damage"):
			enemy.call("take_damage", amount)
		_replicate_enemy_state_after_damage(enemy)
	else:
		rpc_request_enemy_damage.rpc_id(SERVER_ID, str(enemy.get_path()), amount)


func _replicate_enemy_state_after_damage(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return
	if is_game_offline():
		return
	var mp := get_tree().get_multiplayer()
	if not mp.is_server():
		return
	if mp.get_peers().size() == 0:
		return
	var h: int = int(enemy.get("hp")) if enemy.get("hp") != null else 0
	var d: bool = GameConstants.variant_to_bool(enemy.get("is_dead"))
	var mx: int = get_enemy_sync_max_hp(enemy, h)
	var enemy_key := str(enemy.get_meta(&"_net_enemy_key", ""))
	rpc_sync_enemy_after_damage.rpc(str(enemy.get_path()), maxi(0, h), mx, d, enemy_key)


@rpc("authority", "call_remote", "reliable")
func rpc_sync_enemy_after_damage(path_str: String, hp_val: int, max_hp_val: int, dead: bool, enemy_key: String = "") -> void:
	var n := _resolve_enemy_for_sync(path_str, enemy_key)
	if n == null or not is_instance_valid(n):
		return
	if n.get("hp") != null:
		n.hp = hp_val
	var bar := n.get_node_or_null("TextureProgressBar")
	if bar and bar.has_method("update_hp"):
		bar.call("update_hp", hp_val, max_hp_val)
	if dead:
		_apply_synced_enemy_death(n)


func _apply_synced_enemy_death(n: Node) -> void:
	if n.get("is_dead") != null:
		n.set("is_dead", true)
	# Боссов не удаляем здесь: на хосте должна отработать полная death() (люк, дроп). Клиент только скрывает копию.
	if n.is_in_group("boss"):
		n.visible = false
		n.process_mode = Node.PROCESS_MODE_DISABLED
		if n is CollisionObject2D:
			(n as CollisionObject2D).set_collision_layer_value(1, false)
			(n as CollisionObject2D).set_collision_mask_value(1, false)
	else:
		if is_instance_valid(n):
			n.queue_free()


## Клиенты: тот же артефакт под люком, что заспавнил хост (сцена не синхронится сама по сети).
@rpc("authority", "call_remote", "reliable")
func rpc_spawn_boss_loot_at(scene_res_path: String, parent_node_path: String, global_pos: Vector2, artefact_id: String = "", room_x: int = -1, room_y: int = -1) -> void:
	var parent := get_tree().root.get_node_or_null(NodePath(parent_node_path)) as Node2D
	if parent == null or not is_instance_valid(parent):
		return
	var ps := load(scene_res_path) as PackedScene
	if ps == null:
		return
	var item := ps.instantiate() as Node2D
	item.z_index = 2
	item.global_position = global_pos
	_stamp_spawned_artefact(item, artefact_id, Vector2i(room_x, room_y))
	parent.add_child(item)
	item.add_to_group("artefact")


func _room_grid_from_artefact_parent(parent: Node2D) -> Vector2i:
	if parent == null:
		return Vector2i(-1, -1)
	var gx = parent.get("grid_x")
	var gy = parent.get("grid_y")
	if gx == null or gy == null:
		return Vector2i(-1, -1)
	return Vector2i(int(gx), int(gy))


func _stamp_spawned_artefact(item: Node, artefact_id: String, room: Vector2i) -> void:
	if item == null:
		return
	if not artefact_id.is_empty():
		item.set_meta(&"_net_world_artefact_id", artefact_id)
	if room.x >= 0 and room.y >= 0:
		item.set_meta("_treasure_room_grid", room)


func server_spawn_boss_loot_for_coop(scene_res_path: String, parent: Node2D, global_pos: Vector2) -> void:
	var inst := (load(scene_res_path) as PackedScene).instantiate() as Node2D
	var room := _room_grid_from_artefact_parent(parent)
	var artefact_id := "%s|%d|%d|%.1f|%.1f" % [scene_res_path, room.x, room.y, global_pos.x, global_pos.y]
	inst.z_index = 2
	inst.global_position = global_pos
	_stamp_spawned_artefact(inst, artefact_id, room)
	parent.add_child(inst)
	inst.add_to_group("artefact")
	if is_game_offline():
		return
	var mp := get_tree().get_multiplayer()
	if mp.is_server() and mp.get_peers().size() > 0:
		rpc_spawn_boss_loot_at.rpc(scene_res_path, str(parent.get_path()), global_pos, artefact_id, room.x, room.y)


@rpc("any_peer", "call_remote", "reliable")
func rpc_request_enemy_damage(enemy_path_str: String, amount: int) -> void:
	if not is_server():
		return
	var n := _resolve_node_by_path_for_damage(enemy_path_str)
	if n == null or not is_instance_valid(n):
		return
	if not n.is_in_group("enemys"):
		return
	if n.has_method("take_damage"):
		n.call("take_damage", amount)
	_replicate_enemy_state_after_damage(n)


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


## Общий прогресс/статы GameConstants после левелапа (одна «экономика» на всех в коопе).
@rpc("authority", "call_local", "reliable")
func rpc_replicate_player_stats(state: Dictionary) -> void:
	GameConstants.apply_coop_shared_state(state)


@rpc("any_peer", "call_remote", "reliable")
func rpc_submit_progress_after_level_up(state: Dictionary) -> void:
	if not is_server():
		return
	var target_level: int = int(state.get("PLAYER_LEVEL", GameConstants.PLAYER_LEVEL))
	var target_exp: int = int(state.get("PLAYER_EXPERIENCE", GameConstants.PLAYER_EXPERIENCE))
	GameConstants.catch_up_coop_levels_to(target_level)
	GameConstants.PLAYER_EXPERIENCE = target_exp
	rpc_replicate_player_stats.rpc(GameConstants.capture_coop_shared_state())


## Люк босса: сначала локально открываем на машине, где умер босс; затем синхронизируем остальных.
@rpc("any_peer", "call_remote", "reliable")
func rpc_request_server_boss_hatch_open() -> void:
	if not is_server():
		return
	var mm := get_tree().get_first_node_in_group("map_manager")
	if mm and mm.has_method("apply_boss_hatch_opened_visual"):
		mm.apply_boss_hatch_opened_visual()
	rpc_boss_hatch_open_to_peers.rpc()


@rpc("authority", "call_remote", "reliable")
func rpc_boss_hatch_open_to_peers() -> void:
	var mm := get_tree().get_first_node_in_group("map_manager")
	if mm and mm.has_method("apply_boss_hatch_opened_visual"):
		mm.apply_boss_hatch_opened_visual()
