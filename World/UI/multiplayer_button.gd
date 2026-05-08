extends TextureButton

# Ссылка на сцену мультиплеер меню
@export var scene_to_open: PackedScene

func _ready() -> void:
	# Если сцена не установлена через экспорт, устанавливаем по умолчанию
	if not scene_to_open:
		scene_to_open = preload("res://World/UI/multiplayer_menu.tscn")

func _on_pressed() -> void:
	get_tree().change_scene_to_file(scene_to_open.get_path())
