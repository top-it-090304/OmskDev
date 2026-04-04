extends Control

@onready var grid_container = $GridContainer

# Эта строка создаст слот в Инспекторе справа!
@export var map_manager: Node2D 

# Массивы для хранения состояния карточек
var room_cells = [] # 2D массив UI элементов (ColorRect)
var visited_rooms = [] # Комнаты, где игрок БЫЛ
var seen_rooms = [] # Комнаты, которые ВИДНЫ как соседи

var show_full_map = false # Режим показа всей карты

# Цвета для разных типов комнат (можешь поменять на свои)
const COLOR_EMPTY = Color.TRANSPARENT
const COLOR_NORMAL = Color.WHITE
const COLOR_BOSS = Color.RED
const COLOR_TREASURE = Color.GOLD
const COLOR_START = Color.GREEN
const COLOR_CURRENT = Color.CYAN # Цвет текущей комнаты (свечение)
const COLOR_SEEN = Color.GRAY # Цвет соседних, но не посещенных комнат
const COLOR_FULL_MAP_SEEN = Color.DARK_GRAY # Цвет непосещенных при включенной полной карте

func _ready():
	# Ждем создания MapManager и его карты
	await get_tree().process_frame
	
	
	if not map_manager:
		push_error("Minimap не может найти MapManager!")
		return
		
	build_grid()
	
	# Подключаемся к сигналу смены комнаты
	map_manager.room_changed.connect(_on_room_changed)
	
	# Изначально открываем стартовую комнату и её соседей
	_on_room_changed(map_manager.current_room_grid_pos)
func build_grid():
	# СНАЧАЛА цикл по Y (строки), ПОТОМ по X (столбцы)
	for y in range(map_manager.GRID_SIZE):
		room_cells.append([])
		for x in range(map_manager.GRID_SIZE):
			var rect = ColorRect.new()
			rect.color = Color.TRANSPARENT
			rect.custom_minimum_size = Vector2(10, 10) 
			grid_container.add_child(rect)
			room_cells[y].append(rect) # ВАЖНО: сначала Y, потом X


# Эта функция вызывается каждый раз, когда игрок переходит в новую комнату
func _on_room_changed(grid_pos: Vector2i):
	# Больше никаких вычислений! Просто говорим обновить цвета.
	update_minimap_visuals()
func update_minimap_visuals():
	# СНАЧАЛА Y, ПОТОМ X
	for y in range(map_manager.GRID_SIZE):
		for x in range(map_manager.GRID_SIZE):
			var cell = room_cells[y][x] # ВАЖНО: [y][x]
			var room_type = map_manager.layout[x][y] # А вот тут оставляем [x][y], потому что в MapManager массив другой
			var pos = Vector2i(x, y)
			
			if room_type == map_manager.RoomType.EMPTY:
				cell.color = Color.TRANSPARENT
				continue
				
			if show_full_map:
				if map_manager.visited_rooms.has(pos) or pos == map_manager.current_room_grid_pos:
					cell.color = get_room_color(room_type, pos)
				else:
					cell.color = Color.DARK_GRAY
			else:
				if pos == map_manager.current_room_grid_pos:
					cell.color = Color.CYAN
				elif map_manager.visited_rooms.has(pos):
					cell.color = get_room_color(room_type, pos)
				elif map_manager.seen_rooms.has(pos):
					cell.color = Color.GRAY
				else:
					cell.color = Color.TRANSPARENT
# Вспомогательная функция для получения цвета по типу комнаты
func get_room_color(type, pos):
	match type:
		map_manager.RoomType.START: return COLOR_START
		map_manager.RoomType.BOSS: return COLOR_BOSS
		map_manager.RoomType.TREASURE: return COLOR_TREASURE
		map_manager.RoomType.NORMAL: return COLOR_NORMAL
		_: return COLOR_NORMAL

# Переключение режима карты (привяжи это к кнопке в Input Map, например 'M')
func _input(event):
	# --- ТЕСТОВЫЙ РЕЖИМ ---
	# Нажми стрелку "Вправо", чтобы сымитировать переход в комнату справа
	if event.is_action_pressed("ui_right"): # "ui_right" - это стандартная кнопка стрелки вправо в Godot
		var new_x = map_manager.current_room_grid_pos.x + 1
		var new_y = map_manager.current_room_grid_pos.y
		# Проверяем, не выходим ли мы за край карты
		if map_manager.is_valid_pos(Vector2i(new_x, new_y)):
			map_manager.change_current_room(new_x, new_y)
			
	# Нажми стрелку "Влево" для теста возврата
	if event.is_action_pressed("ui_left"):
		var new_x = map_manager.current_room_grid_pos.x - 1
		var new_y = map_manager.current_room_grid_pos.y
		if map_manager.is_valid_pos(Vector2i(new_x, new_y)):
			map_manager.change_current_room(new_x, new_y)

	# --- КНОПКА ПОЛНОЙ КАРТЫ ---
	if event.is_action_pressed("toggle_map"):
		show_full_map = !show_full_map
		update_minimap_visuals()
