extends Node2D
# Ссылки на двери (перетащи их в Inspector)
@onready var door_top = $DoorTop
@onready var door_bottom = $DoorBottom
@onready var door_left = $DoorLeft
@onready var door_right = $DoorRight

# Функция, которую будет вызывать MapManager
func setup_room(has_left, has_right, has_top, has_bottom):
	# Если соседа нет - удаляем дверь (или ставим там стену)
	if not has_left:door_left.queue_free()
	if not has_right:door_right.queue_free()
	if not has_top:door_top.queue_free()
	if not has_bottom:door_bottom.queue_free()
