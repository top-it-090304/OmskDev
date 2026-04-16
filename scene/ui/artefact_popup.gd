extends Control

@onready var title_label = $Panel/VBoxContainer/TitleLabel
@onready var stats_container = $Panel/VBoxContainer/StatsContainer

var stat_lines: Array = []

func _ready():
	print("ArtefactPopup _ready() вызван")
	# Анимация появления
	modulate.a = 0.0
	scale = Vector2(0.5, 0.5)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)

	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3)

	print("Popup анимация запущена")

	# Автоматически удаляем через 3 секунды
	await get_tree().create_timer(3.0).timeout
	print("Popup исчезает")
	fade_out()

func set_artefact_info(artefact_name: String, description: String):
	print("set_artefact_info вызван: ", artefact_name)
	title_label.text = artefact_name

func add_stat_line(text: String, color: Color = Color.WHITE):
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_font_size_override("font_size", 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_container.add_child(label)
	stat_lines.append(label)

func fade_out():
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN)

	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.3)

	await tween.finished
	queue_free()
