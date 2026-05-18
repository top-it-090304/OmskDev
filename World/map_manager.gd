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
const FLOOR1_GOBLIN_AXE := preload("res://scene/game_objects/enemy/goblin_axe/enemy(goblin_axe).tscn")
const FLOOR1_GOBLIN_SLINGER := preload("res://scene/game_objects/enemy/goblin_slinger/goblin_slinger.tscn")
const FLOOR1_BEAST_GOBLIN := preload("res://scene/game_objects/bosses/goblin/beastGoblin.tscn")
const FLOOR1_GOBLIN_RAIDER := preload("res://scene/game_objects/bosses/govlinRaider/goblinRider.tscn")
const FLOOR2_MAGICAN := preload("res://scene/game_objects/enemy/magican/magican.tscn")
const FLOOR2_MAN_STICK := preload("res://scene/game_objects/enemy/manStick/man_stick.tscn")
const FLOOR2_SKELETON_SWORDMAN := preload("res://scene/game_objects/bosses/skeletonSwordman/skeleton_swordman.tscn")
const FLOOR3_SKELETON_GRUNT := preload("res://scene/game_objects/enemy/skeleton_grunt/enemy(skeleton_grunt).tscn")
const FLOOR3_SKELETON_BOW := preload("res://scene/game_objects/enemy/skeleton_bow/skeleton_bow.tscn")
const FLOOR3_SKELETON_KING := preload("res://scene/game_objects/bosses/skeleton_king/skeleton_king.tscn")
const DEFAULT_TREASURE_ITEM_PATHS: Array[String] = [
	"res://scene/pick_up/artefacts/artefact(boots_of_travel).tscn",
	"res://scene/pick_up/artefacts/blue_shroom.tscn",
	"res://scene/pick_up/artefacts/bottle.tscn",
	"res://scene/pick_up/artefacts/coffee_mug.tscn",
	"res://scene/pick_up/artefacts/red_potion.tscn",
]
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
var current_room_grid_pos = Vector2i(int(GameConstants.MAP_MANAGER_GRID_SIZE / 2.0), int(GameConstants.MAP_MANAGER_GRID_SIZE / 2.0))
signal room_changed(new_grid_pos)
var visited_rooms = []
var seen_rooms = []

## Уровень детализации препятствий для текущего сеанса данжа (после спавна камней).
var _dungeon_obstacle_detail_used: int = -1
## При загрузке save / sync с хоста — переопределить на время спавна препятствий (-1 = нет).
var _obstacle_detail_spawn_override: int = -1

var _enemy_net_sync_accum: float = 0.0
## На сервере: peer_id -> последняя клетка комнаты (для sync врагов, когда игроки в разных комнатах).
var _coop_peer_last_room_grid: Dictionary = {}
## Частый batch нужен клиенту, иначе враги визуально ползут к устаревшей позиции.
const ENEMY_NET_SYNC_INTERVAL: float = 0.06
const _ENEMY_NET_SYNC_NEIGHBORS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
]
const _NET_SYNC_POS_EPS2: float = 4.0
const _NET_SYNC_VEL_EPS2: float = 64.0
const ENEMY_STATE_KEY := "enemy_spawns"
const TREASURE_STATE_KEY := "treasure_spawns"
const USED_ARTEFACT_STATE_KEY := "used_artefact_scene_paths"


func _ready() -> void:
	add_to_group("map_manager")
	if NetworkManager.is_game_online():
		set_multiplayer_authority(NetworkManager.SERVER_ID)
	get_tree().auto_accept_quit = false  # Перехватываем попытки выхода
	_apply_floor_enemy_pools()

	if start_room_variations.is_empty() or normal_room_variations.is_empty() or boss_room_variations.is_empty():
		push_error("ОШИБКА: Добавь хотя бы по одной сцене для Start, Normal и Boss комнат!")
		return

	call_deferred("_boot_dungeon_async")


func _apply_floor_enemy_pools() -> void:
	match GameConstants.CURRENT_FLOOR:
		1:
			enemy_variations = [FLOOR1_GOBLIN_AXE, FLOOR1_GOBLIN_SLINGER]
			boss_variations = [FLOOR1_BEAST_GOBLIN, FLOOR1_GOBLIN_RAIDER]
		2:
			enemy_variations = [FLOOR2_MAN_STICK, FLOOR2_MAGICAN]
			boss_variations = [FLOOR2_SKELETON_SWORDMAN]
		_:
			enemy_variations = [FLOOR3_SKELETON_GRUNT, FLOOR3_SKELETON_BOW]
			boss_variations = [FLOOR3_SKELETON_KING]


func _client_retry_finalize_if_needed() -> void:
	if not NetworkManager.is_multiplayer_active() or NetworkManager.is_hosting():
		return
	if PlayerManager.network_spawn_finalize_done:
		return
	push_warning("MapManager: клиент — повторный finalize_network_spawns (после сбоя загрузки данжа?)")
	if not SaveSystem.has_dungeon_state():
		return
	await PlayerManager.finalize_network_spawns()


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
		if not SaveSystem.has_dungeon_state():
			push_error("MapManager: клиент так и не получил dungeon_state")
			return
		await load_dungeon_state()
		await PlayerManager.finalize_network_spawns()
		# Если load_dungeon_state упал по ошибке, finalize не отработал — повтор через несколько секунд
		var retry_t := get_tree().create_timer(3.0)
		retry_t.timeout.connect(_client_retry_finalize_if_needed, CONNECT_ONE_SHOT)
		return

	if SaveSystem.has_dungeon_state():
		print("=== ЗАГРУЗКА СОХРАНЕННОГО ДАНЖЕНА ===")
		await load_dungeon_state()
	else:
		print("=== ГЕНЕРАЦИЯ НОВОГО ДАНЖЕНА ===")
		GameConstants.clear_used_artefact_scene_paths()
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
		_reset_coop_peer_room_grid_track()

		save_dungeon_state()

	if NetworkManager.is_multiplayer_active() and NetworkManager.is_hosting():
		NetworkManager.host_publish_dungeon_state()

	await PlayerManager.finalize_network_spawns()
	if NetworkManager.is_multiplayer_active() and NetworkManager.is_hosting():
		PlayerManager.host_authoritative_floor_spawn_sync()


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
		if NetworkManager.is_game_online() and NetworkManager.is_server():
			var peers := get_tree().get_multiplayer().get_peers()
			if not peers.is_empty():
				NetworkManager.rpc_notify_session_ended.rpc()
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

	var Player = PlayerManager.get_selected_player_scene().instantiate()
	layer.add_child(Player)
	if Player.has_method("_ensure_alive_spawn_state"):
		Player.call("_ensure_alive_spawn_state")

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
func _treasure_rng_seed() -> int:
	return int(generation_seed) ^ 0x5472454C  # "TREL"


