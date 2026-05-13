extends Node2D

# --- НАСТРОЙКИ ---
@export var start_room_variations: Array[PackedScene] = [] 
@export var normal_room_variations: Array[PackedScene] = [] 
@export var boss_room_variations: Array[PackedScene] = [] 
@export var treasure_room_variations: Array[PackedScene] = [] 

@export var layer: Node 

@export var corridor_h_scene: PackedScene 
@export var corridor_v_scene: PackedScene
@export var enemy_variations: Array[PackedScene] = [] 
@export var boss_variations: Array[PackedScene] = [] 
# НОВОЕ: Массив всех возможных предметов для Treasure Room
@export var treasure_items: Array[PackedScene] = []

@export var player_scene:PackedScene
# Люк на следующий этаж — в центре комнаты босса, ссылка для лута боссов
const HATCH_SCENE := preload("res://scene/pick_up/hatch.tscn")
var boss_hatch: Area2D = null
# Гибкий массив препятствий
@export var obstacle_data: Array[Dictionary] = [
	{"scene": preload("res://sprites/Rocks/rock_1.tscn"), "size": Vector2(32, 32)},
	{"scene": preload("res://sprites/Rocks/rock_2.tscn"), "size": Vector2(32, 32)},
	{"scene": preload("res://sprites/Rocks/rock_3.tscn"), "size": Vector2(32, 32)},
	{"scene": preload("res://sprites/Rocks/rock_4.tscn"), "size": Vector2(32, 32)},
	{"scene": preload("res://sprites/Rocks/rock_5.tscn"), "size": Vector2(32, 32)},
	{"scene": preload("res://sprites/Rocks/rock_6.tscn"), "size": Vector2(48, 32)}
]

# Размер комнаты и КОРидОРА в пикселях

enum RoomType { EMPTY, START, NORMAL, BOSS, TREASURE }
var layout = []
var spawned_rooms = []

# НОВОЕ: "Текущая колода" предметов для выдачи
var item_draw_pile: Array[PackedScene] = []

# Seed для генерации (для сохранения/загрузки)
var generation_seed: int = 0

#minimap
var current_room_grid_pos = Vector2i(GameConstants.MAP_MANAGER_GRID_SIZE / 2, GameConstants.MAP_MANAGER_GRID_SIZE / 2)
signal room_changed(new_grid_pos)
var visited_rooms = []
var seen_rooms = []

var _enemy_net_sync_accum: float = 0.0
const ENEMY_NET_SYNC_INTERVAL: float = 0.09


func _ready() -> void:
	add_to_group("map_manager")
	if get_tree().get_multiplayer().has_multiplayer_peer():
		set_multiplayer_authority(NetworkManager.SERVER_ID)
	get_tree().auto_accept_quit = false  # Перехватываем попытки выхода

	if start_room_variations.is_empty() or normal_room_variations.is_empty() or boss_room_variations.is_empty():
		push_error("ОШИБКА: Добавь хотя бы по одной сцене для Start, Normal и Boss комнат!")
		return

	call_deferred("_boot_dungeon_async")


func _client_retry_finalize_if_needed() -> void:
	if not NetworkManager.is_multiplayer_active() or NetworkManager.is_hosting():
		return
	if PlayerManager.network_spawn_finalize_done:
		return
	push_warning("MapManager: клиент — повторный finalize_network_spawns (после сбоя загрузки данжа?)")
	PlayerManager.finalize_network_spawns()


func _boot_dungeon_async() -> void:
	PlayerManager.network_spawn_finalize_done = false
	# Гость (не хост лобби): ждём dungeon с хоста. Не используем is_client() — при HOSTING
	# иногда is_server() ещё не готов, и хост ошибочно попадал в эту ветку и зависал на await.
	if NetworkManager.is_multiplayer_active() and not NetworkManager.is_hosting():
		await get_tree().process_frame
		var ok: bool = await NetworkManager.client_wait_dungeon_ready(75.0)
		if not ok:
			NetworkManager.rpc_request_dungeon_resync.rpc_id(NetworkManager.SERVER_ID)
			ok = await NetworkManager.client_wait_dungeon_ready(30.0)
		if SaveSystem.has_dungeon_state():
			await load_dungeon_state()
		else:
			push_error("MapManager: клиент так и не получил dungeon_state")
		PlayerManager.finalize_network_spawns()
		# Если load_dungeon_state упал по ошибке, finalize не отработал — повтор через несколько секунд
		var retry_t := get_tree().create_timer(3.0)
		retry_t.timeout.connect(_client_retry_finalize_if_needed, CONNECT_ONE_SHOT)
		return

	if SaveSystem.has_dungeon_state():
		print("=== ЗАГРУЗКА СОХРАНЕННОГО ДАНЖЕНА ===")
		await load_dungeon_state()
	else:
		print("=== ГЕНЕРАЦИЯ НОВОГО ДАНЖЕНА ===")
		generation_seed = randi()
		seed(generation_seed)
		print("Seed генерации: ", generation_seed)

		generate_layout()
		draw_map()
		await get_tree().create_timer(0).timeout
		_spawn_player()
		await _spawn_obstacles_after_physics()
		await _spawn_enemies_after_physics()

		_spawn_treasure_items()

		change_current_room(current_room_grid_pos.x, current_room_grid_pos.y)

		save_dungeon_state()

	if NetworkManager.is_multiplayer_active() and NetworkManager.is_hosting():
		NetworkManager.host_publish_dungeon_state()

	PlayerManager.finalize_network_spawns()


