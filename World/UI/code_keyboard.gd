extends PanelContainer

signal key_pressed(value: String)
signal backspace_pressed
signal clear_pressed
signal done_pressed

@export var key_font: Font
@export var key_font_size := 13
@export var button_min_size := Vector2(42, 22)

const KEY_ROWS: Array[Array] = [
	["1", "2", "3", "4", "5", "6", "7", "8"],
	["9", "0", "A", "B", "C", "D", "E", "F"],
]


func _ready() -> void:
	_build()


func _build() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0.78)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left = 6
	panel_style.content_margin_top = 6
	panel_style.content_margin_right = 6
	panel_style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", panel_style)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 3)
	add_child(rows)

	for row_values in KEY_ROWS:
		var row := _make_row()
		rows.add_child(row)
		for key in row_values:
			var button := _make_button(key)
			button.pressed.connect(_on_key_pressed.bind(key))
			row.add_child(button)

	var actions := _make_row()
	rows.add_child(actions)

	var backspace_button := _make_button("Del", Vector2(72, 22))
	backspace_button.pressed.connect(func() -> void: backspace_pressed.emit())
	actions.add_child(backspace_button)

	var clear_button := _make_button("Очистить", Vector2(110, 22))
	clear_button.pressed.connect(func() -> void: clear_pressed.emit())
	actions.add_child(clear_button)

	var done_button := _make_button("Готово", Vector2(100, 22))
	done_button.pressed.connect(func() -> void: done_pressed.emit())
	actions.add_child(done_button)


func _make_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 3)
	return row


func _make_button(text: String, min_size := button_min_size) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.focus_mode = Control.FOCUS_NONE
	if key_font:
		button.add_theme_font_override("font", key_font)
	button.add_theme_font_size_override("font_size", key_font_size)
	return button


func _on_key_pressed(value: String) -> void:
	key_pressed.emit(value)