func _cmp_room_grid(a: Dictionary, b: Dictionary) -> bool:
	var pa: Vector2i = a["grid_pos"]
	var pb: Vector2i = b["grid_pos"]
	if pa.x != pb.x:
		return pa.x < pb.x
	return pa.y < pb.y


func _shuffle_packed_scenes(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _sorted_treasure_rooms() -> Array:
	var rooms: Array = []
	for room_data in spawned_rooms:
		if room_data["type"] == RoomType.TREASURE:
			rooms.append(room_data)
	rooms.sort_custom(_cmp_room_grid)
	return rooms


func _spawn_treasure_in_room(room_data: Dictionary, item_scene: PackedScene) -> void:
	if item_scene == null:
		return
	var room_pos: Vector2i = room_data["grid_pos"]
	if SaveSystem.is_treasure_collected(room_pos):
		return
	var room_node: Node = room_data["node"]
	var item_instance = item_scene.instantiate()
	room_node.add_child(item_instance)
	item_instance.add_to_group("artefact")
	GameConstants.remember_artefact_scene_path(str(item_scene.resource_path))
	item_instance.set_meta("_treasure_room_grid", room_pos)
	var local_center := Vector2(
		GameConstants.MAP_MANAGER_ROOM_SIZE_X / 2.0,
		GameConstants.MAP_MANAGER_ROOM_SIZE_Y / 2.0
	)
	var world_pos: Vector2 = (room_node as Node2D).to_global(local_center)
	item_instance.global_position = world_pos + Vector2(0, -10)
	var pedestal_scene := preload("res://scene/pick_up/artefacts/artefact_pedestal.tscn")
	var pedestal := pedestal_scene.instantiate()
	room_node.add_child(pedestal)
	pedestal.global_position = world_pos
	pedestal.z_index = -1


func _build_treasure_item_paths() -> Array[String]:
	var paths: Array[String] = []
	for item_scene in treasure_items:
		if item_scene == null:
			continue
		var path := str((item_scene as PackedScene).resource_path)
		if not path.is_empty() and not paths.has(path):
			paths.append(path)
	if not paths.is_empty():
		return paths
	for scene_path in DEFAULT_TREASURE_ITEM_PATHS:
		if not paths.has(scene_path):
			paths.append(scene_path)
	return paths


func _spawn_treasure_items() -> void:
	var item_paths := _build_treasure_item_paths()
	if item_paths.is_empty():
		return
	for room_data in _sorted_treasure_rooms():
		var scenes := GameConstants.get_unique_artefact_scenes_from_paths(item_paths, 1, true)
		if scenes.is_empty():
			break
		_spawn_treasure_in_room(room_data, scenes[0])


func _collect_treasure_spawn_state() -> Array:
	var out: Array = []
	for room_data in spawned_rooms:
		if room_data["type"] != RoomType.TREASURE:
			continue
		var room_pos: Vector2i = room_data["grid_pos"]
		if SaveSystem.is_treasure_collected(room_pos):
			continue
		var room_node: Node = room_data["node"]
		for c in room_node.get_children():
			if not c.has_method("server_run_pickup_effects"):
				continue
			var sp := str(c.scene_file_path)
			if sp == "":
				continue
			out.append({
				"room": {"x": room_pos.x, "y": room_pos.y},
				"scene": sp,
			})
			break
	return out


func _spawn_treasures_from_state(spawns: Array) -> void:
	for raw in spawns:
		if not raw is Dictionary:
			continue
		var spec := raw as Dictionary
		var room_raw: Variant = spec.get("room", {})
		if not room_raw is Dictionary:
			continue
		var grid_pos := Vector2i(int(room_raw.get("x", 0)), int(room_raw.get("y", 0)))
		if SaveSystem.is_treasure_collected(grid_pos):
			continue
		var room_data := _get_room_data_by_grid(grid_pos)
		if room_data.is_empty():
			continue
		var scene_path := str(spec.get("scene", ""))
		var item_scene := load(scene_path) as PackedScene
		if item_scene == null:
			push_warning("MapManager: не удалось загрузить артефакт: " + scene_path)
			continue
		_spawn_treasure_in_room(room_data, item_scene)

# --- Генерация скелета ---
func generate_layout():
	layout = []
	for x in range(GameConstants.MAP_MANAGER_GRID_SIZE):
		layout.append([])
		for y in range(GameConstants.MAP_MANAGER_GRID_SIZE):
			layout[x].append(RoomType.EMPTY)

	var start_pos = Vector2i(int(GameConstants.MAP_MANAGER_GRID_SIZE / 2.0), int(GameConstants.MAP_MANAGER_GRID_SIZE / 2.0))
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
		
		# Проверяем все 4 стороны случайно выбранной комнаты
		for dir in directions:
			var new_pos = rand_room + dir
			
			# Если нашли пустое место — ставим сокровищницу
			if is_valid_pos(new_pos) and layout[new_pos.x][new_pos.y] == RoomType.EMPTY:
				layout[new_pos.x][new_pos.y] = RoomType.TREASURE
				treasures_placed += 1
				break # Место нашли, дальше эту комнату не проверяем

func is_valid_pos(pos):
	return pos.x >= 0 and pos.x < GameConstants.MAP_MANAGER_GRID_SIZE and pos.y >= 0 and pos.y < GameConstants.MAP_MANAGER_GRID_SIZE


func _layout_room_type_at(gx: int, gy: int) -> int:
	if layout.is_empty():
		return RoomType.EMPTY
	if gx < 0 or gx >= layout.size():
		return RoomType.EMPTY
	var col: Variant = layout[gx]
	if not col is Array:
		return RoomType.EMPTY
	var row: Array = col as Array
	if gy < 0 or gy >= row.size():
		return RoomType.EMPTY
	return int(row[gy])


func get_random_room_of_type(type):
	var valid_rooms = []
	for x in range(GameConstants.MAP_MANAGER_GRID_SIZE):
		for y in range(GameConstants.MAP_MANAGER_GRID_SIZE):
			if _layout_room_type_at(x, y) == type: valid_rooms.append(Vector2i(x, y))
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
	
	var offset_x = -(GameConstants.MAP_MANAGER_GRID_SIZE * cell_size_x) / 2.0
	var offset_y = -(GameConstants.MAP_MANAGER_GRID_SIZE * cell_size_y) / 2.0

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
				var room_instance = selected_room_scene.instantiate() 
				
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
					corr.position.y = room_pos.y + (GameConstants.MAP_MANAGER_ROOM_SIZE_Y / 2.0) - (GameConstants.MAP_MANAGER_CORRIDOR_LENGTH / 2.0)
					add_child(corr)
				
				if has_bottom:
					var corr = corridor_v_scene.instantiate()
					corr.position.x = room_pos.x + (GameConstants.MAP_MANAGER_ROOM_SIZE_X / 2.0) - (GameConstants.MAP_MANAGER_CORRIDOR_LENGTH / 2.0)
					corr.position.y = room_pos.y + GameConstants.MAP_MANAGER_ROOM_SIZE_Y
					add_child(corr)

func check_neighbor(nx, ny):
	if is_valid_pos(Vector2i(nx, ny)):
		return layout[nx][ny] != RoomType.EMPTY
	return false

# =====================================================================
# СПАВН ПРЕПЯТСТВИЙ
# =====================================================================

func _spawn_obstacles_in_room(room_node: Node2D, room_type: RoomType, detail_level: int) -> void:
	if room_type == RoomType.BOSS or room_type == RoomType.START or room_type == RoomType.TREASURE or room_type == RoomType.EMPTY:
		return
		
	if obstacle_data.is_empty():
		return
	var n_obstacles := obstacle_data.size()

	var container = room_node.find_child("Obstacles")
	if container == null:
		return

	var gx := 0
	var gy := 0
	if room_node :
		var rb := room_node
		gx = rb.grid_x
		gy = rb.grid_y
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(generation_seed) + "|obst|" + str(gx) + "," + str(gy))

	var type_of_room: int = rng.randi_range(1, 3)
	var obstacle_count: int = 0
	match type_of_room:
		1:
			obstacle_count = rng.randi_range(0, 5)
		2:
			obstacle_count = rng.randi_range(3, 8)
		3:
			obstacle_count = rng.randi_range(10, 15)

	match clampi(detail_level, 0, 2):
		0:
			obstacle_count = 0
		1:
			obstacle_count = int(obstacle_count / 2.0)
		_:
			pass
		
	var space_state = get_world_2d().direct_space_state
	var spawned_rects: Array[Rect2] = []
	var blocked_rects := _get_room_door_block_rects(room_node)
	var padding = 8.0 

	for _i in range(obstacle_count):
		var data: Dictionary
		match type_of_room:
			1:
				data = obstacle_data[0]
			2:
				if n_obstacles >= 3:
					data = obstacle_data[1] if rng.randi_range(0, 1) == 0 else obstacle_data[2]
				else:
					data = obstacle_data[mini(1, n_obstacles - 1)]
			3:
				if n_obstacles >= 6:
					var r: int = rng.randi_range(0, 2)
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
			var local_x = rng.randf_range(half_size.x + 64, GameConstants.MAP_MANAGER_ROOM_SIZE_X - half_size.x - 64)
			var local_y = rng.randf_range(half_size.y + 64, GameConstants.MAP_MANAGER_ROOM_SIZE_Y - half_size.y - 64)
			var local_pos = Vector2(local_x, local_y)
			var global_pos = room_node.to_global(local_pos)
			
			params.transform = Transform2D(0, global_pos) 
			
			var wall_hits = space_state.intersect_shape(params)
			if not wall_hits.is_empty():
				continue
				
			var new_rect = Rect2(global_pos - half_size, size).grow(padding)
			if _rect_overlaps_any(new_rect, blocked_rects):
				continue
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


