extends Control

@onready var grid_container = $MarginContainer/GridContainer
@onready var Margin_Container = $MarginContainer
@export var map_manager: Node2D 

var room_cells = []
var visited_rooms = []
var seen_rooms = []

var show_full_map = false
var cell_step = 0.0

func _ready():
	await get_tree().process_frame
	
	if not map_manager:
		push_error("MapManager не найден!")
		return
		
	build_grid()
	
	if grid_container.get_child_count() > 0:
		var separation = grid_container.get_theme_constant("separation")
		cell_step = grid_container.get_child(0).size.x + separation
		
	map_manager.room_changed.connect(_on_room_changed)
	_on_room_changed(map_manager.current_room_grid_pos)

func build_grid():
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
	
	# ИЗМЕНЕНИЕ ТУТ: берем размер РОДИТЕЛЯ (нашего окна миникарты), а не самой сетки
	var viewport_center = Margin_Container.size / 2.0
	print(viewport_center.x,grid_pos.x,cell_step)
	var target_x = viewport_center.x - (grid_pos.x * cell_step) - (cell_step / 2.0)-10
	var target_y = viewport_center.y - (grid_pos.y * cell_step) - (cell_step / 2.0)-10
	
	# Сдвигаем сетку внутри окна
	grid_container.position = Vector2(target_x, target_y)

func _on_room_changed(grid_pos: Vector2i):
	if not map_manager.visited_rooms.has(grid_pos):
		map_manager.visited_rooms.append(grid_pos)
		
	var directions = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	for dir in directions:
		var neighbor_pos = grid_pos + dir
		if map_manager.is_valid_pos(neighbor_pos) and map_manager.layout[neighbor_pos.x][neighbor_pos.y] != map_manager.RoomType.EMPTY:
			if not map_manager.seen_rooms.has(neighbor_pos):
				map_manager.seen_rooms.append(neighbor_pos)

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

func get_room_color(type, pos):
	match type:
		map_manager.RoomType.START: return Color.GREEN
		map_manager.RoomType.BOSS: return Color.RED
		map_manager.RoomType.TREASURE: return Color.GOLD
		map_manager.RoomType.NORMAL: return Color.WHITE
		_: return Color.WHITE

func _input(event):
	if event.is_action_pressed("toggle_map"):
		show_full_map = !show_full_map
		
		if show_full_map:
			# При показе полной карты сдвигаем сетку так, чтобы показать начало (0,0)
			# Или можно просто оставить сдвиг на текущей комнате, как вам удобнее
			grid_container.position = Vector2.ZERO 
		else:
			center_map_on_room(map_manager.current_room_grid_pos)
			
		update_minimap_visuals()