## Глобальная точка спавна в стартовой комнате: PlayerSpawn → старый Marker2D → центр bbox (тайлы могут быть со сдвигом от центра комнаты).
func get_start_room_spawn_global(room_node: Node2D) -> Vector2:
	if room_node == null or not is_instance_valid(room_node):
		return Vector2.ZERO
	var m := room_node.find_child("PlayerSpawn", true, false) as Node2D
	if m != null:
		return m.global_position
	m = room_node.find_child("Marker2D", true, false) as Node2D
	if m != null:
		return m.global_position
	var lc := Vector2(
		GameConstants.MAP_MANAGER_ROOM_SIZE_X * 0.5,
		GameConstants.MAP_MANAGER_ROOM_SIZE_Y * 0.5
	)
	return room_node.to_global(lc)


func get_coop_spawn_points() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var start_cell: Vector2i = get_safe_room_position()
	for room_data in spawned_rooms:
		if room_data["grid_pos"] != start_cell:
			continue
		var room_node := room_data["node"] as Node2D
		var base: Vector2 = get_start_room_spawn_global(room_node)
		# Фиксированные отступы от маркера (в сторону центра пола), без ухода вверх к верхней стене
		var offsets: Array[Vector2] = [
			Vector2(-88, 28),
			Vector2(88, 28),
			Vector2(0, 52),
			Vector2(-88, 52),
			Vector2(88, 52),
		]
		for off in offsets:
			out.append(base + off)
		break
	return out


func get_coop_start_room_node() -> Node2D:
	var start_cell: Vector2i = get_safe_room_position()
	for room_data in spawned_rooms:
		if room_data["grid_pos"] == start_cell:
			return room_data["node"] as Node2D
	return null

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Игрок закрывает игру через Alt+F4 или кнопку окна
		get_tree().set_auto_accept_quit(false)
		# Сохраняем всё перед выходом
		SaveSystem.save_game()
		save_dungeon_state()
		print("=== ВЫХОД ИЗ ИГРЫ - СОХРАНЕНО ===")
		get_tree().quit()

# =====================================================================
# НОВОЕ: ЛОГИКА "КОЛОДЫ КАРТ" ДЛЯ ПРЕДМЕТОВ
# =====================================================================
# =====================================================================
# НОВОЕ: СПАВН ИГРОКА
# =====================================================================
func _spawn_player():
	# В мультиплеере игроков спавнит PlayerManager
	if NetworkManager.connection_state != NetworkManager.ConnectionState.DISCONNECTED:
		return

	var Player = null

	# 1. Если сцена игрока задана в инспекторе, создаем его
	if player_scene:
		Player = player_scene.instantiate()
		layer.add_child(Player) # Добавляем как child прямо в MapManager
	else:
		# 2. Если сцена не задана, пробуем найти игрока уже на сцене (например, если он в автолоаде)
		Player = get_tree().get_first_node_in_group("player")
		if not Player:
			push_warning("MapManager: Сцена игрока не назначена и игрок в группе 'player' не найден!")
			return

	# Ищем стартовую комнату в списке заспавненных
	for room_data in spawned_rooms:
		if room_data["type"] == RoomType.START:
			var room_node := room_data["node"] as Node2D
			var target_pos: Vector2 = get_start_room_spawn_global(room_node)
			# Wait one frame so the node is fully in the scene tree
			await get_tree().process_frame
			Player.global_position = target_pos
			break

# =============
func _get_next_treasure_item() -> PackedScene:
	if treasure_items.is_empty():
		return null
		
	# Если колода пуста, берем все предметы из инспектора, копируем их и перемешиваем
	if item_draw_pile.is_empty():
		item_draw_pile = treasure_items.duplicate()
		item_draw_pile.shuffle()
	if item_draw_pile.is_empty():
		return null
	# Достаем верхнюю карту из колоды (pop_back() быстрее, чем pop_front())
	return item_draw_pile.pop_back()

func _spawn_treasure_items():
	for room_data in spawned_rooms:
		if room_data["type"] == RoomType.TREASURE:
			var room_pos = room_data["grid_pos"]

			# Проверяем, был ли артефакт уже собран в этой комнате
			if SaveSystem.is_treasure_collected(room_pos):
				print("Артефакт в комнате ", room_pos, " уже собран, пропускаем")
				continue

			var item_scene = _get_next_treasure_item()

			if item_scene == null:
				push_warning("Массив treasure_items пуст, предмет не заспавнен.")
				continue

			var room_node = room_data["node"]
			var item_instance = item_scene.instantiate()

			# Добавляем предмет напрямую в корень комнаты
			room_node.add_child(item_instance)
			item_instance.set_meta("_treasure_room_grid", room_pos)

			# Строго по центру комнаты
			var local_center = Vector2(GameConstants.MAP_MANAGER_ROOM_SIZE_X / 2.0, GameConstants.MAP_MANAGER_ROOM_SIZE_Y / 2.0)
			var world_pos: Vector2 = (room_node as Node2D).to_global(local_center)
			item_instance.global_position = world_pos + Vector2(0, -10)

			# Спавним подставку под артефактом
			var pedestal_scene := preload("res://scene/pick_up/artefacts/artefact_pedestal.tscn")
			var pedestal := pedestal_scene.instantiate()
			room_node.add_child(pedestal)
			pedestal.global_position = world_pos
			pedestal.z_index = -1  # render behind artefact

