extends Button

@onready var timer = $Timer
var target_scene="res://world/ui/menu.tscn"
func _on_pressed() -> void:
	# 1. Отключаем кнопку, чтобы не было двойного нажатия при лаге
	set_deferred("disabled", true)
	
	# 2. Даем движку один кадр, чтобы обновить UI (показать нажатие)
	await get_tree().process_frame
	
	# 3. Переходим в меню
	get_tree().change_scene_to_file(target_scene)

func _on_timer_timeout() -> void:
	# Вызываем ту же логику
	get_tree().change_scene_to_file(target_scene)
