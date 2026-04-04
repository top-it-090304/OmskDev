extends Area2D

@export var direction_x = 0 
@export var direction_y = 0 
func _ready():
	body_entered.connect(_on_body_entered)
func _on_body_entered(body):
	# 1. ПРОВЕРКА: Сработал ли триггер вообще?
	print("!!! ТРИГГЕР СРАБОТАЛ !!! Зашел объект: ", body.name)
	
	if body.name == "Player":
		var manager = get_tree().root.find_child("MapManager", true, false)
		
		# 2. ПРОВЕРКА: Нашелся ли MapManager?
		if manager:
			print(">>> MapManager найден! Текущая позиция: ", manager.current_room_grid_pos)
			var new_x = manager.current_room_grid_pos.x + direction_x
			var new_y = manager.current_room_grid_pos.y + direction_y
			
			# 3. ПРОВЕРКА: Какие координаты мы пытаемся отдать?
			print(">>> Попытка перейти в: X=", new_x, " Y=", new_y)
			print(">>> Значения direction_x/y: ", direction_x, direction_y)
			
			manager.change_current_room(new_x, new_y)
			print(">>> ФУНКЦИЯ ВЫЗВАНА!")
		else:
			print("ОШИБКА: MapManager не найден в дереве сцены!")
	else:
		print("--- Игнорируем, зашел не Player, а: ", body.name)
