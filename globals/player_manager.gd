extends Node

var players: Dictionary = {}
var pending_peers: Array = []  # Устанавливается лобби перед сменой сцены
## peer_id -> 0 Knight, 1 Sorceress (кооп: хост собирает в лобби, рассылает при старте)
var peer_characters: Dictionary = {}
var _player_scene: PackedScene
## Клиент: после load_dungeon_state без падений — true; сбрасывается в MapManager._boot_dungeon_async
var network_spawn_finalize_done: bool = false

func get_player_scene_for_index(index: int) -> PackedScene:
	if index == 1:
		return preload("res://scene/game_objects/player2/player_2.tscn")
	return preload("res://scene/game_objects/player/player.tscn")


func get_selected_player_scene() -> PackedScene:
	return get_player_scene_for_index(SaveSystem.get_selected_player())


func get_player_scene_for_peer(peer_id: int) -> PackedScene:
	return get_player_scene_for_index(get_peer_character(peer_id))


func get_peer_character(peer_id: int) -> int:
	if peer_characters.has(peer_id):
		return int(peer_characters[peer_id])
	if peer_id == NetworkManager.my_id:
		return SaveSystem.get_selected_player()
	return 0


func set_peer_character(peer_id: int, char_index: int) -> void:
	peer_characters[peer_id] = clampi(char_index, 0, 1)


func clear_peer_character(peer_id: int) -> void:
	peer_characters.erase(peer_id)


func clear_peer_characters() -> void:
	peer_characters.clear()


func build_peer_characters_for_peers(peer_ids: Array) -> Dictionary:
	var out: Dictionary = {}
	for v in peer_ids:
		var pid: int = int(v)
		out[pid] = get_peer_character(pid)
	return out


func apply_peer_characters(data: Dictionary) -> void:
	peer_characters.clear()
	for k in data.keys():
		var pid: int = int(k) if typeof(k) == TYPE_STRING else int(k)
		peer_characters[pid] = clampi(int(data[k]), 0, 1)


func _ready() -> void:
	_player_scene = get_selected_player_scene()
	NetworkManager.player_disconnected.connect(_on_network_player_disconnected)
	NetworkManager.disconnected_from_server.connect(_on_disconnected)
	get_tree().node_added.connect(_on_node_added)


## В коопе в группе «player» несколько нод; награда за убийство должна идти персонажу этой машины, не «первому попавшемуся».
func get_player_for_local_rewards() -> Node:
	var tree := get_tree()
	if NetworkManager.is_game_offline():
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
		var ref_pos := get_player_world_pos_for_hosting_ai(p2)
		var d2: float = from_global.distance_squared_to(ref_pos)
		if d2 < best_d2:
			best_d2 = d2
			best = p2
	return best


## На **хосте** для чужого пира используем target_position из RPC — иначе интерполяция отстаёт, и ИИ «видит» гостя дальше, чем хоста.
func get_player_world_pos_for_hosting_ai(p: Node2D) -> Vector2:
	if p == null or not is_instance_valid(p):
		return Vector2.ZERO
	if not NetworkManager.is_game_online():
		return p.global_position
	var mp := get_tree().get_multiplayer()
	if mp == null or not mp.is_server():
		return p.global_position
	if p.is_multiplayer_authority():
		return p.global_position
	if p.get_meta(&"net_target_valid", false):
		var tp: Variant = p.get("target_position")
		if tp is Vector2:
			return tp as Vector2
	return p.global_position


## Урон в ближнюю: только если этот игрок — ближайшая цель для ИИ (на хосте учитывается сетевой снапшот позиции).
func is_player_nearest_hosting_target(enemy_global: Vector2, body: Node2D) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	if not body.is_in_group("player"):
		return false
	var n := get_nearest_target_player_node(enemy_global)
	return n != null and n == body


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
		# current_scene при node_added может ещё быть старой (уже в очереди на free) сценой —
		# add_child в неё даёт "Trying to assign invalid previously freed instance".
		call_deferred("_deferred_boot_players_on_layer", node)


func _deferred_boot_players_on_layer(layer: Node) -> void:
	if not is_instance_valid(layer):
		return
	_on_game_scene_ready(layer)


func _on_game_scene_ready(game_root: Node) -> void:
	if not is_instance_valid(game_root):
		return
	for pid in players.keys().duplicate():
		var ex: Variant = players[pid]
		if not is_instance_valid(ex):
			players.erase(pid)
	if NetworkManager.connection_state == NetworkManager.ConnectionState.DISCONNECTED:
		NetworkManager.reset_coop_run_state()
	if NetworkManager.connection_state != NetworkManager.ConnectionState.DISCONNECTED:
		_spawn_player(NetworkManager.my_id, game_root)

	for id in pending_peers:
		if id != NetworkManager.my_id:
			_spawn_player(id, game_root)

	pending_peers.clear()
	NetworkManager.game_started.emit()


