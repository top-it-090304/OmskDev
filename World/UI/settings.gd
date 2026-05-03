extends Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Ставим игру на паузу при открытии меню настроек
	get_tree().paused = true

func _on_texture_button_4_pressed() -> void:
	# Возобновляем игру при закрытии настроек
	get_tree().paused = false
	queue_free()