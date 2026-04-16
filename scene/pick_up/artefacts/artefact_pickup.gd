extends Node2D
class_name ArtefactPickup

# Базовая информация
@export var artefact_name: String = "Artefact"
@export var artefact_icon: Texture2D
@export var artefact_description: String = "Описание"

# Эффекты (можно комбинировать)
@export_group("Stat Bonuses")
@export var speed_bonus: int = 0
@export var health_bonus: int = 0
@export var damage_bonus: int = 0
@export var health_per_level_bonus: int = 0
@export var speed_per_level_bonus: int = 0
@export var damage_per_level_bonus: int = 0

@export_group("Visual")
@export var pickup_sound: AudioStream
@export var glow_color: Color = Color(1, 1, 0, 0.5)

const ARTEFACT_POPUP = preload("res://scene/ui/artefact_popup.tscn")

var is_picked_up: bool = false
var stat_changes: Array = []

func _ready():
	# Автоматически получаем иконку из Sprite2D
	if not artefact_icon and has_node("Sprite2D"):
		var sprite = get_node("Sprite2D")
		if sprite.texture:
			artefact_icon = sprite.texture
		# Увеличиваем размер спрайта в 4 раза
		sprite.scale = Vector2(3.2, 3.2)

	# Добавляем свечение
	add_glow_effect()

func add_glow_effect():
	if has_node("Sprite2D"):
		var sprite = get_node("Sprite2D")
		# Простая анимация покачивания
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(sprite, "position:y", -5, 1.0).set_trans(Tween.TRANS_SINE)
		tween.tween_property(sprite, "position:y", 0, 1.0).set_trans(Tween.TRANS_SINE)

func _on_area_2d_area_entered(area: Area2D) -> void:
	if is_picked_up:
		return

	if area.get_parent().is_in_group("player"):
		var player = area.get_parent()
		pickup(player)

func pickup(player: Node) -> void:
	if is_picked_up:
		return
	is_picked_up = true

	# Очищаем массив изменений
	stat_changes.clear()

	# Применяем эффекты
	apply_effects()

	# Показываем popup
	show_stat_popup()

	# Добавляем в рюкзак
	add_to_backpack()

	# Анимация подбора
	play_pickup_animation()

	print("Подобран артефакт: ", artefact_name)

func apply_effects() -> void:
	# Базовые бонусы
	if speed_bonus != 0:
		GameConstants.PLAYER_MAX_SPEED += speed_bonus
		stat_changes.append({"text": "+%d к скорости" % speed_bonus, "color": Color(0.5, 1, 0.5)})
		print("  +", speed_bonus, " к скорости")

	if health_bonus != 0:
		GameConstants.PLAYER_MAX_HEALTH += health_bonus
		stat_changes.append({"text": "+%d к здоровью" % health_bonus, "color": Color(1, 0.5, 0.5)})
		print("  +", health_bonus, " к здоровью")

	if damage_bonus != 0:
		GameConstants.PLAYER_ATTACK_DAMAGE += damage_bonus
		stat_changes.append({"text": "+%d к урону" % damage_bonus, "color": Color(1, 0.7, 0.3)})
		print("  +", damage_bonus, " к урону")

	# Бонусы за уровень
	if health_per_level_bonus != 0:
		GameConstants.PLAYER_HEALTH_PER_LEVEL += health_per_level_bonus
		stat_changes.append({"text": "+%d здоровья за уровень" % health_per_level_bonus, "color": Color(1, 0.5, 0.5)})
		print("  +", health_per_level_bonus, " здоровья за уровень")

	if speed_per_level_bonus != 0:
		GameConstants.PLAYER_SPEED_PER_LEVEL += speed_per_level_bonus
		stat_changes.append({"text": "+%d скорости за уровень" % speed_per_level_bonus, "color": Color(0.5, 1, 0.5)})
		print("  +", speed_per_level_bonus, " скорости за уровень")

	if damage_per_level_bonus != 0:
		GameConstants.PLAYER_DAMAGE_PER_LEVEL += damage_per_level_bonus
		stat_changes.append({"text": "+%d урона за уровень" % damage_per_level_bonus, "color": Color(1, 0.7, 0.3)})
		print("  +", damage_per_level_bonus, " урона за уровень")

	# Вызываем кастомный эффект
	custom_effect()

# Переопределяется в наследниках для уникальных эффектов
func custom_effect() -> void:
	pass

func add_to_backpack() -> void:
	var backpack = get_tree().get_first_node_in_group("backpack")
	if not backpack:
		var root = get_tree().current_scene
		backpack = root.find_child("Backpack", true, false)

	if backpack and backpack.has_method("add_artefact"):
		backpack.add_artefact(self)

func play_pickup_animation() -> void:
	# Анимация подбора: увеличение и исчезновение
	var tween = create_tween()
	tween.set_parallel(true)

	if has_node("Sprite2D"):
		var sprite = get_node("Sprite2D")
		tween.tween_property(sprite, "scale", Vector2(2, 2), 0.3)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.3)

	tween.tween_property(self, "modulate:a", 0.0, 0.3)

	await tween.finished
	queue_free()

func show_stat_popup() -> void:
	if stat_changes.is_empty():
		print("ВНИМАНИЕ: stat_changes пуст, popup не будет показан")
		return

	print("Создаем popup для артефакта: ", artefact_name)
	var popup = ARTEFACT_POPUP.instantiate()

	# Ищем UI слой (CanvasLayer)
	var ui_layer = get_tree().get_first_node_in_group("ui_layer")
	if not ui_layer:
		# Пробуем найти через root
		var root = get_tree().current_scene
		ui_layer = root.find_child("UI", true, false)

	if ui_layer:
		print("Добавляем popup в UI слой")
		ui_layer.add_child(popup)
	else:
		print("UI слой не найден, добавляем в root")
		get_tree().root.add_child(popup)

	# Устанавливаем название артефакта
	popup.set_artefact_info(artefact_name, artefact_description)

	# Добавляем все изменения характеристик
	for change in stat_changes:
		popup.add_stat_line(change["text"], change["color"])
		print("  Добавлена строка в popup: ", change["text"])
