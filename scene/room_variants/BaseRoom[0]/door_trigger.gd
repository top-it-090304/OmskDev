extends Area2D


# Эти переменные будем настраивать в инспекторе для каждой двери
@export var direction_x = 0 # 1 (направо), -1 (налево), 0 (не меняет X)
@export var direction_y = 0 # 1 (вниз), -1 (вверх), 0 (не меняет Y)

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.name == "Player":
		var manager = get_tree().root.find_child("MapManager", true, false)
		if manager:
			var new_x = manager.current_room_grid_pos.x + direction_x
			var new_y = manager.current_room_grid_pos.y + direction_y
			
			# Просто просим карту поменять текущую активную комнату.
			# Никакого телепорта!
			manager.change_current_room(new_x, new_y)