func _get_room_door_block_rects(room_node: Node2D) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if room_node == null:
		return rects

	var door_width := 168.0
	var door_depth := 128.0
	var room_w := float(GameConstants.MAP_MANAGER_ROOM_SIZE_X)
	var room_h := float(GameConstants.MAP_MANAGER_ROOM_SIZE_Y)

	var top := room_node.get_node_or_null("DoorTop") as Node2D
	if top != null:
		rects.append(_local_rect_to_global(room_node, Rect2(top.position.x - door_width * 0.5, 0.0, door_width, door_depth)))

	var bottom := room_node.get_node_or_null("DoorBottom") as Node2D
	if bottom != null:
		rects.append(_local_rect_to_global(room_node, Rect2(bottom.position.x - door_width * 0.5, room_h - door_depth, door_width, door_depth)))

	var left := room_node.get_node_or_null("DoorLeft") as Node2D
	if left != null:
		rects.append(_local_rect_to_global(room_node, Rect2(0.0, left.position.y - door_width * 0.5, door_depth, door_width)))

	var right := room_node.get_node_or_null("DoorRight") as Node2D
	if right != null:
		rects.append(_local_rect_to_global(room_node, Rect2(room_w - door_depth, right.position.y - door_width * 0.5, door_depth, door_width)))

	return rects


func _local_rect_to_global(node: Node2D, rect: Rect2) -> Rect2:
	return Rect2(node.to_global(rect.position), rect.size)


