extends Node2D


@export var room_scene: PackedScene 

const ROOM_SIZE_X = 848+50 
const ROOM_SIZE_Y = 672+50

# Размер сетки карты 
const GRID_SIZE = 9


enum RoomType { EMPTY, START, NORMAL, BOSS, TREASURE }

# 2D массив скелета
var layout = []

func _ready():
	generate_layout()
	draw_map()


func generate_layout():
	# Инициализируем пустую карту
	layout = []
	for x in GRID_SIZE:
		layout.append([])
		for y in GRID_SIZE:
			layout[x].append(RoomType.EMPTY)

	# Старт (в центре)
	var start_pos = Vector2i(GRID_SIZE / 2, GRID_SIZE / 2)
	layout[start_pos.x][start_pos.y] = RoomType.START

	# Босс (случайная позиция на правом краю)
	var boss_pos = Vector2i(GRID_SIZE - 2, randi_range(1, GRID_SIZE - 2))
	layout[boss_pos.x][boss_pos.y] = RoomType.BOSS

	# Рисуем путь от старта к боссу
	var current = start_pos
	while current != boss_pos:
		if randf() < 0.7 || current.y == boss_pos.y:
			current.x += 1 if boss_pos.x > current.x else -1
		else:
			current.y += 1 if boss_pos.y > current.y else -1
			
		if layout[current.x][current.y] == RoomType.EMPTY:
			layout[current.x][current.y] = RoomType.NORMAL

	# Делаем случайные ответвления от пути
	for _i in range(randi_range(3, 6)):
		var rand_room = get_random_room_of_type(RoomType.NORMAL)
		if rand_room == Vector2i.ZERO: break
		
		var dir = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)].pick_random()
		var new_pos = rand_room + dir
		
		if is_valid_pos(new_pos) and layout[new_pos.x][new_pos.y] == RoomType.EMPTY:
			layout[new_pos.x][new_pos.y] = RoomType.NORMAL

# Вспомогательные функции
func is_valid_pos(pos):
	return pos.x >= 0 and pos.x < GRID_SIZE and pos.y >= 0 and pos.y < GRID_SIZE

func get_random_room_of_type(type):
	var valid_rooms = []
	for x in GRID_SIZE:
		for y in GRID_SIZE:
			if layout[x][y] == type: valid_rooms.append(Vector2i(x, y))
	if valid_rooms.is_empty(): return Vector2i.ZERO
	return valid_rooms.pick_random()


#ОТРИСОВКА КОМНАТ В МИРЕ

func draw_map():
	# Считаем смещение, чтобы карта была по центру экрана
	var offset_x = -(GRID_SIZE * ROOM_SIZE_X) / 2
	var offset_y = -(GRID_SIZE * ROOM_SIZE_Y) / 2

	# Проходимся по всему скелету
	for x in GRID_SIZE:
		for y in GRID_SIZE:
			# Если там не пусто
			if layout[x][y] != RoomType.EMPTY:
				
				# Создаем копию твоей комнаты
				var room_instance = room_scene.instantiate()
				
				# Вычисляем позицию: координаты сетки * размер комнаты + смещение
				var target_pos = Vector2(
					offset_x + x * ROOM_SIZE_X, 
					offset_y + y * ROOM_SIZE_Y
				)
				
				# Ставим комнату на нужное место
				room_instance.position = target_pos
				
				# Добавляем комнату в игру (в дерево узлов)
				add_child(room_instance)
				
				# Если это стартовая комната, можно сразу спавнить туда игрока
				if layout[x][y] == RoomType.START:
					spawn_player(room_instance)

func spawn_player(room):
	# Ищем внутри комнаты узел с именем PlayerSpawn
	var spawn_marker = room.find_child("PlayerSpawn", true, false)
	if spawn_marker:
		
		# var player = preload("res://player.tscn").instantiate()
		# player.global_position = spawn_marker.global_position
		# add_child(player)
		print("Игрок здесь: ", spawn_marker.global_position)
	else:
		print("В комнате нет узла PlayerSpawn!")
