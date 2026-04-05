extends Node2D
# ЭТА СТРОКА РЕГИСТРИРУЕТ ТИП В ДВИЖКЕ! Теперь Godot будет знать, что это RoomBase
class_name RoomBase 

# Ссылки на двери (они должны лежать внутри base_room0)
@onready var door_top = $DoorTop
@onready var door_bottom = $DoorBottom
@onready var door_left = $DoorLeft
@onready var door_right = $DoorRight

var grid_x: int = 0
var grid_y: int = 0

# Функция, которую будет вызывать MapManager
func setup_room(has_left, has_right, has_top, has_bottom):
	if not has_left: door_left.queue_free()
	if not has_right: door_right.queue_free()
	if not has_top: door_top.queue_free()
	if not has_bottom: door_bottom.queue_free()
