extends Control

@onready var label = $Label

func _ready():
	print("Level Up Popup создан!")
	# Анимация появления и исчезновения
	var tween = create_tween()
	tween.set_parallel(true)

	# Движение вверх
	tween.tween_property(self, "position:y", position.y - 100, 1.5)

	# Fade out
	tween.tween_property(label, "modulate:a", 0.0, 1.5)

	# Масштабирование
	tween.tween_property(label, "scale", Vector2(1.5, 1.5), 0.3)

	# Удаляем после анимации
	await tween.finished
	queue_free()