func spawn_peer(peer_id: int) -> void:
	_spawn_player(peer_id, null)


func _spawn_player(player_id: int, game_root: Node = null) -> void:
	if players.has(player_id):
		var existing: Variant = players[player_id]
		if is_instance_valid(existing):
			return
		players.erase(player_id)

	var world: Node = null
	if game_root != null and is_instance_valid(game_root):
		world = game_root
	else:
		var cs: Node = get_tree().current_scene
		if cs != null and is_instance_valid(cs):
			world = cs
	if world == null:
		push_error("PlayerManager: нет валидной сцены для спавна игрока")
		return

	var instance = get_player_scene_for_peer(player_id).instantiate()
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
	for _i in range(10):
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
		var hint := Vector2.INF
		var n_cand: int = candidates.size()
		for j in range(n_cand):
			var cand: Vector2 = candidates[(i + j) % n_cand]
			var refined := _find_valid_spawn_near(cand, 240.0, inst)
			if refined != Vector2.INF and refined.is_finite():
				hint = refined
				break
		if hint == Vector2.INF or not hint.is_finite():
			hint = candidates[mini(i, n_cand - 1)]
		var chosen := _resolve_coop_spawn_position(hint, start_room, inst)
		inst.global_position = chosen
		if inst is CharacterBody2D:
			(inst as CharacterBody2D).velocity = Vector2.ZERO
		if inst.has_method("flush_network_transform"):
			inst.flush_network_transform()
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
		var start_rn: Node2D = null
		if mm.has_method("get_coop_start_room_node"):
			start_rn = mm.get_coop_start_room_node()
		var placed := _resolve_coop_spawn_position(cand, start_rn, inst)
		inst.global_position = placed
		if inst is CharacterBody2D:
			(inst as CharacterBody2D).velocity = Vector2.ZERO
		if inst.has_method("flush_network_transform"):
			inst.flush_network_transform()


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


## Все 32 слоя физики — часть стен/декора на верхних битах; 0xFFFF давала ложные «пусто» в тайле.
const _SPAWN_QUERY_MASK: int = 4294967295


func _resolve_coop_spawn_position(hint: Vector2, start_room: Node2D, inst: Node2D) -> Vector2:
	var clamped := _clamp_spawn_to_start_room(hint, start_room)
	var v := _find_valid_spawn_near(clamped, 320.0, inst)
	if v != Vector2.INF and v.is_finite():
		return v
	v = _find_valid_spawn_near(hint, 400.0, inst)
	if v != Vector2.INF and v.is_finite():
		return v
	if start_room != null and is_instance_valid(start_room):
		var inner := _inner_walkable_rect_global(start_room)
		if inner.size.x >= 48.0 and inner.size.y >= 48.0:
			var center := inner.position + inner.size * 0.5
			v = _find_valid_spawn_near(center, 480.0, inst)
			if v != Vector2.INF and v.is_finite():
				return v
			v = _grid_search_spawn_in_rect(inner, inst)
			if v != Vector2.INF and v.is_finite():
				return v
			v = _find_valid_spawn_near(center, 720.0, inst)
			if v != Vector2.INF and v.is_finite():
				return v
	push_warning("PlayerManager: не удалось найти гарантированно свободную точку спавна в стартовой комнате")
	return clamped if clamped.is_finite() else hint


func _grid_search_spawn_in_rect(rect: Rect2, exclude_body: Node2D) -> Vector2:
	var space_state := get_viewport().find_world_2d().direct_space_state
	if space_state == null:
		return Vector2.INF
	var margin := 36.0
	var x0 := rect.position.x + margin
	var y0 := rect.position.y + margin
	var x1 := rect.position.x + rect.size.x - margin
	var y1 := rect.position.y + rect.size.y - margin
	if x1 <= x0 or y1 <= y0:
		return Vector2.INF
	var step := 40.0
	var x := x0
	while x <= x1:
		var y := y0
		while y <= y1:
			var p := Vector2(x, y)
			var hit := _find_valid_spawn_near(p, 96.0, exclude_body)
			if hit != Vector2.INF and hit.is_finite():
				return hit
			y += step
		x += step
	return Vector2.INF


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
			params.collision_mask = _SPAWN_QUERY_MASK
			if exclude_body != null and exclude_body is CollisionObject2D:
				params.exclude = [(exclude_body as CollisionObject2D).get_rid()]
			if space_state.intersect_shape(params).is_empty():
				return check_pos
		radius += step
	return Vector2.INF

func _on_network_player_disconnected(player_id: int) -> void:
	clear_peer_character(player_id)
	_despawn_player(player_id)


func _on_disconnected() -> void:
	for id in players.keys().duplicate():
		_despawn_player(id)
	players.clear()
	clear_peer_characters()


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
