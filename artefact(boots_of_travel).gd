extends Node2D

@export var artefact_name: String = "Boots of Travel"
@export var artefact_icon: Texture2D
@export var artefact_description: String = "+70 к скорости"
@export var speed_bonus: int = 70

func _ready():
	# Автоматически получаем иконку из Sprite2D
	if not artefact_icon and has_node("Sprite2D"):
		var sprite = get_node("Sprite2D")
		if sprite.texture:
			artefact_icon = sprite.texture

func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.get_parent().is_in_group("player"):
		var player = area.get_parent()
		pickup(player)

func pickup(player: Node) -> void:
	# Применяем эффект
	GameConstants.PLAYER_MAX_SPEED += speed_bonus
	print("Подобраны Boots of Travel! Скорость увеличена на ", speed_bonus)

	# Ищем Backpack в UI слое
	var backpack = get_tree().get_first_node_in_group("backpack")
	if not backpack:
		# Пробуем найти через root
		var root = get_tree().current_scene
		backpack = root.find_child("Backpack", true, false)

	if backpack and backpack.has_method("add_artefact"):
		backpack.add_artefact(self)
	else:
		print("ВНИМАНИЕ: Backpack не найден!")

	# Удаляем с карты
	queue_free()
