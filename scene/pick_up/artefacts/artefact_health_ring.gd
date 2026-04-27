extends Node2D

@export var artefact_name: String = "Health Ring"
@export var artefact_icon: Texture2D
@export var artefact_description: String = "+50 к максимальному здоровью"
@export var health_bonus: int = 50

func _ready():
	# Автоматически получаем иконку из Sprite2D
	if not artefact_icon and has_node("Sprite2D"):
		var sprite = get_node("Sprite2D")
		if sprite.texture:
			artefact_icon = sprite.texture

func _on_area_entered(area: Area2D) -> void:
	if area.get_parent().is_in_group("player"):
		var player = area.get_parent()
		pickup(player)

func pickup(player: Node) -> void:
	# Применяем эффект
	GameConstants.PLAYER_MAX_HEALTH += health_bonus
	print("Подобрано Health Ring! Здоровье увеличено на ", health_bonus)

	# Ищем Backpack в UI слое
	var backpack = get_tree().get_first_node_in_group("backpack")
	if not backpack:
		var root = get_tree().current_scene
		backpack = root.find_child("Backpack", true, false)

	if backpack and backpack.has_method("add_artefact"):
		backpack.add_artefact(self)
	else:
		print("ВНИМАНИЕ: Backpack не найден!")

	# Удаляем с карты
	queue_free()
