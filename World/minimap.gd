extends Control
@onready var grid_container = $MarginContainer/GridContainer
@onready var Margin_Container = $MarginContainer
@export var map_manager: Node2D 

# НОВОЕ: Укажи здесь размер твоего окна миникарты в пикселях (например, 150 на 150).
# Это нужно, чтобы математика не ломалась, пока Godot грузит интерфейс.
@export var minimap_window_size: Vector2 = Vector2(80, 80) 

var room_cells = []
var show_full_map = false
var cell_step = 0.0
var grid_total_size = Vector2.ZERO

func _exit_tree() -> void:
	if GameConstants.constants_changed.is_connected(_on_game_constants_changed):
		GameConstants.constants_changed.disconnect(_on_game_constants_changed)


func _ready():
	await get_tree().process_frame

	if not is_instance_valid(map_manager):
		push_error("MapManager не найден или уже освобождён!")
		return

	build_grid()

	if not map_manager.room_changed.is_connected(_on_room_changed):
		map_manager.room_changed.connect(_on_room_changed)
	if not GameConstants.constants_changed.is_connected(_on_game_constants_changed):
		GameConstants.constants_changed.connect(_on_game_constants_changed)
	# У клиента layout заполняется только после sync данжа — до этого layout == [] и layout[0] падает
	var watchdog := 600
	while not _is_map_layout_ready():
		watchdog -= 1
		if watchdog <= 0:
			push_warning("minimap: layout ещё не готов (таймаут ожидания); первое обновление при room_changed")
			return
		await get_tree().process_frame
	_on_room_changed(map_manager.current_room_grid_pos)


func _is_map_layout_ready() -> bool:
	if not is_instance_valid(map_manager):
		return false
	var l: Variant = map_manager.layout
	if not l is Array:
		return false
	var g: int = GameConstants.MAP_MANAGER_GRID_SIZE
	if (l as Array).size() < g:
		return false
	for i in g:
		var row: Variant = (l as Array)[i]
		if not row is Array or (row as Array).size() < g:
			return false
	return true


func _refresh_cell_metrics() -> void:
	var cell_size := Vector2(12, 12)
	var separation: int = grid_container.get_theme_constant("separation")
	if separation == 0:
		separation = 2
	cell_step = cell_size.x + separation
	var g: int = GameConstants.MAP_MANAGER_GRID_SIZE
	grid_total_size.x = cell_step * g
	grid_total_size.y = cell_step * g


## Синхрон с GameConstants (кооп: снимок хоста / hot-reload cfg) — иначе room_cells[y] падает на индексе вроде 5.
func _ensure_room_cells_match_constants() -> void:
	var g: int = GameConstants.MAP_MANAGER_GRID_SIZE
	if room_cells.size() != g:
		build_grid()
		_refresh_cell_metrics()
		return
	for row in room_cells:
		if not row is Array or (row as Array).size() != g:
			build_grid()
			_refresh_cell_metrics()
			return


func build_grid():
	for child in grid_container.get_children():
		if is_instance_valid(child):
			child.queue_free()
	room_cells.clear()
	
	grid_container.columns = GameConstants.MAP_MANAGER_GRID_SIZE
	
	for y in range(GameConstants.MAP_MANAGER_GRID_SIZE):
		room_cells.append([])
		for x in range(GameConstants.MAP_MANAGER_GRID_SIZE):
			var rect = ColorRect.new()
			rect.color = Color.TRANSPARENT
			rect.custom_minimum_size = Vector2(12, 12) 
			grid_container.add_child(rect)
			room_cells[y].append(rect)
	_refresh_cell_metrics()

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


func _on_game_constants_changed() -> void:
	if not is_instance_valid(map_manager):
		return
	_ensure_room_cells_match_constants()
	if _is_map_layout_ready():
		update_minimap_visuals()
		center_map_on_room(map_manager.current_room_grid_pos)

func update_minimap_visuals():
	_ensure_room_cells_match_constants()
	if not is_instance_valid(map_manager) or not _is_map_layout_ready():
		return
	var g: int = GameConstants.MAP_MANAGER_GRID_SIZE
	var lay: Variant = map_manager.layout
	if not lay is Array or (lay as Array).size() < g:
		return
	for y in range(g):
		if y >= room_cells.size():
			return
		var row_cells: Variant = room_cells[y]
		if not row_cells is Array or (row_cells as Array).size() < g:
			return
		for x in range(g):
			if x >= (lay as Array).size():
				return
			var col: Variant = (lay as Array)[x]
			if not col is Array or (col as Array).size() <= y:
				return
			var cell = (row_cells as Array)[x]
			var room_type = int((col as Array)[y])
			var pos = Vector2i(x, y)
			
			if room_type == map_manager.RoomType.EMPTY:
				cell.color = Color.TRANSPARENT
				continue
				
			if show_full_map:
				if map_manager.visited_rooms.has(pos) or pos == map_manager.current_room_grid_pos:
					cell.color = get_room_color(room_type)
				elif map_manager.seen_rooms.has(pos):
					cell.color = get_seen_room_color(room_type)
				else:
					cell.color = Color.DIM_GRAY
			else:
				if pos == map_manager.current_room_grid_pos:
					cell.color = get_current_room_color(room_type)
				elif map_manager.visited_rooms.has(pos):
					cell.color = get_room_color(room_type)
				elif map_manager.seen_rooms.has(pos):
					cell.color = get_seen_room_color(room_type)
				else:
					cell.color = Color.TRANSPARENT

func get_room_color(type: int) -> Color:
	match type:
		map_manager.RoomType.START: return Color.LIGHT_GREEN
		map_manager.RoomType.BOSS: return Color.INDIAN_RED
		map_manager.RoomType.TREASURE: return Color(0.95, 0.78, 0.18, 1.0)
		map_manager.RoomType.NORMAL: return Color.DARK_GRAY
		_: return Color.CORAL


func get_seen_room_color(type: int) -> Color:
	match type:
		map_manager.RoomType.START:
			return Color(0.28, 0.5, 0.28, 1.0)
		map_manager.RoomType.BOSS:
			return Color(0.55, 0.22, 0.2, 1.0)
		map_manager.RoomType.TREASURE:
			# Артефактная/сокровищница до входа: серый корпус + жёлтый оттенок.
			return Color(0.62, 0.56, 0.32, 1.0)
		map_manager.RoomType.NORMAL:
			return Color(0.34, 0.34, 0.34, 1.0)
		_:
			return Color(0.35, 0.3, 0.26, 1.0)


func get_current_room_color(type: int) -> Color:
	match type:
		map_manager.RoomType.START:
			return Color.LAWN_GREEN
		map_manager.RoomType.BOSS:
			return Color.ORANGE_RED
		map_manager.RoomType.TREASURE:
			return Color.YELLOW
		map_manager.RoomType.NORMAL:
			return Color.ANTIQUE_WHITE
		_:
			return Color.ANTIQUE_WHITE

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
			if is_instance_valid(map_manager):
				center_map_on_room(map_manager.current_room_grid_pos)
			
		update_minimap_visuals()
