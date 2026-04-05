extends Node2D

# --- НАСТРОЙКИ ---
@export var start_room_variations: Array[PackedScene] = [] 
@export var normal_room_variations: Array[PackedScene] = [] 
@export var boss_room_variations: Array[PackedScene] = [] 
@export var treasure_room_variations: Array[PackedScene] = [] 

@export var corridor_h_scene: PackedScene 
@export var corridor_v_scene: PackedScene
@export var enemy_variations: Array[PackedScene] = [] 

# НОВОЕ: Массив всех возможных предметов для Treasure Room
@export var treasure_items: Array[PackedScene] = []

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
const ROOM_SIZE_X = 864 
const ROOM_SIZE_Y = 608 + 32 
const CORRIDOR_LENGTH = 64 

const GRID_SIZE = 15
enum RoomType { EMPTY, START, NORMAL, BOSS, TREASURE }
var layout = []
var spawned_rooms = []

# НОВОЕ: "Текущая колода" предметов для выдачи
var item_draw_pile: Array[PackedScene] = []

#minimap
var current_room_grid_pos = Vector2i(GRID_SIZE / 2, GRID_SIZE / 2)
signal room_changed(new_grid_pos)
var visited_rooms = []
var seen_rooms = []


func _ready():
	if start_room_variations.is_empty() or normal_room_variations.is_empty() or boss_room_variations.is_empty():
		push_error("ОШИБКА: Добавь хотя бы по одной сцене для Start, Normal и Boss комнат!")
		return
		
	generate_layout()
	draw_map()
	await get_tree().create_timer(0).timeout
	
	await _spawn_obstacles_after_physics()
	await _spawn_enemies_after_physics()
	
	# НОВОЕ: Спавним предметы в комнатах сокровищ (делаем это последним)
	_spawn_treasure_items()
	
	change_current_room(current_room_grid_pos.x, current_room_grid_pos.y)

# =====================================================================
# НОВОЕ: ЛОГИКА "КОЛОДЫ КАРТ" ДЛЯ ПРЕДМЕТОВ
# =====================================================================

func _get_next_treasure_item() -> PackedScene:
	if treasure_items.is_empty():
		return null
		
	# Если колода пуста, берем все предметы из инспектора, копируем их и перемешиваем
	if item_draw_pile.is_empty():
		item_draw_pile = treasure_items.duplicate()
		item_draw_pile.shuffle()
		
	# Достаем верхнюю карту из колоды (pop_back() быстрее, чем pop_front())
	return item_draw_pile.pop_back()

func _spawn_treasure_items():
	for room_data in spawned_rooms:
		if room_data["type"] == RoomType.TREASURE:
			var item_scene = _get_next_treasure_item()
			
			if item_scene == null:
				push_warning("Массив treasure_items пуст, предмет не заспавнен.")
				continue
				
			var room_node = room_data["node"]
			var item_instance = item_scene.instantiate()
			
			# Добавляем предмет напрямую в корень комнаты
			room_node.add_child(item_instance)
			
			# Строго по центру комнаты
			var local_center = Vector2(ROOM_SIZE_X / 2.0, ROOM_SIZE_Y / 2.0)
			item_instance.global_position = room_node.to_global(local_center)

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

	var treasure_count = randi_range(1, 2)
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

				add_child(room_instance)
				
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
# СПАВН ПРЕПЯТСТВИЙ
# =====================================================================

func _spawn_obstacles_in_room(room_node: Node2D, room_type: RoomType):
	if room_type == RoomType.START or room_type == RoomType.TREASURE or room_type == RoomType.EMPTY:
		return
		
	if obstacle_data.is_empty():
		return

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
		var data 
		match type_of_room:
			1: data = obstacle_data[0]
			2: 
				if randi_range(0, 1): data = obstacle_data[1] 
				else: data = obstacle_data[2]
			
			3:
				var r = randi_range(0, 2)
				if r == 0: data = obstacle_data[3] 
				elif r == 1: data = obstacle_data[4]
				else: data = obstacle_data[5]
				
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
			var local_x = randf_range(half_size.x + 64, ROOM_SIZE_X - half_size.x - 64)
			var local_y = randf_range(half_size.y + 64, ROOM_SIZE_Y - half_size.y - 64)
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
			
			
		for _i in range(enemy_count):
			_spawn_single_enemy(space_state, room_node)

func _spawn_single_enemy(space_state, room_node):
	var max_attempts = 30 
	
	for _attempt in range(max_attempts):
		var local_x = randf_range(64, ROOM_SIZE_X - 64)
		var local_y = randf_range(64, ROOM_SIZE_Y - 64)
		var local_point = Vector2(local_x, local_y)
		var global_point = room_node.to_global(local_point)

		var query = PhysicsPointQueryParameters2D.new()
		query.position = global_point 
		query.collide_with_bodies = true  
		query.collide_with_areas = false  
		query.collision_mask = 1 

		var intersection = space_state.intersect_point(query)

		if intersection.is_empty():
			var selected_enemy_scene = enemy_variations.pick_random()
			var enemy = selected_enemy_scene.instantiate()
			
			var area_enemys = room_node.find_child("Enemys")
			if area_enemys == null:
				return
			
			area_enemys.add_child(enemy)
			enemy.global_position = global_point
			return 

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
