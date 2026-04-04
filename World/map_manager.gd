extends Node2D

# --- НАСТРОЙКИ ---
@export var room_scene: PackedScene 
@export var corridor_h_scene: PackedScene 
@export var corridor_v_scene: PackedScene
@export var enemy_scene: PackedScene 

# Размер комнаты и КОРидОРА в пикселях
const ROOM_SIZE_X = 864 
const ROOM_SIZE_Y = 608 + 32 
const CORRIDOR_LENGTH = 64 

const GRID_SIZE = 9
enum RoomType { EMPTY, START, NORMAL, BOSS, TREASURE }
var layout = []
var spawned_rooms = []

#minimap
var current_room_grid_pos = Vector2i(GRID_SIZE / 2, GRID_SIZE / 2)
signal room_changed(new_grid_pos)
var visited_rooms = []
var seen_rooms = []
var onlyfirst=true

func _ready():
	generate_layout()
	draw_map()
	await get_tree().create_timer(0).timeout
	# Ждем ОБЯЗАТЕЛЬНО один кадр физики, чтобы стены из TileMap стали твердыми
	_spawn_enemies_after_physics()
	change_current_room(current_room_grid_pos.x, current_room_grid_pos.y)
# --- Генерация скелета ---
func generate_layout():
	layout = []
	for x in range(GRID_SIZE):
		layout.append([])
		for y in range(GRID_SIZE):
			layout[x].append(RoomType.EMPTY)

	var start_pos = Vector2i(GRID_SIZE / 2, GRID_SIZE / 2)
	layout[start_pos.x][start_pos.y] = RoomType.START

	var boss_pos = Vector2i(GRID_SIZE - 2, randi_range(1, GRID_SIZE - 2))
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

func is_valid_pos(pos):
	return pos.x >= 0 and pos.x < GRID_SIZE and pos.y >= 0 and pos.y < GRID_SIZE

func get_random_room_of_type(type):
	var valid_rooms = []
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			if layout[x][y] == type: valid_rooms.append(Vector2i(x, y))
	if valid_rooms.is_empty(): return Vector2i(-1, -1)
	return valid_rooms.pick_random()

# --- ОТРИСОВКА ---
func draw_map():
	var cell_size_x = ROOM_SIZE_X + CORRIDOR_LENGTH
	var cell_size_y = ROOM_SIZE_Y + CORRIDOR_LENGTH
	
	var offset_x = -(GRID_SIZE * cell_size_x) / 2
	var offset_y = -(GRID_SIZE * cell_size_y) / 2

	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			if layout[x][y] != RoomType.EMPTY:
				
				var room_pos = Vector2(offset_x + x * cell_size_x, offset_y + y * cell_size_y)
				var room_instance = room_scene.instantiate()
				room_instance.position = room_pos
				
				add_child(room_instance)
				
				# Сохраняем только саму ноду комнаты (координаты нам больше не нужны!)
				spawned_rooms.append({
					"node": room_instance,
					"type": layout[x][y]
				})
				
				var has_left = check_neighbor(x - 1, y)
				var has_right = check_neighbor(x + 1, y)
				var has_top = check_neighbor(x, y - 1)
				var has_bottom = check_neighbor(x, y + 1)
				
				room_instance.setup_room(has_left, has_right, has_top, has_bottom)
				
				if has_right:
					var corr = corridor_h_scene.instantiate()
					corr.position.x = room_pos.x + ROOM_SIZE_X
					corr.position.y = room_pos.y + (ROOM_SIZE_Y / 2) - (CORRIDOR_LENGTH / 2) 
					add_child(corr)
				
				if has_bottom:
					var corr = corridor_v_scene.instantiate()
					corr.position.x = room_pos.x + (ROOM_SIZE_X / 2) - (CORRIDOR_LENGTH / 2)
					corr.position.y = room_pos.y + ROOM_SIZE_Y
					add_child(corr)

func check_neighbor(nx, ny):
	if is_valid_pos(Vector2i(nx, ny)):
		return layout[nx][ny] != RoomType.EMPTY
	return false

# =====================================================================
# НОВЫЙ, БЕЗОШИБОЧНЫЙ СПАВН ВРАГОВ
# =====================================================================

func _spawn_enemies_after_physics():
	# await приостанавливает функцию до следующего кадра физики.
	# Без этого TileMap стены еще "невидимы" для raycast/point запросов!
	await get_tree().physics_frame 
	
	var space_state = get_world_2d().direct_space_state
	
	for room_data in spawned_rooms:
		var room_type = room_data["type"]
		var room_node = room_data["node"]
		
		if room_type == RoomType.START or room_type == RoomType.EMPTY:
			continue
			
		var enemy_count = 0
		match room_type:
			RoomType.NORMAL: enemy_count = randi_range(2, 5)
			RoomType.TREASURE: enemy_count = randi_range(1, 2)
			RoomType.BOSS: enemy_count = 1
			
		for _i in range(enemy_count):
			_spawn_single_enemy(space_state, room_node)

func _spawn_single_enemy(space_state, room_node):
	var max_attempts = 30 
	
	for _attempt in range(max_attempts):
		# 1. Генерируем локальную точку для проверки
		var local_x = randf_range(64, ROOM_SIZE_X - 64)
		var local_y = randf_range(64, ROOM_SIZE_Y - 64)
		var local_point = Vector2(local_x, local_y)

		# 2. Переводим в ГЛОБАЛЬНУЮ для проверки физики
		var global_point = room_node.to_global(local_point)

		var query = PhysicsPointQueryParameters2D.new()
		query.position = global_point 
		query.collide_with_bodies = true  
		query.collide_with_areas = false  
		
		# ВАЖНО: Убедись, что здесь указан слой СТЕН, а не пола!
		# Если пол и стены на 1 слое, intersect_point будет бить в пол.
		query.collision_mask = 1 

		var intersection = space_state.intersect_point(query)

		# 3. Если точка свободна от стен
		if intersection.is_empty():
			var enemy = enemy_scene.instantiate()
			
			var area_enemys = room_node.find_child("Enemys")
			if area_enemys == null:
				return
			
			# 4. СНАЧАЛА делаем врага ребенком Enemys
			area_enemys.add_child(enemy)
			
			# 5. ПОСЛЕ добавления задаем ему ГЛОБАЛЬНУЮ позицию.
			# Godot сам поймет, куда его поставить внутри area_enemys, 
			# чтобы он оказался ровно там, где мы проверяли физику!
			enemy.global_position = global_point
			
			return # Враг успешно поставлен, выходим из цикла
func change_current_room(new_x, new_y):
	var new_pos = Vector2i(new_x, new_y)
	
	if new_pos == current_room_grid_pos and onlyfirst==false:
		return
	else:
		onlyfirst=false
	# 1. Добавляем текущую комнату в список ПОСЕЩЕННЫХ
	if not visited_rooms.has(new_pos):
		visited_rooms.append(new_pos)
		
	# 2. Ищем соседей и добавляем их в список ВИДИМЫХ
	var directions = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	for dir in directions:
		var neighbor_pos = new_pos + dir
		# Если сосед существует на карте и это не пустота
		if is_valid_pos(neighbor_pos) and layout[neighbor_pos.x][neighbor_pos.y] != RoomType.EMPTY:
			if not seen_rooms.has(neighbor_pos):
				seen_rooms.append(neighbor_pos)
				
	# 3. Обновляем текущую позицию и КРИЧИМ миникарте, что всё изменилось
	current_room_grid_pos = new_pos
	room_changed.emit(current_room_grid_pos)
