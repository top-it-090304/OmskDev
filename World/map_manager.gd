extends Node2D

# --- НАСТРОЙКИ ---
@export var room_scene: PackedScene 
@export var corridor_h_scene: PackedScene # Перетащи CorridorH сюда
@export var corridor_v_scene: PackedScene # Перетащи CorridorV сюда
@export var enemy_goblin_axe_scene: PackedScene 

# Размер комнаты и КОРидОРА в пикселях
const ROOM_SIZE_X = 864 # Твой размер
const ROOM_SIZE_Y = 608+32 # Твой размер
const CORRIDOR_LENGTH = 64 # ВНИМАНИЕ: должно делиться на размер тайла!

const GRID_SIZE = 9
enum RoomType { EMPTY, START, NORMAL, BOSS, TREASURE }
var layout = []
var spawned_rooms = []

func _ready():
	generate_layout()
	draw_map()
	call_deferred("_spawn_all_enemies")
# --- Генерация скелета (без изменений) ---
func generate_layout():
	layout = []
	for x in GRID_SIZE:
		layout.append([])
		for y in GRID_SIZE:
			layout[x].append(RoomType.EMPTY)

	var start_pos = Vector2i(GRID_SIZE / 2, GRID_SIZE / 2)
	layout[start_pos.x][start_pos.y] = RoomType.START

	var boss_pos = Vector2i(GRID_SIZE - 2, randi_range(1, GRID_SIZE - 2))
	layout[boss_pos.x][boss_pos.y] = RoomType.BOSS

	var current = start_pos
	while current != boss_pos:
		if randf() < 0.7 || current.y == boss_pos.y:
			current.x += 1 if boss_pos.x > current.x else -1
		else:
			current.y += 1 if boss_pos.y > current.y else -1
		if layout[current.x][current.y] == RoomType.EMPTY:
			layout[current.x][current.y] = RoomType.NORMAL

	for _i in range(randi_range(3, 6)):
		var rand_room = get_random_room_of_type(RoomType.NORMAL)
		if rand_room == Vector2i.ZERO: break
		var dir = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)].pick_random()
		var new_pos = rand_room + dir
		if is_valid_pos(new_pos) and layout[new_pos.x][new_pos.y] == RoomType.EMPTY:
			layout[new_pos.x][new_pos.y] = RoomType.NORMAL

func is_valid_pos(pos):
	return pos.x >= 0 and pos.x < GRID_SIZE and pos.y >= 0 and pos.y < GRID_SIZE

func get_random_room_of_type(type):
	var valid_rooms = []
	for x in GRID_SIZE:
		for y in GRID_SIZE:
			if layout[x][y] == type: valid_rooms.append(Vector2i(x, y))
	if valid_rooms.is_empty(): return Vector2i.ZERO
	return valid_rooms.pick_random()