# --- Генерация скелета ---
func generate_layout():
	layout = []
	for x in range(GameConstants.MAP_MANAGER_GRID_SIZE):
		layout.append([])
		for y in range(GameConstants.MAP_MANAGER_GRID_SIZE):
			layout[x].append(RoomType.EMPTY)

	var start_pos = Vector2i(GameConstants.MAP_MANAGER_GRID_SIZE / 2, GameConstants.MAP_MANAGER_GRID_SIZE / 2)
	layout[start_pos.x][start_pos.y] = RoomType.START

	var boss_pos = Vector2i(GameConstants.MAP_MANAGER_GRID_SIZE - 2, randi_range(1, GameConstants.MAP_MANAGER_GRID_SIZE - 2))
	layout[boss_pos.x][boss_pos.y] = RoomType.BOSS

	var current = start_pos
	while current != boss_pos:
		if !is_valid_pos(current): break 
		
		var next_step = current
		if randf() < 0.7 || current.y == boss_pos.y:
			next_step.x += 1 if boss_pos.x > current.x else -1
		else:
			next_step.y += 1 if boss_pos.y > current.y else -1
			
		if !is_valid_pos(next_step):
			continue 
			
		current = next_step
		if layout[current.x][current.y] == RoomType.EMPTY:
			layout[current.x][current.y] = RoomType.NORMAL

	for _i in range(randi_range(3, 6)):
		var rand_room = get_random_room_of_type(RoomType.NORMAL)
		if rand_room == Vector2i(-1, -1): break 
		
		var dir = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)].pick_random()
		var new_pos = rand_room + dir
		
		if is_valid_pos(new_pos) and layout[new_pos.x][new_pos.y] == RoomType.EMPTY:
			layout[new_pos.x][new_pos.y] = RoomType.NORMAL

	var treasure_count = randi_range(4, 6)
	var treasures_placed = 0
	
	# Даем 15 попыток (вместо 2), чтобы точно найти свободное место на карте
	for _i in range(15):
		if treasures_placed >= treasure_count:
			break # Уже поставили нужное количество, выходим из цикла
			
		var rand_room = get_random_room_of_type(RoomType.NORMAL)
		if rand_room == Vector2i(-1, -1): break
		
		# Перемешиваем направления, чтобы не всегда лепить сокровищницу только вправо или вниз
		var directions = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
		directions.shuffle()
		
		var placed = false
		# Проверяем все 4 стороны случайно выбранной комнаты
		for dir in directions:
			var new_pos = rand_room + dir
			
			# Если нашли пустое место — ставим сокровищницу
			if is_valid_pos(new_pos) and layout[new_pos.x][new_pos.y] == RoomType.EMPTY:
				layout[new_pos.x][new_pos.y] = RoomType.TREASURE
				treasures_placed += 1
				placed = true
				break # Место нашли, дальше эту комнату не проверяем

func is_valid_pos(pos):
	return pos.x >= 0 and pos.x < GameConstants.MAP_MANAGER_GRID_SIZE and pos.y >= 0 and pos.y < GameConstants.MAP_MANAGER_GRID_SIZE

func get_random_room_of_type(type):
	var valid_rooms = []
	for x in range(GameConstants.MAP_MANAGER_GRID_SIZE):
		for y in range(GameConstants.MAP_MANAGER_GRID_SIZE):
			if layout[x][y] == type: valid_rooms.append(Vector2i(x, y))
	if valid_rooms.is_empty(): return Vector2i(-1, -1)
	return valid_rooms.pick_random()