func _rect_overlaps_any(rect: Rect2, others: Array[Rect2]) -> bool:
	for other in others:
		if rect.intersects(other):
			return true
	return false

func _spawn_obstacles_after_physics() -> void:
	await get_tree().physics_frame 
	var detail_level: int = GameConstants.OBSTACLE_DETAIL_LEVEL
	if _obstacle_detail_spawn_override >= 0:
		detail_level = clampi(_obstacle_detail_spawn_override, 0, 2)
	_dungeon_obstacle_detail_used = detail_level
	for room_data in spawned_rooms:
		_spawn_obstacles_in_room(room_data["node"], room_data["type"], detail_level)

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
		
		if room_type==RoomType.NORMAL:
			enemy_count = randi_range(2, 5)
			if NetworkManager.is_game_online():
				enemy_count = ceili(float(enemy_count) * 1.5)
		
		if room_type==RoomType.BOSS: 
			_spawn_boss(space_state, room_node)
			continue
			
		var slot_idx := 0
		for _i in range(enemy_count):
			_spawn_single_enemy(space_state, room_node, slot_idx)
			slot_idx += 1
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
		var pool: Array[PackedScene] = []
		for s: PackedScene in boss_variations:
			if s != null:
				pool.append(s)
		if pool.is_empty():
			return
		# Два босса: не повторять того же, что на прошлом этаже (случайный порядок между ними).
		if pool.size() > 1 and SaveSystem.last_spawned_boss_scene_path != "":
			var last_path := SaveSystem.last_spawned_boss_scene_path
			var filtered: Array[PackedScene] = []
			for s: PackedScene in pool:
				if s.resource_path != last_path:
					filtered.append(s)
			if not filtered.is_empty():
				pool = filtered
		var selected_boss_scene: PackedScene = pool.pick_random()
		SaveSystem.last_spawned_boss_scene_path = selected_boss_scene.resource_path

		var boss = selected_boss_scene.instantiate()
		_set_spawned_enemy_identity(boss, 0, true)
		_assign_enemy_net_identity(boss, room_node as Node2D, 0, true)
		
		var area_enemys = room_node.find_child("Enemys")
		if area_enemys == null:
			return
		
		area_enemys.add_child(boss)
		boss.global_position = global_point
		# Люк в геометрическом центре комнаты босса (локальные координаты комнаты)
		_ensure_boss_hatch(room_node)
		return


func _ensure_boss_hatch(room_node: Node2D) -> void:
	if room_node == null:
		return
	if boss_hatch != null and is_instance_valid(boss_hatch):
		boss_hatch.queue_free()
		boss_hatch = null
	var hatch_inst := HATCH_SCENE.instantiate() as Area2D
	room_node.add_child(hatch_inst)
	hatch_inst.position = Vector2(
		GameConstants.MAP_MANAGER_ROOM_SIZE_X / 2.0,
		GameConstants.MAP_MANAGER_ROOM_SIZE_Y / 2.0
	)
	boss_hatch = hatch_inst
	if SaveSystem.is_boss_hatch_opened() and hatch_inst.has_method("apply_save_open_state"):
		hatch_inst.apply_save_open_state()


func open_boss_hatch() -> void:
	apply_boss_hatch_opened_visual()
	if NetworkManager.is_game_offline():
		return
	var mp := get_tree().get_multiplayer()
	if mp.is_server():
		NetworkManager.rpc_boss_hatch_open_to_peers.rpc()
	else:
		NetworkManager.rpc_request_server_boss_hatch_open.rpc_id(NetworkManager.SERVER_ID)


func apply_boss_hatch_opened_visual() -> void:
	if boss_hatch != null and is_instance_valid(boss_hatch) and boss_hatch.has_method("apply_hatch_open_visual"):
		boss_hatch.apply_hatch_open_visual()
	SaveSystem.set_boss_hatch_opened(true)


func _ensure_saved_open_boss_hatch() -> void:
	if boss_hatch != null and is_instance_valid(boss_hatch):
		if boss_hatch.has_method("apply_save_open_state"):
			boss_hatch.apply_save_open_state()
		return
	for room_data in spawned_rooms:
		if room_data.get("type", RoomType.EMPTY) != RoomType.BOSS:
			continue
		var room_node := room_data.get("node") as Node2D
		if room_node == null or not is_instance_valid(room_node):
			continue
		_ensure_boss_hatch(room_node)
		return


func _spawn_single_enemy_online_deterministic(room_node: Node2D, slot_idx: int) -> void:
	if enemy_variations.is_empty():
		return
	var gx := 0
	var gy := 0
	if room_node:
		var rb := room_node 
		gx = rb.grid_x
		gy = rb.grid_y
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(generation_seed) + "|e_sp|" + str(gx) + "," + str(gy) + "|" + str(slot_idx))
	var area_enemys := room_node.find_child("Enemys", true, false)
	if area_enemys == null:
		return
	var idx: int = rng.randi() % enemy_variations.size()
	var selected_enemy_scene: PackedScene = enemy_variations[idx]
	var enemy := selected_enemy_scene.instantiate()
	_set_spawned_enemy_identity(enemy, slot_idx)
	_assign_enemy_net_identity(enemy, room_node, slot_idx)
	var margin := 80.0
	var rx: float = float(GameConstants.MAP_MANAGER_ROOM_SIZE_X) - 2.0 * margin
	var ry: float = float(GameConstants.MAP_MANAGER_ROOM_SIZE_Y) - 2.0 * margin
	var u := rng.randf()
	var v := rng.randf()
	var local_point := Vector2(margin + u * rx, margin + v * ry)
	var global_point := room_node.to_global(local_point)
	area_enemys.add_child(enemy)
	enemy.global_position = global_point


func _spawn_single_enemy(space_state, room_node, slot_idx: int = 0) -> void:
	if NetworkManager.is_game_online():
		_spawn_single_enemy_online_deterministic(room_node as Node2D, slot_idx)
		return
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
			_set_spawned_enemy_identity(enemy, slot_idx)
			_assign_enemy_net_identity(enemy, room_node as Node2D, slot_idx)
			
			var area_enemys = room_node.find_child("Enemys")
			if area_enemys == null:
				return
			
			area_enemys.add_child(enemy)
			enemy.global_position = global_point
			return 


