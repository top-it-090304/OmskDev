extends Node

# Синглтон для тряски камеры (можно добавить в автозагрузку в project.godot, 
# но пока пусть живёт в сцене)

var trauma = 0.0
var trauma_power = 2.0  # Степень влияния травмы на смещение
var decay = 3.0         # Скорость затухания тряски

var rng = RandomNumberGenerator.new()

func _ready():
	rng.randomize()

func _process(delta):
	# Травма плавно уменьшается со временем
	trauma = max(trauma - decay * delta, 0.0)
	
	# Находим камеру на сцене (обычно это Camera2D в Layer или Player)
	var camera = get_viewport().get_camera_2d()
	if camera:
		# Смещение зависит от травмы в квадрате (для более резкого эффекта в начале)
		var shake_amount = pow(trauma, trauma_power)
		# Случайное смещение в пределах shake_amount
		camera.offset.x = rng.randf_range(-shake_amount, shake_amount)
		camera.offset.y = rng.randf_range(-shake_amount, shake_amount)

# Вызвать для запуска тряски
func add_trauma(amount: float):
	trauma = min(trauma + amount, 1.0)  # Максимум 1.0