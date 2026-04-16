extends Control

# Настройки сетки
@export var grid_columns: int = 8  # Количество колонок как в Isaac
@export var icon_size: int = 32  # Размер иконки
@export var icon_spacing: int = 4  # Отступ между иконками

# Контейнер для иконок
@onready var grid_container: GridContainer

var collected_artefacts: Array = []

func _ready():
	setup_grid()

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
	# Сохраняем данные артефакта
	var artefact_info = {
		"name": artefact_data.artefact_name if "artefact_name" in artefact_data else "Unknown",
		"icon": artefact_data.artefact_icon if "artefact_icon" in artefact_data else null,
		"description": artefact_data.artefact_description if "artefact_description" in artefact_data else ""
	}

	collected_artefacts.append(artefact_info)

	# Создаем иконку
	create_icon(artefact_info)

	print("Артефакт добавлен в рюкзак: ", artefact_info["name"])

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