# --- ОТРИСОВКА ---
func draw_map():
	# Иначе повторный draw_map / load_dungeon_state оставляет старые комнаты и «битые» ссылки → queue_free на freed
	for c in get_children().duplicate():
		if is_instance_valid(c):
			c.free()
	spawned_rooms.clear()
	boss_hatch = null

	var cell_size_x = GameConstants.MAP_MANAGER_ROOM_SIZE_X + GameConstants.MAP_MANAGER_CORRIDOR_LENGTH
	var cell_size_y = GameConstants.MAP_MANAGER_ROOM_SIZE_Y + GameConstants.MAP_MANAGER_CORRIDOR_LENGTH
	
	var offset_x = -(GameConstants.MAP_MANAGER_GRID_SIZE * cell_size_x) / 2
	var offset_y = -(GameConstants.MAP_MANAGER_GRID_SIZE * cell_size_y) / 2

	for x in range(GameConstants.MAP_MANAGER_GRID_SIZE):
		for y in range(GameConstants.MAP_MANAGER_GRID_SIZE):
			if layout[x][y] != RoomType.EMPTY:
				
				var room_pos = Vector2(offset_x + x * cell_size_x, offset_y + y * cell_size_y)
				var selected_room_scene: PackedScene = null
				
				match layout[x][y]:
					RoomType.START:
						if not start_room_variations.is_empty():
							selected_room_scene = start_room_variations.pick_random()
					RoomType.NORMAL:
						if not normal_room_variations.is_empty():
							selected_room_scene = normal_room_variations.pick_random()
					RoomType.BOSS:
						if not boss_room_variations.is_empty():
							selected_room_scene = boss_room_variations.pick_random()
					RoomType.TREASURE:
						if not treasure_room_variations.is_empty():
							selected_room_scene = treasure_room_variations.pick_random()
				
				if selected_room_scene == null:
					continue
					
				# ВОТ ЗДЕСЬ ИЗМЕНЕНИЕ: as RoomBase
				var room_instance = selected_room_scene.instantiate() as RoomBase
				
				# Если somehow сцена оказалась не той, пропускаем (защита от вылета)
				if room_instance == null:
					continue
				
				room_instance.position = room_pos
				room_instance.grid_x = x
				room_instance.grid_y = y
				if layout[x][y] == RoomType.BOSS:
					room_instance.is_boss_room = true

				add_child(room_instance)

				spawned_rooms.append({
					"node": room_instance,
					"type": layout[x][y],
					"grid_pos": Vector2i(x, y)
				})
				
				var has_left = check_neighbor(x - 1, y)
				var has_right = check_neighbor(x + 1, y)
				var has_top = check_neighbor(x, y - 1)
				var has_bottom = check_neighbor(x, y + 1)
				
				room_instance.setup_room(has_left, has_right, has_top, has_bottom)
				
				
				if has_right:
					var corr = corridor_h_scene.instantiate()
					corr.position.x = room_pos.x + GameConstants.MAP_MANAGER_ROOM_SIZE_X
					corr.position.y = room_pos.y + (GameConstants.MAP_MANAGER_ROOM_SIZE_Y / 2) - (GameConstants.MAP_MANAGER_CORRIDOR_LENGTH / 2) 
					add_child(corr)
				
				if has_bottom:
					var corr = corridor_v_scene.instantiate()
					corr.position.x = room_pos.x + (GameConstants.MAP_MANAGER_ROOM_SIZE_X / 2) - (GameConstants.MAP_MANAGER_CORRIDOR_LENGTH / 2)
					corr.position.y = room_pos.y + GameConstants.MAP_MANAGER_ROOM_SIZE_Y
					add_child(corr)

func check_neighbor(nx, ny):
	if is_valid_pos(Vector2i(nx, ny)):
		return layout[nx][ny] != RoomType.EMPTY
	return false

# =====================================================================
# СПАВН ПРЕПЯТСТВИЙ
# =====================================================================

func _spawn_obstacles_in_room(room_node: Node2D, room_type: RoomType):
	if room_type == RoomType.BOSS or room_type == RoomType.START or room_type == RoomType.TREASURE or room_type == RoomType.EMPTY:
		return
		
	if obstacle_data.is_empty():
		return
	var n_obstacles := obstacle_data.size()

	var container = room_node.find_child("Obstacles")
	if container == null:
		return

	var obstacle_count = 0
	var type_of_room = randi_range(1, 3)
	match type_of_room:
		1: obstacle_count = randi_range(0, 5)
		2: obstacle_count = randi_range(3, 8)
		3: obstacle_count = randi_range(10, 15)
		
	var space_state = get_world_2d().direct_space_state
	var spawned_rects: Array[Rect2] = []
	var padding = 8.0 

	for _i in range(obstacle_count):
		var data: Dictionary
		match type_of_room:
			1:
				data = obstacle_data[0]
			2:
				if n_obstacles >= 3:
					data = obstacle_data[1] if randi_range(0, 1) == 0 else obstacle_data[2]
				else:
					data = obstacle_data[mini(1, n_obstacles - 1)]
			3:
				if n_obstacles >= 6:
					var r := randi_range(0, 2)
					data = obstacle_data[3 + r]
				else:
					data = obstacle_data[mini(3, n_obstacles - 1)]
				
		var scene: PackedScene = data["scene"]
		var size: Vector2 = data["size"]
		
		if scene == null: continue
		
		var shape = RectangleShape2D.new()
		shape.size = size
		
		var params = PhysicsShapeQueryParameters2D.new()
		params.shape = shape
		params.collide_with_bodies = true
		params.collision_mask = 1 
		
		var half_size = size / 2.0
		var max_attempts = 30

		for _attempt in range(max_attempts):
			var local_x = randf_range(half_size.x + 64, GameConstants.MAP_MANAGER_ROOM_SIZE_X - half_size.x - 64)
			var local_y = randf_range(half_size.y + 64, GameConstants.MAP_MANAGER_ROOM_SIZE_Y - half_size.y - 64)
			var local_pos = Vector2(local_x, local_y)
			var global_pos = room_node.to_global(local_pos)
			
			params.transform = Transform2D(0, global_pos) 
			
			var wall_hits = space_state.intersect_shape(params)
			if not wall_hits.is_empty():
				continue
				
			var new_rect = Rect2(global_pos - half_size, size).grow(padding)
			var overlaps_obstacle = false
			for existing_rect in spawned_rects:
				if new_rect.intersects(existing_rect):
					overlaps_obstacle = true
					break
			
			if overlaps_obstacle:
				continue
			
			var obstacle = scene.instantiate()
			container.add_child(obstacle)
			obstacle.global_position = global_pos
			spawned_rects.append(new_rect)
			break

