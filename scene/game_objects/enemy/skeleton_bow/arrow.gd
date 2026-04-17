extends Area2D

var direction = Vector2.ZERO
var speed = GameConstants.ARROW_SPEED
var lifetime = 5.0  # Автоудаление через 5 секунд

func _ready() -> void:
	# Автоудаление стрелы через 5 секунд
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		queue_free()

func _process(delta: float) -> void:
	# Если направление задано, летим строго по нему
	if direction != Vector2.ZERO:
		position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	# Игнорируем врагов, чтобы стрела не попадала в самого гоблина при вылете
	if body.is_in_group("enemy"): 
		return
		
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(GameConstants.ARROW_DAMAGE)
	
	# Удаляем стрелу при любом столкновении (стена или игрок)
	queue_free()