func _set_spawned_enemy_identity(enemy: Node, slot_idx: int, is_boss: bool = false) -> void:
	if enemy == null:
		return
	enemy.name = ("%s_%02d" % ["Boss" if is_boss else "Enemy", slot_idx])
	enemy.set_meta(&"_spawn_slot", slot_idx)


func _enemy_net_key(room_grid: Vector2i, slot_idx: int) -> String:
	return "%d,%d:%d" % [room_grid.x, room_grid.y, slot_idx]


func _assign_enemy_net_identity(enemy: Node, room_node: Node2D, slot_idx: int, is_boss: bool = false) -> void:
	if enemy == null or room_node == null:
		return
	var room_grid := Vector2i(int(room_node.get("grid_x")), int(room_node.get("grid_y")))
	enemy.set_meta(&"_spawn_slot", slot_idx)
	enemy.set_meta(&"_spawn_room", room_grid)
	enemy.set_meta(&"_net_enemy_key", _enemy_net_key(room_grid, slot_idx))
	enemy.set_meta(&"_is_boss_spawn", is_boss)


func get_enemy_by_net_key(enemy_key: String) -> Node:
	if enemy_key.is_empty():
		return null
	for room_data in spawned_rooms:
		var room_node := room_data.get("node") as Node2D
		if room_node == null or not is_instance_valid(room_node):
			continue
		var enemys_node := room_node.find_child("Enemys", true, false)
		if enemys_node == null:
			continue
		for enemy in enemys_node.get_children():
			if is_instance_valid(enemy) and str(enemy.get_meta(&"_net_enemy_key", "")) == enemy_key:
				return enemy
	return null

## Кооп: зачистка комнаты на всех машинах + прогресс только на хосте
func apply_room_cleared_for_network(grid: Vector2i) -> void:
	var room_node: Node2D = null
	for room_data in spawned_rooms:
		if room_data["grid_pos"] == grid:
			room_node = room_data["node"] as Node2D
			break
	if room_node == null:
		return
	var mp := get_tree().get_multiplayer()
	var enode := room_node.find_child("Enemys", true, false)
	if enode:
		if enode.has_method("mark_cleared_by_network"):
			enode.mark_cleared_by_network()
		for child in enode.get_children():
			if not is_instance_valid(child):
				continue
			# На хосте босс в коопе: is_dead=true уже в начале death(), но люк/лут — после await.
			# Раньше queue_free здесь убивал узел до конца death() → без люка и артефакта.
			if child.is_in_group("boss") and NetworkManager.is_game_online() and mp.is_server():
				continue
			child.queue_free()
	update_visibility()
	if NetworkManager.is_game_online() and mp.is_server():
		GameConstants.on_room_cleared()
		save_dungeon_state()
		NetworkManager.host_publish_dungeon_state()
	else:
		GameConstants.on_room_cleared_clients_sync()


## Кооп: хост рассылает вход в комнату всем (включая вошедшего клиента)
func server_handle_coop_room_enter(grid: Vector2i, entering_peer_id: int) -> void:
	var mp := get_tree().get_multiplayer()
	if NetworkManager.is_game_offline() or not mp.is_server():
		return
	_coop_peer_last_room_grid[entering_peer_id] = grid
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
	if NetworkManager.is_game_offline():
		return
	var mp := get_tree().get_multiplayer()
	if mp.get_unique_id() == entered_peer_id:
		return
	var leader: Node2D = _find_player_node_by_authority(entered_peer_id)
	if leader == null:
		_follow_coop_when_leader_ready(entered_peer_id, room_grid, 20)
		return
	_apply_follow_positions_for_local_players(entered_peer_id, room_grid, leader)


func _find_player_node_by_authority(peer_id: int) -> Node2D:
	for n in get_tree().get_nodes_in_group("player"):
		if n is Node2D and int(n.get_multiplayer_authority()) == int(peer_id):
			return n as Node2D
	return null


func _follow_coop_when_leader_ready(entered_peer_id: int, room_grid: Vector2i, attempts: int) -> void:
	if attempts <= 0:
		return
	await get_tree().process_frame
	if NetworkManager.is_game_offline():
		return
	var mp := get_tree().get_multiplayer()
	if mp.get_unique_id() == entered_peer_id:
		return
	var leader: Node2D = _find_player_node_by_authority(entered_peer_id)
	if leader == null:
		_follow_coop_when_leader_ready(entered_peer_id, room_grid, attempts - 1)
		return
	_apply_follow_positions_for_local_players(entered_peer_id, room_grid, leader)


func _apply_follow_positions_for_local_players(entered_peer_id: int, room_grid: Vector2i, leader: Node2D) -> void:
	var mp := get_tree().get_multiplayer()
	var follower_pid := mp.get_unique_id()
	var target := get_coop_follower_spawn_global(room_grid, leader.global_position, follower_pid, entered_peer_id)
	for n in get_tree().get_nodes_in_group("player"):
		if not n.get("is_local_player"):
			continue
		if int(n.get_multiplayer_authority()) == int(entered_peer_id):
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
		if is_valid_pos(neighbor_pos) and _layout_room_type_at(neighbor_pos.x, neighbor_pos.y) != RoomType.EMPTY:
			if not seen_rooms.has(neighbor_pos):
				seen_rooms.append(neighbor_pos)

	current_room_grid_pos = new_pos
	room_changed.emit(current_room_grid_pos)
	
	update_visibility()
	
	var mp := get_tree().get_multiplayer()
	if NetworkManager.is_game_offline():
		SaveSystem.save_game()
		save_dungeon_state()
	elif mp.is_server():
		for room_data in spawned_rooms:
			if room_data["grid_pos"] == new_pos and room_data["type"] >= 2:
				SaveSystem.save_game()
				save_dungeon_state()
				NetworkManager.host_publish_dungeon_state()
				print("Автосейв: зашли в важную комнату (ID: ", new_pos, ")")
				break