func _spawn_obstacles_after_physics():
	await get_tree().physics_frame 
	for room_data in spawned_rooms:
		_spawn_obstacles_in_room(room_data["node"], room_data["type"])

# =====================================================================
# СПАВН ВРАГОВ
# =====================================================================

func _spawn_enemies_after_physics():
	await get_tree().physics_frame 
	
	if enemy_variations.is_empty():
		return
		
	var space_state = get_world_2d().direct_space_state
	
	for room_data in spawned_rooms:
		var room_type = room_data["type"]
		var room_node = room_data["node"]
		
		if room_type == RoomType.START or room_type == RoomType.TREASURE or room_type == RoomType.EMPTY:
			continue
			
		var enemy_count = 0
		
		if room_type==RoomType.NORMAL: enemy_count = randi_range(2, 5)
		
		if room_type==RoomType.BOSS: 
			_spawn_boss(space_state, room_node)
			return
			
		for _i in range(enemy_count):
			_spawn_single_enemy(space_state, room_node)
func _spawn_boss(space_state, room_node):
	if boss_variations.is_empty():
		push_warning("MapManager: boss_variations пуст — босс не заспавнен")
		return
	var local_x = (GameConstants.MAP_MANAGER_ROOM_SIZE_X /2)
	var local_y = (GameConstants.MAP_MANAGER_ROOM_SIZE_Y /2)
	var local_point = Vector2(local_x, local_y)
	var global_point = room_node.to_global(local_point)

	var query = PhysicsPointQueryParameters2D.new()
	query.position = global_point 
	query.collide_with_bodies = true  
	query.collide_with_areas = false  
	query.collision_mask = 1 

	var intersection = space_state.intersect_point(query)

	if intersection.is_empty():
		var selected_boss_scene = boss_variations.pick_random()
		var boss = selected_boss_scene.instantiate()
		
		var area_enemys = room_node.find_child("Enemys")
		if area_enemys == null:
			return
		
		area_enemys.add_child(boss)
		boss.global_position = global_point
		# Люк в геометрическом центре комнаты босса (локальные координаты комнаты)
		if boss_hatch != null and is_instance_valid(boss_hatch):
			boss_hatch.queue_free()
			boss_hatch = null
		var hatch_inst := HATCH_SCENE.instantiate() as Area2D
		room_node.add_child(hatch_inst)
		hatch_inst.position = local_point
		boss_hatch = hatch_inst
		if SaveSystem.is_boss_hatch_opened() and hatch_inst.has_method("apply_save_open_state"):
			hatch_inst.apply_save_open_state()
		return


func open_boss_hatch() -> void:
	apply_boss_hatch_opened_visual()
	var mp := get_tree().get_multiplayer()
	if not mp.has_multiplayer_peer():
		return
	if mp.is_server():
		NetworkManager.rpc_boss_hatch_open_to_peers.rpc()
	else:
		NetworkManager.rpc_request_server_boss_hatch_open.rpc_id(NetworkManager.SERVER_ID)


func apply_boss_hatch_opened_visual() -> void:
	if boss_hatch != null and is_instance_valid(boss_hatch) and boss_hatch.has_method("apply_hatch_open_visual"):
		boss_hatch.apply_hatch_open_visual()
	SaveSystem.set_boss_hatch_opened(true)


func _spawn_single_enemy(space_state, room_node):
	var max_attempts = 30 
	
	for _attempt in range(max_attempts):
		var local_x = randf_range(64, GameConstants.MAP_MANAGER_ROOM_SIZE_X - 64)
		var local_y = randf_range(64, GameConstants.MAP_MANAGER_ROOM_SIZE_Y - 64)
		var local_point = Vector2(local_x, local_y)
		var global_point = room_node.to_global(local_point)

		var query = PhysicsPointQueryParameters2D.new()
		query.position = global_point 
		query.collide_with_bodies = true  
		query.collide_with_areas = false  
		query.collision_mask = 1 

		var intersection = space_state.intersect_point(query)

		if intersection.is_empty():
			if enemy_variations.is_empty():
				return
			var selected_enemy_scene = enemy_variations.pick_random()
			var enemy = selected_enemy_scene.instantiate()
			
			var area_enemys = room_node.find_child("Enemys")
			if area_enemys == null:
				return
			
			area_enemys.add_child(enemy)
			enemy.global_position = global_point
			return 

