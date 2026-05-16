extends Control

@onready var title_label = $Panel/VBoxContainer/TitleLabel
@onready var stats_container = $Panel/VBoxContainer/StatsContainer

var stat_lines: Array = []

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate.a = 0.0
	scale = Vector2(0.5, 0.5)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3)

	await get_tree().create_timer(3.0, true, false, true).timeout
	fade_out()

func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventScreenTouch and event.pressed:
		fade_out()
	elif event is InputEventMouseButton and event.pressed:
		fade_out()

func set_artefact_info(artefact_name: String, _description: String):
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