func get_current_room_node() -> Node2D:
	for room_data in spawned_rooms:
		if room_data["grid_pos"] == current_room_grid_pos:
			return room_data["node"] as Node2D
	return null


func is_world_position_in_current_room(world_pos: Vector2, margin: float = 0.0) -> bool:
	var room_node := get_current_room_node()
	if room_node == null or not is_instance_valid(room_node):
		return true
	var local_pos := room_node.to_local(world_pos)
	return local_pos.x >= margin \
		and local_pos.y >= margin \
		and local_pos.x <= float(GameConstants.MAP_MANAGER_ROOM_SIZE_X) - margin \
		and local_pos.y <= float(GameConstants.MAP_MANAGER_ROOM_SIZE_Y) - margin

# =====================================================================
# ВОЗВРАТ ИГРОКА В БЕЗОПАСНУЮ КОМНАТУ
# =====================================================================
func get_safe_room_position() -> Vector2i:
	# Ищем старт-комнату на текущем layout (этаже)
	for x in range(GameConstants.MAP_MANAGER_GRID_SIZE):
		for y in range(GameConstants.MAP_MANAGER_GRID_SIZE):
			if _layout_room_type_at(x, y) == RoomType.START:
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
			if room_pos == current_room_grid_pos:
				room_node.modulate = Color(1, 1, 1, 1)
				room_node.visible = true
				_show_room_contents(room_node, true)
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

func _show_room_contents(room_node: Node2D, contents_visible: bool):
	# Скрываем/показываем врагов. ВНИМАНИЕ: не выключаем process_mode — клиенту в коопе нужен
	# physics_process для интерполяции позиций по RPC от хоста, иначе враги «зависают» на клиенте.
	var enemys_node = room_node.find_child("Enemys")
	if enemys_node:
		for enemy in enemys_node.get_children():
			enemy.visible = contents_visible
	
	# Скрываем/показываем артефакты
	for child in room_node.get_children():
		if child.is_in_group("artefact") or child.has_method("server_run_pickup_effects"):
			child.visible = contents_visible
		# Также скрываем подставки под артефакты
		if child.name == "ArtefactPedestal" or "pedestal" in child.name.to_lower():
			child.visible = contents_visible

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
		# Геометрия этажа — у гостя после sync должен совпасть размер сетки с хостом (иначе layout[x][y] и миникарта падают на индексе вроде 5).
		"map_grid_size": GameConstants.MAP_MANAGER_GRID_SIZE,
		"map_room_size_x": GameConstants.MAP_MANAGER_ROOM_SIZE_X,
		"map_room_size_y": GameConstants.MAP_MANAGER_ROOM_SIZE_Y,
		"map_corridor_length": GameConstants.MAP_MANAGER_CORRIDOR_LENGTH,
		"obstacle_detail": (_dungeon_obstacle_detail_used if _dungeon_obstacle_detail_used >= 0 else GameConstants.clamp_obstacle_detail_level(GameConstants.OBSTACLE_DETAIL_LEVEL)),
		"current_room_pos": {
			"x": current_room_grid_pos.x,
			"y": current_room_grid_pos.y
		},
		"visited_rooms": [],
		"seen_rooms": [],
		"cleared_rooms": [],
		"collected_treasure_rooms": [],
		"boss_hatch_opened": SaveSystem.is_boss_hatch_opened(),
		TREASURE_STATE_KEY: [],
		ENEMY_STATE_KEY: [],
		USED_ARTEFACT_STATE_KEY: []
	}

	# Сохраняем посещенные комнаты
	for room_pos in visited_rooms:
		dungeon_data["visited_rooms"].append({"x": room_pos.x, "y": room_pos.y})

	# Сохраняем увиденные комнаты	у
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
	dungeon_data[TREASURE_STATE_KEY] = _collect_treasure_spawn_state()
	dungeon_data[ENEMY_STATE_KEY] = _collect_enemy_spawn_state()
	dungeon_data[USED_ARTEFACT_STATE_KEY] = GameConstants.get_used_artefact_scene_paths()

	SaveSystem.save_dungeon_data(dungeon_data)
	print("Состояние данжена сохранено (seed: ", generation_seed, ")")


func _collect_enemy_spawn_state() -> Array:
	var out: Array = []
	for room_data in spawned_rooms:
		var room_node := room_data.get("node") as Node2D
		if room_node == null or not is_instance_valid(room_node):
			continue
		var enemys_node := room_node.find_child("Enemys", true, false)
		if enemys_node == null:
			continue
		var grid_pos: Vector2i = room_data["grid_pos"]
		for enemy in enemys_node.get_children():
			if not is_instance_valid(enemy) or not enemy is Node2D:
				continue
			if GameConstants.variant_to_bool(enemy.get("is_dead")):
				continue
			var slot_idx := int(enemy.get_meta(&"_spawn_slot", 0))
			var scene_path := str(enemy.scene_file_path)
			if scene_path == "":
				continue
			var local_pos := room_node.to_local((enemy as Node2D).global_position)
			out.append({
				"scene": scene_path,
				"room": {"x": grid_pos.x, "y": grid_pos.y},
				"local_pos": {"x": local_pos.x, "y": local_pos.y},
				"slot": slot_idx,
				"name": str(enemy.name),
				"is_boss": room_data["type"] == RoomType.BOSS
			})
	return out


func _get_room_data_by_grid(grid_pos: Vector2i) -> Dictionary:
	for room_data in spawned_rooms:
		if room_data["grid_pos"] == grid_pos:
			return room_data
	return {}


