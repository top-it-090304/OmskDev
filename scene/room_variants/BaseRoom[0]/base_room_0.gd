extends Node2D
class_name RoomBase 

@onready var door_top = $DoorTop
@onready var door_bottom = $DoorBottom
@onready var door_left = $DoorLeft
@onready var door_right = $DoorRight

# (Кстати, заметил опечатку: walleft. Лучше переименуй в wall_left для аккуратности)
@export var wall_top: PackedScene
@export var wall_left: PackedScene
@export var wall_down: PackedScene
@export var wall_right: PackedScene

var grid_x: int = 0
var grid_y: int = 0

func setup_room(has_left, has_right, has_top, has_bottom):
	# Вызываем помощника для каждой стороны
	if not has_left: _replace_with_wall(door_left, wall_left)
	if not has_right: _replace_with_wall(door_right, wall_right)
	if not has_top: _replace_with_wall(door_top, wall_top)
	if not has_bottom: _replace_with_wall(door_bottom, wall_down)

# Вспомогательная функция, чтобы не писать один и тот же код 4 раза
func _replace_with_wall(door_node: Node2D, wall_scene: PackedScene):
	# Проверка на всякий случай, чтобы игра не вылетела, если мы забыли назначить сцену в инспекторе
	if door_node and wall_scene:
		var new_wall = wall_scene.instantiate()
		
		add_child(new_wall)
		door_node.queue_free()
