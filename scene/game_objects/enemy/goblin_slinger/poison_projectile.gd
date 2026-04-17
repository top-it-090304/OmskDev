extends Area2D

var direction = Vector2.ZERO
var speed = 0.0
var lifetime = 5.0

func _ready() -> void:
	# Получаем значения из GameConstants
	speed = GameConstants.POISON_PROJECTILE_SPEED
	lifetime = GameConstants.POISON_DURATION

	# Автоудаление снаряда через lifetime секунд
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		queue_free()

func _process(delta: float) -> void:
	if direction != Vector2.ZERO:
		position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	# Игнорируем врагов
	if body.is_in_group("enemy"):
		return

	if body.is_in_group("player"):
		if body.has_method("apply_poison"):
			# Применяем яд к игроку используя константы из GameConstants
			body.apply_poison(
				GameConstants.POISON_DURATION,
				GameConstants.POISON_PROJECTILE_DAMAGE,
				GameConstants.POISON_TICK_RATE
			)
			print("Игрок отравлен! Длительность: ", GameConstants.POISON_DURATION, "с")

	# Удаляем снаряд при любом столкновении
	queue_free()
