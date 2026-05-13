extends Node

var players: Dictionary = {}
var pending_peers: Array = []  # Устанавливается лобби перед сменой сцены
var _player_scene: PackedScene
## Клиент: после load_dungeon_state без падений — true; сбрасывается в MapManager._boot_dungeon_async
var network_spawn_finalize_done: bool = false

func _ready() -> void:
	_player_scene = preload("res://scene/game_objects/player/player.tscn")
	NetworkManager.player_disconnected.connect(_despawn_player)
	NetworkManager.disconnected_from_server.connect(_on_disconnected)
	get_tree().node_added.connect(_on_node_added)


## В коопе в группе «player» несколько нод; награда за убийство должна идти персонажу этой машины, не «первому попавшемуся».
func get_player_for_local_rewards() -> Node:
	var tree := get_tree()
	if not tree.get_multiplayer().has_multiplayer_peer():
		return tree.get_first_node_in_group("player")
	var lp := tree.get_first_node_in_group("local_player")
	return lp if lp != null else tree.get_first_node_in_group("player")


func _on_node_added(node: Node) -> void:
	if node.name == "Layer" and node.get_parent() == get_tree().root:
		_on_game_scene_ready()

func _on_game_scene_ready() -> void:
	if NetworkManager.connection_state != NetworkManager.ConnectionState.DISCONNECTED:
		_spawn_player(NetworkManager.my_id)
	
	for id in pending_peers:
		if id != NetworkManager.my_id:
			_spawn_player(id)
	
	pending_peers.clear()
	NetworkManager.game_started.emit()


func spawn_peer(peer_id: int) -> void:
	_spawn_player(peer_id)

func _spawn_player(player_id: int) -> void:
	if players.has(player_id):
		return
	
	var world = get_tree().current_scene
	if not world:
		push_error("PlayerManager: нет текущей сцены")
		return
		
	var instance = _player_scene.instantiate()
	instance.name = "Player_%d" % player_id
	instance.set_multiplayer_authority(player_id)
	world.add_child(instance)
	
	if player_id == NetworkManager.my_id:
		instance.is_local_player = true
	
	players[player_id] = instance
	if NetworkManager.connection_state == NetworkManager.ConnectionState.DISCONNECTED:
		_position_new_player(instance, player_id)


## Вызывается из MapManager после полной загрузки/генерации карты (один раз на этаж)
func finalize_network_spawns() -> void:
	if NetworkManager.connection_state == NetworkManager.ConnectionState.DISCONNECTED:
		return
	if NetworkManager.is_multiplayer_active() and network_spawn_finalize_done:
		return
	# Тайл-коллизии и стены после draw_map — одного кадра мало (спавн «в стене»)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var mm := get_tree().root.find_child("MapManager", true, false)
	if mm == null or not mm.has_method("get_coop_spawn_points"):
		return
	var candidates: Array = mm.get_coop_spawn_points()
	if candidates.is_empty():
		_fallback_place_network_players(mm)
		if NetworkManager.is_multiplayer_active():
			network_spawn_finalize_done = true
		return
	var sorted_ids: Array = players.keys()
	sorted_ids.sort()
	for i in sorted_ids.size():
		var pid: int = sorted_ids[i]
		if not players.has(pid):
			continue
		var inst: Node2D = players[pid]
		var chosen: Vector2 = Vector2.INF
		var n_cand: int = candidates.size()
		for j in range(n_cand):
			var cand: Vector2 = candidates[(i + j) % n_cand]
			var refined := _find_valid_spawn_near(cand)
			if refined != Vector2.INF and refined.is_finite():
				chosen = refined
				break
		if chosen == Vector2.INF or not chosen.is_finite():
			chosen = candidates[mini(i, n_cand - 1)]
		var snap := _find_valid_spawn_near(chosen)
		if snap != Vector2.INF and snap.is_finite():
			chosen = snap
		inst.global_position = chosen
		if inst is CharacterBody2D:
			(inst as CharacterBody2D).velocity = Vector2.ZERO
	if NetworkManager.is_multiplayer_active():
		network_spawn_finalize_done = true


