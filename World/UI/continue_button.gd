extends TextureButton

@export var target_scene: PackedScene

func _ready():
	# Проверяем наличие сохранения и активируем/деактивируем кнопку
	disabled = not SaveSystem.has_save()

	if disabled:
		modulate = Color(0.5, 0.5, 0.5, 0.7)  # Затемняем кнопку
	else:
		modulate = Color(1, 1, 1, 1)

func _on_pressed() -> void:
	print("=== ПРОДОЛЖИТЬ ИГРУ ===")

	# Загружаем сохранение
	if SaveSystem.load_game():
		NetworkManager.disconnect_game()
		# Перезапускаем музыку перед сменой сцены
		AudioManager.restart_music()
		# Запускаем игру
		get_tree().change_scene_to_packed(target_scene)
	else:
		push_error("Не удалось загрузить сохранение")
