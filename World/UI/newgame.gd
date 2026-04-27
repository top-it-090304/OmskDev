extends TextureButton

@export var target_scene1: PackedScene

func _on_pressed() -> void:
	print("=== НОВАЯ ИГРА ===")

	# Сбрасываем все значения к базовым
	SaveSystem.reset_to_base_values()

	# Удаляем старое сохранение
	SaveSystem.delete_save()

	# Запускаем игру
	get_tree().change_scene_to_packed(target_scene1)
