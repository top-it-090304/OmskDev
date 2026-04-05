extends Area2D


# Ссылка на корневую ноду самой комнаты
var parent_room_node: Node2D

func _ready():
	parent_room_node = get_parent()
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.name == "Player":
		var manager = get_tree().root.find_child("MapManager", true, false)
		if manager:
			# Передаем координаты комнаты, в которой лежит эта зона
			manager.change_current_room(parent_room_node.grid_x, parent_room_node.grid_y)
