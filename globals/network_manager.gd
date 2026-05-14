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
	SaveSystem.set_boss_hatch_opened(false)
	SaveSystem.save_game()
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
	if int(multiplayer.get_remote_sender_id()) != int(picker_peer_id):
		return
	var node := _find_artefact_pickup_node(resource_path, Vector2i(room_x, room_y))
	if node == null:
		return
	if node.has_method("server_consume_world_only_for_remote_client_pickup"):
		node.server_consume_world_only_for_remote_client_pickup()
	else:
		if is_instance_valid(node):
			node.queue_free()
	rpc_client_mirror_artefact_pickup.rpc(resource_path, room_x, room_y, picker_peer_id)


@rpc("authority", "call_remote", "reliable")
func rpc_client_mirror_artefact_pickup(resource_path: String, room_x: int, room_y: int, picker_peer_id: int) -> void:
	if is_server():
		return
	var room := Vector2i(room_x, room_y)
	SaveSystem.mark_treasure_collected(room)
	var n := _find_artefact_pickup_node(resource_path, room)
	if n != null and is_instance_valid(n):
		n.queue_free()
	var my_pid: int = int(multiplayer.get_unique_id())
	if my_pid != int(picker_peer_id):
		return
	var res := load(resource_path)
	if res == null:
		return
	var pickup = res.instantiate()
	if pickup.has_method("apply_effects"):
		pickup.apply_effects()
	if pickup.has_method("show_stat_popup"):
		pickup.show_stat_popup()
	var info := _artefact_network_dict_from_pickup(pickup)
	if is_instance_valid(pickup):
		pickup.queue_free()
	var tree := get_tree()
	if tree == null:
		return
	var backpack: Node = tree.get_first_node_in_group("backpack")
	if backpack == null and tree.current_scene != null:
		backpack = tree.current_scene.find_child("Backpack", true, false)
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


func enemy_mp_is_network_client() -> bool:
	if is_game_offline():
		return false
	return not get_tree().get_multiplayer().is_server()


func enemy_client_interpolate_if_needed(enemy: CharacterBody2D, delta: float) -> bool:
	if not enemy_mp_is_network_client():
		return false
	if not is_instance_valid(enemy):
		return true
	if not enemy.get_meta(_META_NET_ENEMY_VALID, false):
		enemy.velocity = Vector2.ZERO
		enemy.move_and_slide()
		return true
	var tgt: Vector2 = enemy.get_meta(_META_NET_ENEMY_POS, enemy.global_position)
	var vel: Vector2 = enemy.get_meta(_META_NET_ENEMY_VEL, Vector2.ZERO)
	enemy.global_position = enemy.global_position.lerp(tgt, minf(1.0, 22.0 * delta))
	enemy.velocity = vel
	enemy.move_and_slide()
	return true


@rpc("authority", "call_remote", "unreliable")
func rpc_sync_enemy_transform(path_str: String, pos: Vector2, vel: Vector2) -> void:
	var n := get_tree().root.get_node_or_null(NodePath(path_str))
	if n == null or not is_instance_valid(n) or not n is CharacterBody2D:
		return
	var ch := n as CharacterBody2D
	ch.set_meta(_META_NET_ENEMY_VALID, true)
	ch.set_meta(_META_NET_ENEMY_POS, pos)
	ch.set_meta(_META_NET_ENEMY_VEL, vel)


func server_apply_damage_to_player_from_enemy(player: Node, amount: int) -> void:
	if not is_instance_valid(player) or not player.is_in_group("player"):
		return
	if not player.has_method("take_damage"):
		return
	if is_game_offline():
		player.call("take_damage", amount)
		return
	_online_server_apply_damage_to_player(player, amount)


## Онлайн: только хост решает урон; у пира с authority == unique_id — локально (call_remote себя не трогает).
func _online_server_apply_damage_to_player(player: Node, amount: int) -> void:
	var mp := get_tree().get_multiplayer()
	if not mp.is_server():
		return
	var auth := player.get_multiplayer_authority()
	if auth == mp.get_unique_id():
		player.call("take_damage", amount)
	elif player.has_method("rpc_take_damage_from_server"):
		player.rpc_take_damage_from_server.rpc_id(auth, amount)


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
	var mx: int = int(enemy.get("max_hp")) if enemy.get("max_hp") != null else maxi(h, 1)
	rpc_sync_enemy_after_damage.rpc(str(enemy.get_path()), maxi(0, h), mx, d)


@rpc("authority", "call_remote", "reliable")
func rpc_sync_enemy_after_damage(path_str: String, hp_val: int, max_hp_val: int, dead: bool) -> void:
	var n := _resolve_node_by_path_for_damage(path_str)
	if n == null or not is_instance_valid(n):
		return
	if n.get("hp") != null:
		n.hp = hp_val
	var bar := n.get_node_or_null("TextureProgressBar")
	if bar and bar.has_method("update_hp"):
		bar.call("update_hp", hp_val, max_hp_val)
	if dead:
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
func rpc_spawn_boss_loot_at(scene_res_path: String, parent_node_path: String, global_pos: Vector2) -> void:
	var parent := get_tree().root.get_node_or_null(NodePath(parent_node_path)) as Node2D
	if parent == null or not is_instance_valid(parent):
		return
	var ps := load(scene_res_path) as PackedScene
	if ps == null:
		return
	var item := ps.instantiate() as Node2D
	item.z_index = 2
	parent.add_child(item)
	item.global_position = global_pos


func server_spawn_boss_loot_for_coop(scene_res_path: String, parent: Node2D, global_pos: Vector2) -> void:
	var inst := (load(scene_res_path) as PackedScene).instantiate() as Node2D
	inst.z_index = 2
	parent.add_child(inst)
	inst.global_position = global_pos
	if is_game_offline():
		return
	var mp := get_tree().get_multiplayer()
	if mp.is_server() and mp.get_peers().size() > 0:
		rpc_spawn_boss_loot_at.rpc(scene_res_path, str(parent.get_path()), global_pos)


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
	GameConstants.apply_coop_start_state(state)


@rpc("any_peer", "call_remote", "reliable")
func rpc_submit_progress_after_level_up(state: Dictionary) -> void:
	if not is_server():
		return
	rpc_replicate_player_stats.rpc(state)


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
