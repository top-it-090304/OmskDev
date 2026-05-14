extends Control

# Настройки сетки
@export var grid_columns: int = 8  # Количество колонок как в Isaac
@export var icon_size: int = 32  # Размер иконки
@export var icon_spacing: int = 4  # Отступ между иконками

# Контейнер для иконок
@onready var grid_container: GridContainer

var collected_artefacts: Array = []
var is_initialized_from_save: bool = false  # Флаг что уже загружено из сохранения

func _ready():
	add_to_group("backpack")
	setup_grid()
	
	# Очищаем локальный массив перед загрузкой из сохранения
	collected_artefacts.clear()
	
	# Восстанавливаем артефакты из сохранения
	if SaveSystem.has_collected_artefacts():
		is_initialized_from_save = true
		var saved_artefacts = SaveSystem.get_collected_artefacts()
		for artefact_data in saved_artefacts:
			# Загружаем иконку из пути
			var icon_texture = null
			if artefact_data.get("icon_path", "") != "":
				icon_texture = load(artefact_data["icon_path"])

			var artefact_info = {
				"name": artefact_data.get("name", "Unknown"),
				"icon": icon_texture,
				"icon_path": str(artefact_data.get("icon_path", "")),
				"description": artefact_data.get("description", "")
			}
			collected_artefacts.append(artefact_info)
			create_icon(artefact_info)
		print("Восстановлено артефактов из сохранения: ", collected_artefacts.size())
		# Синхронизируем с инвентарём (он может ещё не быть готов — откладываем на следующий кадр)
		call_deferred("_sync_inventory_on_load")

func setup_grid():
	# Создаем GridContainer если его нет
	if not grid_container:
		grid_container = GridContainer.new()
		add_child(grid_container)

	# Настраиваем сетку
	grid_container.columns = grid_columns
	grid_container.add_theme_constant_override("h_separation", icon_spacing)
	grid_container.add_theme_constant_override("v_separation", icon_spacing)

	# Позиционируем в правом верхнем углу
	grid_container.position = Vector2(10, 10)

func add_artefact(artefact_data) -> void:
	# Проверяем, нет ли уже такого артефакта (защита от дублей)
	var artefact_name = artefact_data.artefact_name if "artefact_name" in artefact_data else "Unknown"
	if has_artefact(artefact_name):
		print("Артефакт уже есть в рюкзаке, пропускаем: ", artefact_name)
		return
	
	# Сохраняем данные артефакта
	var artefact_info = {
		"name": artefact_name,
		"icon": artefact_data.artefact_icon if "artefact_icon" in artefact_data else null,
		"icon_path": artefact_data.artefact_icon.resource_path if (artefact_data.artefact_icon and "artefact_icon" in artefact_data) else "",
		"description": artefact_data.artefact_description if "artefact_description" in artefact_data else ""
	}

	for a in collected_artefacts:
		if a.get("name", "") == artefact_info["name"]:
			return

	collected_artefacts.append(artefact_info)

	# Создаем иконку
	create_icon(artefact_info)

	# Уведомляем инвентарь (только добавляем, не пересоздаём)
	var inventory = get_tree().get_first_node_in_group("inventory_screen")
	if inventory and inventory.has_method("add_artefact"):
		inventory.add_artefact(artefact_info)

	print("Артефакт добавлен в рюкзак: ", artefact_info["name"])


## Кооп: подбор по RPC без узла в дереве — словарь из NetworkManager.
func add_artefact_from_network(info: Dictionary) -> void:
	var artefact_name := str(info.get("name", "Unknown"))
	if has_artefact(artefact_name):
		print("Артефакт уже есть в рюкзаке (network), пропускаем: ", artefact_name)
		return
	var icon_texture = null
	var icon_path := str(info.get("icon_path", ""))
	if icon_path != "":
		icon_texture = load(icon_path)
	var artefact_info := {
		"name": artefact_name,
		"icon": icon_texture,
		"icon_path": icon_path,
		"description": str(info.get("description", "")),
	}
	for a in collected_artefacts:
		if a.get("name", "") == artefact_info["name"]:
			return
	collected_artefacts.append(artefact_info)
	create_icon(artefact_info)
	var tree := get_tree()
	if tree == null:
		return
	var inventory = tree.get_first_node_in_group("inventory_screen")
	if inventory and inventory.has_method("add_artefact"):
		inventory.add_artefact(artefact_info)
	print("Артефакт добавлен в рюкзак (network): ", artefact_info["name"])


func create_icon(artefact_info: Dictionary) -> void:
	# Создаем контейнер для иконки
	var icon_panel = PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(icon_size, icon_size)

	# Стилизация панели (темный фон с рамкой)
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style_box.border_color = Color(0.3, 0.3, 0.3, 1.0)
	style_box.border_width_left = 1
	style_box.border_width_right = 1
	style_box.border_width_top = 1
	style_box.border_width_bottom = 1
	icon_panel.add_theme_stylebox_override("panel", style_box)

	# Создаем TextureRect для иконки
	var texture_rect = TextureRect.new()
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.custom_minimum_size = Vector2(icon_size - 4, icon_size - 4)

	if artefact_info["icon"]:
		texture_rect.texture = artefact_info["icon"]
	else:
		# Если нет иконки, показываем заглушку
		texture_rect.modulate = Color(0.5, 0.5, 0.5, 1.0)

	icon_panel.add_child(texture_rect)

	# Добавляем tooltip с описанием
	icon_panel.tooltip_text = artefact_info["name"] + "\n" + artefact_info["description"]

	# Добавляем в сетку
	grid_container.add_child(icon_panel)

	# Анимация появления
	animate_icon_appear(icon_panel)

func animate_icon_appear(icon: Control) -> void:
	# Начинаем с маленького размера
	icon.scale = Vector2(0.1, 0.1)
	icon.modulate.a = 0.0

	# Анимация увеличения и появления
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)

	tween.tween_property(icon, "scale", Vector2(1.0, 1.0), 0.3)
	tween.tween_property(icon, "modulate:a", 1.0, 0.3)

func get_artefact_count() -> int:
	return collected_artefacts.size()

func has_artefact(artefact_name: String) -> bool:
	for artefact in collected_artefacts:
		if artefact["name"] == artefact_name:
			return true
	return false

func clear_backpack() -> void:
	collected_artefacts.clear()
	for child in grid_container.get_children():
		child.queue_free()

func get_collected_artefact_names() -> Array:
	var artefacts_data = []
	for artefact in collected_artefacts:
		artefacts_data.append({
			"name": artefact["name"],
			"icon_path": artefact.get("icon_path", ""),
			"description": artefact.get("description", "")
		})
	return artefacts_data


func _sync_inventory_on_load() -> void:
	var inventory = get_tree().get_first_node_in_group("inventory_screen")
	if inventory and inventory.has_method("clear_and_sync"):
		inventory.clear_and_sync(collected_artefacts)
