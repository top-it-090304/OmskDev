extends Control
@onready var grid_container = $MarginContainer/GridContainer
@onready var Margin_Container = $MarginContainer
@export var map_manager: Node2D 

# НОВОЕ: Укажи здесь размер твоего окна миникарты в пикселях (например, 150 на 150).
# Это нужно, чтобы математика не ломалась, пока Godot грузит интерфейс.
@export var minimap_window_size: Vector2 = Vector2(108, 108) 

var room_cells = []
var show_full_map = false
var cell_step = 0.0
var grid_total_size = Vector2.ZERO

func _ready():
	await get_tree().process_frame
	
	if not map_manager:
		push_error("MapManager не найден!")
		return
		
	# Отключаем обрезку границ
	
		
	build_grid()
	
	# ИСПРАВЛЕНИЕ 1: Считаем шаг ячейки НАПРЯМУЮ из константы.
	# Мы сами задали размер 12x12 в build_grid(), поэтому нам не нужно спрашивать 
	# у Godot размер ребенка (на первом кадре он всегда возвращает 0, из-за чего и был баг).
	var cell_size = Vector2(12, 12) 
	var separation = grid_container.get_theme_constant("separation")
	if separation == 0: separation = 2 # Запасной отступ, если в теме пусто
	
	cell_step = cell_size.x + separation
	grid_total_size.x = cell_step * map_manager.GRID_SIZE
	grid_total_size.y = cell_step * map_manager.GRID_SIZE
		
	map_manager.room_changed.connect(_on_room_changed)
	_on_room_changed(map_manager.current_room_grid_pos)

func build_grid():
	for child in grid_container.get_children():
		child.queue_free()
	room_cells.clear()
	
	grid_container.columns = map_manager.GRID_SIZE
	
	for y in range(map_manager.GRID_SIZE):
		room_cells.append([])
		for x in range(map_manager.GRID_SIZE):
			var rect = ColorRect.new()
			rect.color = Color.TRANSPARENT
			rect.custom_minimum_size = Vector2(12, 12) 
			grid_container.add_child(rect)
			room_cells[y].append(rect)

func center_map_on_room(grid_pos: Vector2i):
	if cell_step == 0: return
	
	var viewport_size = minimap_window_size
	
	# Считаем идеальную позицию, чтобы текущая комната была ровно по центру
	var target_x = (viewport_size.x / 2.0) - (grid_pos.x * cell_step) - (cell_step / 2.0)
	var target_y = (viewport_size.y / 2.0) - (grid_pos.y * cell_step) - (cell_step / 2.0)
	
	# ВСЁ! Никаких проверок на выход за края, никаких clamp.
	# Сетка будет свободно уезжать за пределы окна миникарты.
	grid_container.position = Vector2(target_x, target_y)
func _on_room_changed(grid_pos: Vector2i):
	update_minimap_visuals()
	center_map_on_room(grid_pos)

func update_minimap_visuals():
	for y in range(map_manager.GRID_SIZE):
		for x in range(map_manager.GRID_SIZE):
			var cell = room_cells[y][x]
			var room_type = map_manager.layout[x][y]
			var pos = Vector2i(x, y)
			
			if room_type == map_manager.RoomType.EMPTY:
				cell.color = Color.TRANSPARENT
				continue
				
			if show_full_map:
				if map_manager.visited_rooms.has(pos) or pos == map_manager.current_room_grid_pos:
					cell.color = get_room_color(room_type, pos)
				else:
					cell.color = Color.DIM_GRAY
			else:
				if pos == map_manager.current_room_grid_pos:
					match get_room_color(room_type, pos):
						Color.DARK_GRAY: cell.color = Color.ANTIQUE_WHITE
						Color.LIGHT_GREEN: cell.color = Color.LAWN_GREEN
						Color.INDIAN_RED: cell.color = Color.ORANGE_RED
						Color.SANDY_BROWN: cell.color = Color.YELLOW
						_: cell.color = Color.ANTIQUE_WHITE
				elif map_manager.visited_rooms.has(pos):
					cell.color = get_room_color(room_type, pos)
				elif map_manager.seen_rooms.has(pos):
					cell.color = Color.DIM_GRAY
				else:
					cell.color = Color.TRANSPARENT

func get_room_color(type, pos):
	match type:
		map_manager.RoomType.START: return Color.LIGHT_GREEN
		map_manager.RoomType.BOSS: return Color.INDIAN_RED
		map_manager.RoomType.TREASURE: return Color.SANDY_BROWN
		map_manager.RoomType.NORMAL: return Color.DARK_GRAY
		_: return Color.CORAL

func _input(event):
	if event.is_action_pressed("toggle_map"):
		show_full_map = !show_full_map
		
		if show_full_map:
			var viewport_size = minimap_window_size
			# Центрируем всю сгенерированную карту по центру окошка
			var target_x = (viewport_size.x - grid_total_size.x) / 2.0
			var target_y = (viewport_size.y - grid_total_size.y) / 2.0
			grid_container.position = Vector2(target_x, target_y)
		else:
			center_map_on_room(map_manager.current_room_grid_pos)
			
		update_minimap_visuals()