func _spawn_enemies_from_state(enemy_spawns: Array) -> void:
	for raw in enemy_spawns:
		if not raw is Dictionary:
			continue
		var spec := raw as Dictionary
		var room_raw: Variant = spec.get("room", {})
		var local_raw: Variant = spec.get("local_pos", {})
		if not room_raw is Dictionary or not local_raw is Dictionary:
			continue
		var grid_pos := Vector2i(int(room_raw.get("x", 0)), int(room_raw.get("y", 0)))
		var room_data := _get_room_data_by_grid(grid_pos)
		if room_data.is_empty():
			continue
		var room_node := room_data.get("node") as Node2D
		if room_node == null:
			continue
		var enemys_node := room_node.find_child("Enemys", true, false)
		if enemys_node == null:
			continue
		var scene_path := str(spec.get("scene", ""))
		var slot_idx := int(spec.get("slot", enemys_node.get_child_count()))
		var is_boss := GameConstants.variant_to_bool(spec.get("is_boss", room_data["type"] == RoomType.BOSS))
		if is_boss:
			scene_path = _resolve_saved_boss_scene_path(scene_path, slot_idx)
		else:
			scene_path = _resolve_saved_enemy_scene_path(scene_path, slot_idx)
		var enemy_scene := load(scene_path) as PackedScene
		if enemy_scene == null:
			push_warning("MapManager: не удалось загрузить врага из dungeon_state: " + scene_path)
			continue
		var enemy := enemy_scene.instantiate()
		_set_spawned_enemy_identity(enemy, slot_idx, is_boss)
		_assign_enemy_net_identity(enemy, room_node, slot_idx, is_boss)
		var saved_name := str(spec.get("name", ""))
		if saved_name != "":
			enemy.name = saved_name
		enemys_node.add_child(enemy)
		var local_pos := Vector2(float(local_raw.get("x", 0.0)), float(local_raw.get("y", 0.0)))
		(enemy as Node2D).global_position = room_node.to_global(local_pos)
		if is_boss:
			_ensure_boss_hatch(room_node)


func _resolve_saved_enemy_scene_path(saved_path: String, slot_idx: int) -> String:
	for enemy_scene: PackedScene in enemy_variations:
		if enemy_scene != null and enemy_scene.resource_path == saved_path:
			return saved_path
	if enemy_variations.is_empty():
		return saved_path
	var replacement: PackedScene = enemy_variations[slot_idx % enemy_variations.size()]
	if replacement == null:
		return saved_path
	return replacement.resource_path


func _resolve_saved_boss_scene_path(_saved_path: String, slot_idx: int) -> String:
	for boss_scene: PackedScene in boss_variations:
		if boss_scene != null and boss_scene.resource_path == _saved_path:
			return _saved_path
	if not boss_variations.is_empty():
		var replacement: PackedScene = boss_variations[slot_idx % boss_variations.size()]
		if replacement != null:
			return replacement.resource_path
	return _saved_path

## Старые сейвы без полей map_* — оставляем текущие GameConstants (кооп-снимок хоста и т.д.).
func _apply_saved_map_geometry(dd: Dictionary) -> void:
	if dd.has("map_grid_size"):
		var g := clampi(int(dd["map_grid_size"]), 4, 32)
		if g > 0:
			GameConstants.MAP_MANAGER_GRID_SIZE = g
	if dd.has("map_room_size_x"):
		GameConstants.MAP_MANAGER_ROOM_SIZE_X = int(dd["map_room_size_x"])
	if dd.has("map_room_size_y"):
		GameConstants.MAP_MANAGER_ROOM_SIZE_Y = int(dd["map_room_size_y"])
	if dd.has("map_corridor_length"):
		GameConstants.MAP_MANAGER_CORRIDOR_LENGTH = int(dd["map_corridor_length"])


func load_dungeon_state():
	var dungeon_data = SaveSystem.load_dungeon_data()
	if not dungeon_data:
		print("Ошибка загрузки состояния данжена")
		return

	_apply_saved_map_geometry(dungeon_data)

	# Восстанавливаем seed и генерируем тот же данжен
	generation_seed = dungeon_data.get("generation_seed", 0)
	seed(generation_seed)
	print("Загружен seed: ", generation_seed)

	if dungeon_data.has(USED_ARTEFACT_STATE_KEY) and dungeon_data[USED_ARTEFACT_STATE_KEY] is Array:
		GameConstants.set_used_artefact_scene_paths(dungeon_data[USED_ARTEFACT_STATE_KEY])
	else:
		GameConstants.clear_used_artefact_scene_paths()
		if dungeon_data.has(TREASURE_STATE_KEY) and dungeon_data[TREASURE_STATE_KEY] is Array:
			for raw in dungeon_data[TREASURE_STATE_KEY]:
				if raw is Dictionary:
					GameConstants.remember_artefact_scene_path(str((raw as Dictionary).get("scene", "")))

	_obstacle_detail_spawn_override = GameConstants.clamp_obstacle_detail_level(
		dungeon_data.get("obstacle_detail", GameConstants.OBSTACLE_DETAIL_LEVEL)
	)

	# Генерируем данжен с тем же seed
	generate_layout()
	draw_map()
	GameConstants.constants_changed.emit()
	
	# Восстанавливаем собранные комнаты с сокровищами ПЕРЕД спавном
	if "collected_treasure_rooms" in dungeon_data:
		SaveSystem.collected_treasure_rooms = dungeon_data["collected_treasure_rooms"]
		print("Восстановлено собранных комнат с сокровищами: ", SaveSystem.collected_treasure_rooms.size())
	
	await get_tree().create_timer(0).timeout
	_spawn_player()
	await _spawn_obstacles_after_physics()
	_obstacle_detail_spawn_override = -1
	if dungeon_data.has(ENEMY_STATE_KEY) and dungeon_data[ENEMY_STATE_KEY] is Array:
		_spawn_enemies_from_state(dungeon_data[ENEMY_STATE_KEY])
	else:
		await _spawn_enemies_after_physics()
	if GameConstants.variant_to_bool(dungeon_data.get("boss_hatch_opened", SaveSystem.is_boss_hatch_opened())):
		SaveSystem.set_boss_hatch_opened(true)
		_ensure_saved_open_boss_hatch()
	if dungeon_data.has(TREASURE_STATE_KEY) and dungeon_data[TREASURE_STATE_KEY] is Array and not dungeon_data[TREASURE_STATE_KEY].is_empty():
		_spawn_treasures_from_state(dungeon_data[TREASURE_STATE_KEY])
	else:
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
	if NetworkManager.is_game_offline():
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
	_reset_coop_peer_room_grid_track()

	print("Состояние данжена восстановлено")