## Кооп: зачистка комнаты на всех машинах + прогресс только на хосте
func apply_room_cleared_for_network(grid: Vector2i) -> void:
	var room_node: Node2D = null
	for room_data in spawned_rooms:
		if room_data["grid_pos"] == grid:
			room_node = room_data["node"] as Node2D
			break
	if room_node == null:
		return
	var enode := room_node.find_child("Enemys", true, false)
	if enode:
		if enode.has_method("mark_cleared_by_network"):
			enode.mark_cleared_by_network()
		for child in enode.get_children():
			if is_instance_valid(child):
				child.queue_free()
	update_visibility()
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() and mp.is_server():
		GameConstants.on_room_cleared()
		save_dungeon_state()
		NetworkManager.host_publish_dungeon_state()
	else:
		GameConstants.on_room_cleared_clients_sync()


## Кооп: хост рассылает вход в комнату всем (включая вошедшего клиента)
func server_handle_coop_room_enter(grid: Vector2i, entering_peer_id: int) -> void:
	var mp := get_tree().get_multiplayer()
	if not mp.has_multiplayer_peer() or not mp.is_server():
		return
	NetworkManager.rpc_sync_coop_room.rpc(grid.x, grid.y, entering_peer_id)


func apply_coop_room_sync_all(grid: Vector2i, entered_peer_id: int) -> void:
	change_current_room(grid.x, grid.y)
	_move_local_players_to_follow_peer(entered_peer_id, grid)


## Точка для союзника: та же комната по сетке, рядом с лидером, не в коридоре
func get_coop_follower_spawn_global(
	room_grid: Vector2i,
	leader_global: Vector2,
	follower_peer_id: int,
	leader_peer_id: int
) -> Vector2:
	var room_node: Node2D = null
	for room_data in spawned_rooms:
		if room_data["grid_pos"] == room_grid:
			room_node = room_data["node"] as Node2D
			break
	if room_node == null:
		return leader_global + Vector2(48, 0)
	var tl := room_node.global_position
	var margin := 56.0
	var rz := Vector2(GameConstants.MAP_MANAGER_ROOM_SIZE_X, GameConstants.MAP_MANAGER_ROOM_SIZE_Y)
	var offsets: Array[Vector2] = []
	if follower_peer_id < leader_peer_id:
		offsets = [
			Vector2(-56, 0),
			Vector2(56, 0),
			Vector2(0, 56),
			Vector2(0, -56),
			Vector2(-40, 48),
			Vector2(40, -48),
		]
	else:
		offsets = [
			Vector2(56, 0),
			Vector2(-56, 0),
			Vector2(0, 56),
			Vector2(0, -56),
			Vector2(40, 48),
			Vector2(-40, -48),
		]
	for off in offsets:
		var p := leader_global + off
		var cx := clampf(p.x, tl.x + margin, tl.x + rz.x - margin)
		var cy := clampf(p.y, tl.y + margin, tl.y + rz.y - margin)
		var c := Vector2(cx, cy)
		if c.distance_squared_to(leader_global) > 100.0:
			return c
	return Vector2(
		clampf(leader_global.x, tl.x + margin, tl.x + rz.x - margin),
		clampf(leader_global.y, tl.y + margin, tl.y + rz.y - margin)
	)


func _move_local_players_to_follow_peer(entered_peer_id: int, room_grid: Vector2i) -> void:
	var mp := get_tree().get_multiplayer()
	if not mp.has_multiplayer_peer():
		return
	if mp.get_unique_id() == entered_peer_id:
		return
	var leader: Node2D = null
	for n in get_tree().get_nodes_in_group("player"):
		if n is Node2D and n.get_multiplayer_authority() == entered_peer_id:
			leader = n as Node2D
			break
	if leader == null:
		return
	var follower_pid := mp.get_unique_id()
	var target := get_coop_follower_spawn_global(room_grid, leader.global_position, follower_pid, entered_peer_id)
	for n in get_tree().get_nodes_in_group("player"):
		if not n.get("is_local_player"):
			continue
		if n.get_multiplayer_authority() == entered_peer_id:
			continue
		if n is CharacterBody2D:
			var ch := n as CharacterBody2D
			ch.global_position = target
			ch.velocity = Vector2.ZERO
			if n.has_method("flush_network_transform"):
				n.flush_network_transform()


func change_current_room(new_x, new_y):
	var new_pos = Vector2i(new_x, new_y)

	if not visited_rooms.has(new_pos):
		visited_rooms.append(new_pos)

	var directions = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	for dir in directions:
		var neighbor_pos = new_pos + dir
		if is_valid_pos(neighbor_pos) and layout[neighbor_pos.x][neighbor_pos.y] != RoomType.EMPTY:
			if not seen_rooms.has(neighbor_pos):
				seen_rooms.append(neighbor_pos)

	current_room_grid_pos = new_pos
	room_changed.emit(current_room_grid_pos)
	
	update_visibility()
	
	var mp := get_tree().get_multiplayer()
	if not mp.has_multiplayer_peer():
		SaveSystem.save_game()
		save_dungeon_state()
	else:
		for room_data in spawned_rooms:
			if room_data["grid_pos"] == new_pos and room_data["type"] >= 2:
				SaveSystem.save_game()
				save_dungeon_state()
				print("Автосейв: зашли в важную комнату (ID: ", new_pos, ")")
				break

