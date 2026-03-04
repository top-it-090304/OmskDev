extends Node2D

@onready var area = $Area2D
var base_rotation: float = 0.0  # Базовый угол поворота в радианах

func _ready():
	# Подключаем сигнал для обнаружения столкновений
	if area:
		area.body_entered.connect(_on_body_entered)
		# Убеждаемся, что Area2D активен
		area.monitoring = true
		area.monitorable = false
	
	# Применяем базовый поворот к самому узлу
	# Это позволит анимации работать относительно этого поворота
	rotation = base_rotation

func set_attack_direction(direction_radians: float):
	# Устанавливаем базовый угол поворота меча (в радианах)
	# Поворачиваем сам узел, чтобы анимация работала относительно этого поворота
	base_rotation = direction_radians
	rotation = base_rotation

func _on_body_entered(body: Node2D):
	# Проверяем, что это враг
	if body.is_in_group("enemy"):
		# Вызываем функцию смерти врага
		if body.has_method("die"):
			body.die()
		else:
			print("Враг не имеет метода die()")
	else:
		print("Объект не в группе enemy: ", body.name)