# --- НОВАЯ ОТРИСОВКА С КОРИДОРАМИ ---
func draw_map():
	# Считаем общую ширину ячейки (Комната + Коридор)
	var cell_size_x = ROOM_SIZE_X + CORRIDOR_LENGTH
	var cell_size_y = ROOM_SIZE_Y + CORRIDOR_LENGTH
	
	# Центрируем карту
	var offset_x = -(GRID_SIZE * cell_size_x) / 2
	var offset_y = -(GRID_SIZE * cell_size_y) / 2

	for x in GRID_SIZE:
		for y in GRID_SIZE:
			if layout[x][y] != RoomType.EMPTY:
				
				# Позиция самой комнаты
				var room_pos = Vector2(offset_x + x * cell_size_x, offset_y + y * cell_size_y)
				var room_instance = room_scene.instantiate()
				room_instance.position = room_pos
				add_child(room_instance)
				
				spawned_rooms.append({
					"node": room_instance,
					"type": layout[x][y],
					"pos": room_pos
				})
				# Проверяем соседей
				var has_left = check_neighbor(x - 1, y)
				var has_right = check_neighbor(x + 1, y)
				var has_top = check_neighbor(x, y - 1)
				var has_bottom = check_neighbor(x, y + 1)
				
				# Настройка дверей в комнате
				room_instance.setup_room(has_left, has_right, has_top, has_bottom)
				
				# --- СПАВН КОРИДОРОВ ---
				
				# Если есть сосед справа -> рисуем горизонтальный коридор
				if has_right:
					var corr = corridor_h_scene.instantiate()
					# Коридор начинается сразу после правого края комнаты
					corr.position.x = room_pos.x + ROOM_SIZE_X
					# По высоте коридор должен быть на уровне проема двери (обычно центр)
					corr.position.y = room_pos.y + (ROOM_SIZE_Y / 2) - (CORRIDOR_LENGTH / 2) 
					add_child(corr)
				
				# Если есть сосед снизу -> рисуем вертикальный коридор
				if has_bottom:
					var corr = corridor_v_scene.instantiate()
					# Коридор начинается сразу после нижнего края комнаты
					corr.position.x = room_pos.x + (ROOM_SIZE_X / 2) - (CORRIDOR_LENGTH / 2)
					corr.position.y = room_pos.y + ROOM_SIZE_Y
					add_child(corr)

func check_neighbor(nx, ny):
	if is_valid_pos(Vector2i(nx, ny)):
		return layout[nx][ny] != RoomType.EMPTY
	return false

func spawn_player(room):
	var spawn_marker = room.find_child("PlayerSpawn", true, false)
	if spawn_marker:
		print("Игрок здесь: ", spawn_marker.global_position)

func _spawn_all_enemies():
	var space_state = get_world_2d().direct_space_state
	
	for room_data in spawned_rooms:
		var room_type = room_data["type"]
		var room_node = room_data["node"]
		var room_pos = room_data["pos"]
		
		# В стартовой комнате врагов не будет
		if room_type == RoomType.START or room_type == RoomType.EMPTY:
			continue
			
		# Определяем количество врагов (от 2 до 5 в обычных, от 1 до 2 в сокровищнице, 1 босс)
		var enemy_count = 0
		match room_type:
			RoomType.NORMAL: enemy_count = randi_range(4,5)
			RoomType.TREASURE: enemy_count = randi_range(2,3)
			RoomType.BOSS: enemy_count = 1
			
		# Пытаемся заспавнить каждого врага
		for i in range(enemy_count):
			_spawn_single_enemy(space_state, room_node, room_pos)

func _spawn_single_enemy(space_state, room_node, room_pos):
	var max_attempts = 20 # Защита от бесконечного цикла, если комната забита стенами
	
	for _attempt in range(max_attempts):
		# Генерируем случайную точку ВНУТРИ комнаты (отступаем по 64 пикселя от краев, чтобы не заспавнить в стене)
		var rand_x = randf_range(room_pos.x + 64, room_pos.x + ROOM_SIZE_X - 64)
		var rand_y = randf_range(room_pos.y + 64, room_pos.y + ROOM_SIZE_Y - 300)
		var test_point = Vector2(rand_x, rand_y)
		
		# Настройки запроса к физике
		var query = PhysicsPointQueryParameters2D.new()
		query.position = test_point
		query.collide_with_bodies = true  # Проверяем столкновения с твердыми телами (стенами)
		query.collide_with_areas = false  # Игнорируем Area2D (например, триггеры дверей)
		query.collision_mask = 1 # Убедись, что у твоих стен маска коллизии 1 (слой 1). Если другой слой - поменяй цифру.
		
		# Отправляем запрос физическому движку
		var intersection = space_state.intersect_point(query)
		
		# Если массив пустой - значит в этой точке НЕТ стен!
		if intersection.is_empty():
			var enemy = enemy_goblin_axe_scene.instantiate()
			enemy.global_position = test_point
			room_node.add_child(enemy) # Добавляем врага НЕПОСРЕДСТВЕННО в ноду комнаты
			return