func _reset_coop_peer_room_grid_track() -> void:
	var mp := get_tree().get_multiplayer()
	if mp == null or not mp.is_server():
		return
	_coop_peer_last_room_grid.clear()
	var host_id := int(mp.get_unique_id())
	_coop_peer_last_room_grid[host_id] = current_room_grid_pos
	for pid in mp.get_peers():
		_coop_peer_last_room_grid[int(pid)] = current_room_grid_pos


func _room_in_enemy_net_sync_region(room_grid: Vector2i) -> bool:
	if room_grid == current_room_grid_pos:
		return true
	for d in _ENEMY_NET_SYNC_NEIGHBORS:
		if room_grid == current_room_grid_pos + d:
			return true
	return false


func room_in_local_enemy_net_sync_region(room_grid: Vector2i) -> bool:
	return _room_in_enemy_net_sync_region(room_grid)


## Сервер: синхронизировать врагов во всех комнатах, где сейчас (или рядом) стоит любой из пиров.
func _room_in_enemy_net_sync_for_server(room_grid: Vector2i) -> bool:
	var mp := get_tree().get_multiplayer()
	if mp == null or not mp.is_server():
		return false
	var peer_ids: Array[int] = []
	peer_ids.append(int(mp.get_unique_id()))
	for p in mp.get_peers():
		peer_ids.append(int(p))
	for rid in peer_ids:
		var rg: Vector2i = current_room_grid_pos
		if _coop_peer_last_room_grid.has(rid):
			rg = _coop_peer_last_room_grid[rid] as Vector2i
		if room_grid == rg:
			return true
		for d in _ENEMY_NET_SYNC_NEIGHBORS:
			if room_grid == rg + d:
				return true
	return false


func _enemy_net_visual_snapshot(ch: Node) -> Dictionary:
	var spr := ""
	var spr_frame := 0
	var ap := ""
	var ap_pos := 0.0
	var spr_node := ch.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if spr_node != null and spr_node.sprite_frames != null:
		spr = str(spr_node.animation)
		spr_frame = spr_node.frame
	var ap_node := ch.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap_node != null and ap_node.is_playing():
		ap = str(ap_node.current_animation)
		ap_pos = ap_node.current_animation_position
	return {
		"spr": spr,
		"spr_frame": spr_frame,
		"ap": ap,
		"ap_pos": ap_pos,
	}


func _physics_process_host_sync_enemies() -> void:
	# Только CharacterBody2D под Enemys — без get_nodes_in_group по всему дереву.
	var batch: Array = []
	for room_data in spawned_rooms:
		var room_grid: Vector2i = room_data["grid_pos"]
		if not _room_in_enemy_net_sync_for_server(room_grid):
			continue
		var room_node = room_data.get("node")
		if not is_instance_valid(room_node):
			continue
		var enemys_node = room_node.find_child("Enemys", true, false)
		if enemys_node == null:
			continue
		for n in enemys_node.get_children():
			if not is_instance_valid(n) or not n is CharacterBody2D:
				continue
			if GameConstants.variant_to_bool(n.get("is_dead")):
				continue
			var ch := n as CharacterBody2D
			var pos := ch.global_position
			var vel := ch.velocity
			var vis := _enemy_net_visual_snapshot(ch)
			var spr := str(vis.get("spr", ""))
			var spr_frame := int(vis.get("spr_frame", 0))
			var ap := str(vis.get("ap", ""))
			var ap_pos := float(vis.get("ap_pos", 0.0))
			var hp_val: int = int(ch.get("hp")) if ch.get("hp") != null else 0
			var max_hp_val: int = NetworkManager.get_enemy_sync_max_hp(ch, hp_val)
			var dead := GameConstants.variant_to_bool(ch.get("is_dead"))
			if ch.has_meta(&"_net_sync_last_pos"):
				var last_p: Vector2 = ch.get_meta(&"_net_sync_last_pos")
				var last_v: Vector2 = ch.get_meta(&"_net_sync_last_vel")
				var last_spr: String = str(ch.get_meta(&"_net_sync_last_spr", ""))
				var last_ap: String = str(ch.get_meta(&"_net_sync_last_ap", ""))
				var last_hp: int = int(ch.get_meta(&"_net_sync_last_hp", hp_val))
				if pos.distance_squared_to(last_p) < _NET_SYNC_POS_EPS2 and vel.distance_squared_to(last_v) < _NET_SYNC_VEL_EPS2 and spr == last_spr and ap == last_ap and hp_val == last_hp:
					continue
			ch.set_meta(&"_net_sync_last_pos", pos)
			ch.set_meta(&"_net_sync_last_vel", vel)
			ch.set_meta(&"_net_sync_last_spr", spr)
			ch.set_meta(&"_net_sync_last_ap", ap)
			ch.set_meta(&"_net_sync_last_hp", hp_val)
			var enemy_key := str(ch.get_meta(&"_net_enemy_key", ""))
			batch.append({
				"path": str(ch.get_path()),
				"key": enemy_key,
				"pos": pos,
				"vel": vel,
				"spr": spr,
				"spr_frame": spr_frame,
				"ap": ap,
				"ap_pos": ap_pos,
				"hp": maxi(0, hp_val),
				"max_hp": max_hp_val,
				"dead": dead,
			})
	if not batch.is_empty():
		NetworkManager.rpc_sync_enemy_batch.rpc(batch)


func _physics_process(delta: float) -> void:
	if NetworkManager.is_game_offline():
		return
	var mp := get_tree().get_multiplayer()
	if not mp.is_server():
		return
	if mp.get_peers().is_empty():
		return
	_enemy_net_sync_accum += delta
	if _enemy_net_sync_accum < ENEMY_NET_SYNC_INTERVAL:
		return
	_enemy_net_sync_accum = 0.0
	_physics_process_host_sync_enemies()