## Если карта ещё не загружена (гость без данжа / гонка), всё равно разносим игроков — как раньше без «тихого» return
func _fallback_place_network_players(mm: Node) -> void:
	var origin: Vector2 = Vector2.ZERO
	var found := false
	var rooms_var: Variant = mm.get("spawned_rooms")
	if rooms_var != null and rooms_var is Array:
		var rooms: Array = rooms_var
		for room_data in rooms:
			if not room_data is Dictionary:
				continue
			var rn: Node2D = room_data.get("node") as Node2D
			if rn == null or not is_instance_valid(rn):
				continue
			var lc := Vector2(
				GameConstants.MAP_MANAGER_ROOM_SIZE_X * 0.5,
				GameConstants.MAP_MANAGER_ROOM_SIZE_Y * 0.5
			)
			origin = rn.to_global(lc)
			found = true
			break
	if not found:
		var cam := mm.get_viewport().get_camera_2d()
		if cam:
			origin = cam.get_screen_center_position()
		else:
			var layer := mm.get_parent() as Node2D
			origin = layer.global_position + Vector2(400, 280) if layer else Vector2(400, 280)
	var sorted_ids: Array = players.keys()
	sorted_ids.sort()
	var n := sorted_ids.size()
	for i in n:
		var pid: int = sorted_ids[i]
		if not players.has(pid):
			continue
		var inst: Node2D = players[pid]
		var off := Vector2((i - (n - 1) * 0.5) * 88.0, 0.0)
		inst.global_position = origin + off
		if inst is CharacterBody2D:
			(inst as CharacterBody2D).velocity = Vector2.ZERO


func _despawn_player(player_id: int) -> void:
	if not players.has(player_id):
		return
	players[player_id].queue_free()
	players.erase(player_id)

func _position_new_player(instance: Node2D, player_id: int) -> void:
	if NetworkManager.connection_state == NetworkManager.ConnectionState.DISCONNECTED:
		return

	# Пробуем найти позицию локального игрока
	var search_origin: Vector2 = Vector2.INF
	
	if players.has(NetworkManager.my_id):
		search_origin = players[NetworkManager.my_id].global_position
	else:
		# Если локального нет, ищем любого другого
		for pid in players:
			if pid != player_id:
				search_origin = players[pid].global_position
				break
	
	if search_origin != Vector2.INF:
		var spawn_pos = _find_valid_spawn_near(search_origin)
		if spawn_pos != Vector2.INF:
			instance.global_position = spawn_pos
			return

	# Резервный путь через MapManager
	var map_manager = get_tree().root.find_child("MapManager", true, false)
	if map_manager and map_manager.has_method("get_spawn_point"):
		instance.global_position = map_manager.get_spawn_point()

func _find_valid_spawn_near(center: Vector2) -> Vector2:
	var space_state = get_viewport().find_world_2d().direct_space_state
	var radius = 64.0
	var max_radius = 256.0
	var step = 32.0
	
	var shape = RectangleShape2D.new()
	shape.size = Vector2(32, 32)
	
	while radius <= max_radius:
		for i in range(8):
			var angle = i * PI / 4.0
			var check_pos = center + Vector2(cos(angle), sin(angle)) * radius
			
			var params = PhysicsShapeQueryParameters2D.new()
			params.shape = shape
			params.transform = Transform2D(0, check_pos)
			# Как у CharacterBody2D игрока (hitbox collision_mask = 2) — иначе «пусто» и точка внутри стены
			params.collision_mask = 3
			
			var result = space_state.intersect_shape(params)
			if result.is_empty():
				return check_pos
		radius += step
	
	return Vector2.INF

func _on_disconnected() -> void:
	for id in players.keys().duplicate():
		_despawn_player(id)
	players.clear()


func find_safe_spawn_near_global(center: Vector2) -> Vector2:
	return _find_valid_spawn_near(center)


func host_pull_co_players_into_combat_room(enemys_node: Node) -> void:
	if not NetworkManager.is_multiplayer_active():
		return
	var mp := get_tree().get_multiplayer()
	if not mp.is_server():
		return
	var room_root := enemys_node.get_parent() as Node2D
	if room_root == null:
		return
	var rs := room_root.find_child("room_shape", true, false) as Area2D
	if rs == null:
		return
	var insiders: Array[Node2D] = []
	for b in rs.get_overlapping_bodies():
		if b is Node2D and b.is_in_group("player"):
			insiders.append(b as Node2D)
	if insiders.is_empty():
		return
	var anchor: Vector2 = insiders[0].global_position
	for p in get_tree().get_nodes_in_group("player"):
		if not p is CharacterBody2D:
			continue
		if insiders.has(p):
			continue
		var pos := find_safe_spawn_near_global(anchor)
		if pos == Vector2.INF or not pos.is_finite():
			pos = anchor + Vector2(72, 0)
		var auth := p.get_multiplayer_authority()
		if auth == mp.get_unique_id():
			(p as CharacterBody2D).global_position = pos
			(p as CharacterBody2D).velocity = Vector2.ZERO
		else:
			if p.has_method("rpc_server_teleport_to"):
				(p as Node).rpc_server_teleport_to.rpc_id(auth, pos)