# =====================================================================
# ВОЗВРАТ ИГРОКА В БЕЗОПАСНУЮ КОМНАТУ
# =====================================================================
func get_safe_room_position() -> Vector2i:
	# Ищем старт-комнату на текущем layout (этаже)
	for x in range(GameConstants.MAP_MANAGER_GRID_SIZE):
		for y in range(GameConstants.MAP_MANAGER_GRID_SIZE):
			if layout[x][y] == RoomType.START:
				return Vector2i(x, y)
	# Если по какой-то причине нет старта — возвращаем текущую (fallback)
	return current_room_grid_pos

func teleport_player_to_safe_room():
	var safe_pos = get_safe_room_position()
	print("=== БЕЗОПАСНЫЙ ТЕЛЕПОРТ В КОМНАТУ: ", safe_pos, " ===")
	
	# Принудительно меняем текущую комнату
	current_room_grid_pos = safe_pos
	
	# Перезагружаем комнату (игрок появится в спавне стартовой комнаты)
	change_current_room(safe_pos.x, safe_pos.y)
	
	# Сбрасываем агрессию во всех комнатах (чтобы враги не атаковали сразу)
	_reset_room_aggression()
	
	print("Игрок безопасно перемещён в стартовую комнату")

# =====================================================================
# FOG OF WAR SYSTEM
# =====================================================================

func update_visibility():
	for room_data in spawned_rooms:
		var room_node = room_data["node"] as Node2D
		var room_pos = room_data["grid_pos"]
		
		if room_node:
			# Текущая комната всегда видима
			if room_pos == current_room_grid_pos:
				room_node.modulate = Color(1, 1, 1, 1)
				room_node.visible = true
				_show_room_contents(room_node, true)
			# Зачищенные комнаты видимы навсегда
			elif room_pos in visited_rooms:
				var enemys_node = room_node.find_child("Enemys")
				if enemys_node and enemys_node.get_child_count() == 0:
					room_node.modulate = Color(1, 1, 1, 1)
					room_node.visible = true
					_show_room_contents(room_node, true)
				else:
					room_node.modulate = Color(0, 0, 0, 1)
					room_node.visible = true
					_show_room_contents(room_node, false)
			else:
				room_node.modulate = Color(0, 0, 0, 1)
				room_node.visible = true
				_show_room_contents(room_node, false)

func _show_room_contents(room_node: Node2D, show: bool):
	# Скрываем/показываем врагов
	var enemys_node = room_node.find_child("Enemys")
	if enemys_node:
		for enemy in enemys_node.get_children():
			enemy.visible = show
	
	# Скрываем/показываем артефакты
	for child in room_node.get_children():
		if child.is_in_group("artefact"):
			child.visible = show
		# Также скрываем подставки под артефакты
		if child.name == "ArtefactPedestal" or "pedestal" in child.name.to_lower():
			child.visible = show

func _reset_room_aggression():
	# Прогоняем по всем комнатам и сбрасываем агрессию врагов
	for room_data in spawned_rooms:
		var room_node = room_data["node"]
		var enemys_node = room_node.find_child("Enemys")
		if enemys_node:
			enemys_node.aggression = false
	print("Агрессия во всех комнатах сброшена")

# ДОПОЛНИТЕЛЬНО: Очищает текущую комнату от врагов и ставит игрока в её центр
func respawn_player_in_current_room():
	for room_data in spawned_rooms:
		if room_data["grid_pos"] == current_room_grid_pos:
			var room_node = room_data["node"]
			var enemys_node = room_node.find_child("Enemys")
			
			# Убиваем всех врагов в комнате
			if enemys_node:
				for enemy in enemys_node.get_children():
					if is_instance_valid(enemy):
						enemy.queue_free()
			
			# Ставим игрока в центр комнаты
			var player = get_tree().get_first_node_in_group("player")
			if player:
				var local_center = Vector2(GameConstants.MAP_MANAGER_ROOM_SIZE_X / 2.0, GameConstants.MAP_MANAGER_ROOM_SIZE_Y / 2.0)
				player.global_position = room_node.to_global(local_center)
				print("Игрок респавнится в центре текущей комнаты (враги убиты)")
			break

func save_dungeon_state():
	var dungeon_data = {
		"generation_seed": generation_seed,
		"current_room_pos": {
			"x": current_room_grid_pos.x,
			"y": current_room_grid_pos.y
		},
		"visited_rooms": [],
		"seen_rooms": [],
		"cleared_rooms": [],
		"collected_treasure_rooms": []
	}

	# Сохраняем посещенные комнаты
	for room_pos in visited_rooms:
		dungeon_data["visited_rooms"].append({"x": room_pos.x, "y": room_pos.y})

	# Сохраняем увиденные комнаты
	for room_pos in seen_rooms:
		dungeon_data["seen_rooms"].append({"x": room_pos.x, "y": room_pos.y})

	# Сохраняем зачищенные комнаты (комнаты без врагов)
	for room_data in spawned_rooms:
		var room_node = room_data["node"]
		var enemys_node = room_node.find_child("Enemys")
		if enemys_node and enemys_node.get_child_count() == 0:
			var grid_pos = room_data["grid_pos"]
			dungeon_data["cleared_rooms"].append({"x": grid_pos.x, "y": grid_pos.y})

	# Сохраняем комнаты с собранными сокровищами
	dungeon_data["collected_treasure_rooms"] = SaveSystem.collected_treasure_rooms

	SaveSystem.save_dungeon_data(dungeon_data)
	print("Состояние данжена сохранено (seed: ", generation_seed, ")")

