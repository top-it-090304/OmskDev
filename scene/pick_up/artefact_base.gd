extends Node2D
class_name ArtefactBase

# Информация об артефакте
@export var artefact_name: String = "Artefact"
@export var artefact_icon: Texture2D  # Иконка для рюкзака
@export var artefact_description: String = "Описание артефакта"

signal picked_up(artefact: ArtefactBase)

func _ready():
	# Автоматически получаем иконку из Sprite2D если не задана
	if not artefact_icon and has_node("Sprite2D"):
		var sprite = get_node("Sprite2D")
		if sprite.texture:
			artefact_icon = sprite.texture

func _on_area_entered(area: Area2D) -> void:
	if area.get_parent().is_in_group("player"):
		var player = area.get_parent()
		pickup(player)

func pickup(player: Node) -> void:
	# Применяем эффект артефакта
	apply_effect(player)

	# Добавляем в рюкзак
	if player.has_node("Backpack"):
		var backpack = player.get_node("Backpack")
		if backpack.has_method("add_artefact"):
			backpack.add_artefact(self)

	# Удаляем с карты
	queue_free()

# Переопределяется в наследниках
func apply_effect(player: Node) -> void:
	pass
