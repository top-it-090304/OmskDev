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


## ИИ врагов/боссов: ближайший живой игрок (по мировой позиции). В соло совпадает с единственным игроком.
func get_nearest_target_player_node(from_global: Vector2) -> Node2D:
	var tree := get_tree()
	if tree == null:
		return null
	var best: Node2D = null
	var best_d2: float = INF
	for n in tree.get_nodes_in_group("player"):
		if not n is Node2D or not is_instance_valid(n):
			continue
		if n.get("is_dead") == true:
			continue
		var p2 := n as Node2D
		var d2: float = from_global.distance_squared_to(p2.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = p2
	return best


## В коопе: в зоне детектора есть хотя бы один живой игрок (сигналы enter/exit с двумя игроками дают ложный сброс).
func detector_has_living_player(detector: Area2D) -> bool:
	if detector == null or not is_instance_valid(detector):
		return false
	for b in detector.get_overlapping_bodies():
		if b is Node2D and b.is_in_group("player") and b.get("is_dead") != true:
			return true
	return false


func _on_node_added(node: Node) -> void:
	if node.name == "Layer" and node.get_parent() == get_tree().root:
		_on_game_scene_ready()

func _on_game_scene_ready() -> void:
	if NetworkManager.connection_state == NetworkManager.ConnectionState.DISCONNECTED:
		NetworkManager.reset_coop_run_state()
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
		var existing: Variant = players[player_id]
		if is_instance_valid(existing):
			return
		players.erase(player_id)
	
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
	# Тайл-коллизии TileMapLayer попадают в дерево не сразу — без ожидания intersect_shape даёт «пусто» в стене
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var mm := get_tree().root.find_child("MapManager", true, false)
	if mm == null or not mm.has_method("get_coop_spawn_points"):
		return
	var start_room: Node2D = null
	if mm.has_method("get_coop_start_room_node"):
		start_room = mm.get_coop_start_room_node()
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
		if not is_instance_valid(inst):
			players.erase(pid)
			continue
		var chosen: Vector2 = Vector2.INF
		var n_cand: int = candidates.size()
		for j in range(n_cand):
			var cand: Vector2 = candidates[(i + j) % n_cand]
			var refined := _find_valid_spawn_near(cand, 200.0, inst)
			if refined != Vector2.INF and refined.is_finite():
				chosen = refined
				break
		if chosen == Vector2.INF or not chosen.is_finite():
			chosen = candidates[mini(i, n_cand - 1)]
		chosen = _clamp_spawn_to_start_room(chosen, start_room)
		var snap := _find_valid_spawn_near(chosen, 200.0, inst)
		if snap != Vector2.INF and snap.is_finite():
			chosen = snap
		chosen = _clamp_spawn_to_start_room(chosen, start_room)
		var snap2 := _find_valid_spawn_near(chosen, 160.0, inst)
		if snap2 != Vector2.INF and snap2.is_finite():
			chosen = snap2
		inst.global_position = chosen
		if inst is CharacterBody2D:
			(inst as CharacterBody2D).velocity = Vector2.ZERO
	if NetworkManager.is_multiplayer_active():
		network_spawn_finalize_done = true


## Если карта ещё не загружена (гость без данжа / гонка), всё равно разносим игроков — как раньше без «тихого» return
func _fallback_place_network_players(mm: Node) -> void:
	var origin: Vector2 = Vector2.ZERO
	var found := false
	var start_cell: Vector2i = Vector2i.ZERO
	if mm.has_method("get_safe_room_position"):
		start_cell = mm.get_safe_room_position()
	var rooms_var: Variant = mm.get("spawned_rooms")
	if rooms_var != null and rooms_var is Array:
		var rooms: Array = rooms_var
		for room_data in rooms:
			if not room_data is Dictionary:
				continue
			if room_data.get("grid_pos") != start_cell:
				continue
			var rn: Node2D = room_data.get("node") as Node2D
			if rn == null or not is_instance_valid(rn):
				continue
			if mm.has_method("get_start_room_spawn_global"):
				origin = mm.get_start_room_spawn_global(rn)
			else:
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
		if not is_instance_valid(inst):
			players.erase(pid)
			continue
		var off := Vector2((i - (n - 1) * 0.5) * 88.0, 0.0)
		var cand := origin + off
		var fixed := _find_valid_spawn_near(cand, 256.0, inst)
		if fixed != Vector2.INF and fixed.is_finite():
			cand = fixed
		inst.global_position = cand
		if inst is CharacterBody2D:
			(inst as CharacterBody2D).velocity = Vector2.ZERO


func _despawn_player(player_id: int) -> void:
	if not players.has(player_id):
		return
	var inst: Variant = players[player_id]
	if is_instance_valid(inst):
		(inst as Node).queue_free()
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
		var spawn_pos = _find_valid_spawn_near(search_origin, 256.0, instance)
		if spawn_pos != Vector2.INF:
			instance.global_position = spawn_pos
			return

	# Резервный путь через MapManager
	var map_manager = get_tree().root.find_child("MapManager", true, false)
	if map_manager and map_manager.has_method("get_spawn_point"):
		instance.global_position = map_manager.get_spawn_point()

func _inner_walkable_rect_global(room_node: Node2D) -> Rect2:
	if room_node == null or not is_instance_valid(room_node):
		return Rect2()
	var rs := room_node.find_child("room_shape", true, false) as Area2D
	if rs == null:
		var tl := room_node.global_position
		var m := 96.0
		var rz := Vector2(GameConstants.MAP_MANAGER_ROOM_SIZE_X, GameConstants.MAP_MANAGER_ROOM_SIZE_Y)
		return Rect2(tl.x + m, tl.y + m, rz.x - 2.0 * m, rz.y - 2.0 * m)
	var cs := rs.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null or cs.shape == null or not (cs.shape is RectangleShape2D):
		var tl2 := room_node.global_position
		var m2 := 96.0
		var rz2 := Vector2(GameConstants.MAP_MANAGER_ROOM_SIZE_X, GameConstants.MAP_MANAGER_ROOM_SIZE_Y)
		return Rect2(tl2.x + m2, tl2.y + m2, rz2.x - 2.0 * m2, rz2.y - 2.0 * m2)
	var rr := cs.shape as RectangleShape2D
	var half := rr.size * 0.5
	return Rect2(cs.global_position - half, rr.size)


func _clamp_spawn_to_start_room(pos: Vector2, room_node: Node2D) -> Vector2:
	if room_node == null or not is_instance_valid(room_node):
		return pos
	var inner := _inner_walkable_rect_global(room_node)
	if inner.size.x < 32.0 or inner.size.y < 32.0:
		return pos
	var pad := 40.0
	return Vector2(
		clampf(pos.x, inner.position.x + pad, inner.position.x + inner.size.x - pad),
		clampf(pos.y, inner.position.y + pad, inner.position.y + inner.size.y - pad)
	)


func _find_valid_spawn_near(center: Vector2, max_search_radius: float = 256.0, exclude_body: Node2D = null) -> Vector2:
	var space_state := get_viewport().find_world_2d().direct_space_state
	if space_state == null:
		return Vector2.INF
	var radius := 48.0
	var step := 24.0
	# Капсула ближе к CharacterBody2D игрока (круг r≈9 у ног), чем квадрат 32×32
	var shape := CircleShape2D.new()
	shape.radius = 12.0
	while radius <= max_search_radius:
		for i in range(12):
			var angle := TAU * float(i) / 12.0
			var check_pos := center + Vector2(cos(angle), sin(angle)) * radius
			var params := PhysicsShapeQueryParameters2D.new()
			params.shape = shape
			# Смещение как у CollisionShape2D игрока (y+8)
			params.transform = Transform2D(0, check_pos + Vector2(0, 8))
			params.collide_with_areas = true
			params.collide_with_bodies = true
			# Тайлсет стен: layer 1+8 (129) и др.; mask=3 давал ложные «пустые» точки в стене
			params.collision_mask = 0x0000FFFF
			if exclude_body != null and exclude_body is CollisionObject2D:
				params.exclude = [(exclude_body as CollisionObject2D).get_rid()]
			if space_state.intersect_shape(params).is_empty():
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