func load_dungeon_state():
	var dungeon_data = SaveSystem.load_dungeon_data()
	if not dungeon_data:
		print("Ошибка загрузки состояния данжена")
		return

	# Восстанавливаем seed и генерируем тот же данжен
	generation_seed = dungeon_data.get("generation_seed", 0)
	seed(generation_seed)
	print("Загружен seed: ", generation_seed)

	# Генерируем данжен с тем же seed
	generate_layout()
	draw_map()
	
	# Восстанавливаем собранные комнаты с сокровищами ПЕРЕД спавном
	if "collected_treasure_rooms" in dungeon_data:
		SaveSystem.collected_treasure_rooms = dungeon_data["collected_treasure_rooms"]
		print("Восстановлено собранных комнат с сокровищами: ", SaveSystem.collected_treasure_rooms.size())
	
	await get_tree().create_timer(0).timeout
	_spawn_player()
	await _spawn_obstacles_after_physics()
	await _spawn_enemies_after_physics()
	_spawn_treasure_items()

	# Восстанавливаем посещенные комнаты
	visited_rooms.clear()
	if "visited_rooms" in dungeon_data:
		for room_pos in dungeon_data["visited_rooms"]:
			if not room_pos is Dictionary:
				continue
			visited_rooms.append(Vector2i(int(room_pos.get("x", 0)), int(room_pos.get("y", 0))))

	# Восстанавливаем увиденные комнаты
	seen_rooms.clear()
	if "seen_rooms" in dungeon_data:
		for room_pos in dungeon_data["seen_rooms"]:
			if not room_pos is Dictionary:
				continue
			seen_rooms.append(Vector2i(int(room_pos.get("x", 0)), int(room_pos.get("y", 0))))

	# Удаляем врагов из зачищенных комнат
	if "cleared_rooms" in dungeon_data:
		for cleared_pos in dungeon_data["cleared_rooms"]:
			if not cleared_pos is Dictionary:
				continue
			var cleared_vec = Vector2i(int(cleared_pos.get("x", 0)), int(cleared_pos.get("y", 0)))
			for room_data in spawned_rooms:
				if room_data["grid_pos"] == cleared_vec:
					var room_node = room_data["node"]
					var enemys_node = room_node.find_child("Enemys")
					if enemys_node:
						for enemy in enemys_node.get_children():
							if is_instance_valid(enemy):
								enemy.queue_free()
					break

	# Очищаем "колоду" предметов, чтобы не было дубликатов
	item_draw_pile.clear()

	# Восстанавливаем текущую комнату
	if "current_room_pos" in dungeon_data:
		var room_pos = dungeon_data["current_room_pos"]
		if room_pos is Dictionary:
			current_room_grid_pos = Vector2i(int(room_pos.get("x", 0)), int(room_pos.get("y", 0)))
		else:
			current_room_grid_pos = get_safe_room_position()
	else:
		current_room_grid_pos = get_safe_room_position()
	
	# В коопе позиции задаёт PlayerManager.finalize_network_spawns — иначе двигаем только одного из get_first_node_in_group("player")
	if not get_tree().get_multiplayer().has_multiplayer_peer():
		var player = get_tree().get_first_node_in_group("player")
		if player:
			if SaveSystem.saved_player_position != Vector2.ZERO:
				# Если позиция сохранена — восстанавливаем
				player.global_position = SaveSystem.saved_player_position
				print("Игрок восстановлен в позиции: ", SaveSystem.saved_player_position)
			else:
				# Если позиция НЕ сохранена — спавним в стартовой комнате (4, 4)
				for room_data in spawned_rooms:
					if room_data["type"] == RoomType.START:
						var room_node = room_data["node"] as Node2D
						player.global_position = get_start_room_spawn_global(room_node)
						print("Игрок спавнится в стартовой комнате")
						break
	
	change_current_room(current_room_grid_pos.x, current_room_grid_pos.y)
	update_visibility()

	print("Состояние данжена восстановлено")


func _physics_process(delta: float) -> void:
	var mp := get_tree().get_multiplayer()
	if not mp.has_multiplayer_peer() or not mp.is_server():
		return
	if mp.get_peers().is_empty():
		return
	_enemy_net_sync_accum += delta
	if _enemy_net_sync_accum < ENEMY_NET_SYNC_INTERVAL:
		return
	_enemy_net_sync_accum = 0.0
	# Только тело врага: в группе «enemys» ошибочно бывают hitbox/таймеры/спрайты — ломали путь и забивали unreliable RPC.
	for n in get_tree().get_nodes_in_group("enemys"):
		if not is_instance_valid(n) or not n is CharacterBody2D:
			continue
		if GameConstants.variant_to_bool(n.get("is_dead")):
			continue
		var ch := n as CharacterBody2D
		var vel := ch.velocity
		NetworkManager.rpc_sync_enemy_transform.rpc(str(ch.get_path()), ch.global_position, vel)
