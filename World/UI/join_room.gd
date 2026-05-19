extends Control

const CodeKeyboard := preload("res://World/UI/code_keyboard.gd")

@onready var code_input: LineEdit = $Panel/VBoxContainer/CodeInput
@onready var error_label: Label = $Panel/VBoxContainer/ErrorLabel
@onready var back_button: TextureButton = $Panel/VBoxContainer/BackButton
@onready var panel: Panel = $Panel
@onready var panel_box: VBoxContainer = $Panel/VBoxContainer

var _code_keyboard: Control
var _syncing_code_input := false


func _ready() -> void:
	NetworkManager.reset_menu_navigation_flags()
	error_label.text = ""
	code_input.virtual_keyboard_enabled = false
	_ignore_button_label_mouse($Panel/VBoxContainer/PasteButton)
	_ignore_button_label_mouse($Panel/VBoxContainer/ConnectButton)
	_ignore_button_label_mouse(back_button)
	code_input.text_changed.connect(_on_code_input_text_changed)
	code_input.focus_entered.connect(_show_virtual_keyboard)
	code_input.gui_input.connect(_on_code_input_gui_input)
	if not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	_create_code_keyboard()
	_apply_mobile_layout()
	if panel:
		panel.z_index = 2
	if _code_keyboard:
		_code_keyboard.z_index = 0
	call_deferred("_focus_code_input")


func _apply_mobile_layout() -> void:
	if panel == null or panel_box == null:
		return
	var compact := get_viewport_rect().size.y <= 320.0
	# Панель выше HEX-клавиатуры (anchor_top 0.62), иначе «Назад» не нажимается.
	panel.anchor_bottom = 0.56 if compact else 0.58
	panel_box.add_theme_constant_override("separation", 2 if compact else 4)
	_set_font_size($Panel/VBoxContainer/Title, 11 if compact else 14)
	_set_font_size(code_input, 11 if compact else 13)
	_set_font_size(error_label, 8 if compact else 10)
	for button in [
		$Panel/VBoxContainer/PasteButton,
		$Panel/VBoxContainer/ConnectButton,
		$Panel/VBoxContainer/BackButton,
	]:
		button.custom_minimum_size = Vector2(172, 22) if compact else Vector2(125, 24)
		var label := button.get_node_or_null("Label") as Label
		if label:
			_set_font_size(label, 10 if compact else 14)
			label.clip_text = true
	_set_button_text($Panel/VBoxContainer/PasteButton, "Вставить")
	_set_button_text($Panel/VBoxContainer/ConnectButton, "Войти" if compact else "Подключиться")
	_set_button_text($Panel/VBoxContainer/BackButton, "Назад")
	code_input.custom_minimum_size = Vector2(172, 22) if compact else Vector2(125, 24)
	if _code_keyboard:
		_layout_code_keyboard(compact)


func _set_font_size(control: Control, size: int) -> void:
	if control:
		control.add_theme_font_size_override("font_size", size)


func _set_button_text(button: Control, text: String) -> void:
	var label := button.get_node_or_null("Label") as Label
	if label:
		label.text = text


func _ignore_button_label_mouse(button: Control) -> void:
	for child in button.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func _focus_code_input() -> void:
	# Только фокус: клавиатура по тапу в поле, чтобы не перекрыть «Назад» при входе.
	code_input.grab_focus()


func _on_code_input_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		code_input.grab_focus()
		_show_virtual_keyboard()


func _on_code_input_text_changed(new_text: String) -> void:
	if _syncing_code_input:
		return
	var sanitized := _sanitize_code(new_text)
	if sanitized != new_text:
		_set_code_text(sanitized, code_input.caret_column)


func _show_virtual_keyboard() -> void:
	if _code_keyboard:
		_code_keyboard.visible = true


func _hide_virtual_keyboard() -> void:
	if _code_keyboard:
		_code_keyboard.visible = false


func _create_code_keyboard() -> void:
	_code_keyboard = CodeKeyboard.new()
	_code_keyboard.name = "CodeKeyboard"
	_code_keyboard.visible = false
	_code_keyboard.mouse_filter = Control.MOUSE_FILTER_STOP
	if code_input.has_theme_font("font"):
		_code_keyboard.key_font = code_input.get_theme_font("font")
	var compact := get_viewport_rect().size.y <= 320.0
	_code_keyboard.key_font_size = 10 if compact else 13
	_code_keyboard.button_min_size = Vector2(34, 19) if compact else Vector2(42, 22)
	_code_keyboard.action_button_min_size = Vector2(70, 20) if compact else Vector2(84, 24)
	_code_keyboard.row_separation = 2 if compact else 3
	_code_keyboard.button_separation = 2 if compact else 3
	_code_keyboard.key_pressed.connect(_on_code_keyboard_key_pressed)
	_code_keyboard.backspace_pressed.connect(_on_code_keyboard_backspace_pressed)
	_code_keyboard.clear_pressed.connect(_on_code_keyboard_clear_pressed)
	_code_keyboard.done_pressed.connect(_on_code_keyboard_done_pressed)
	add_child(_code_keyboard)
	_layout_code_keyboard(compact)


func _layout_code_keyboard(compact: bool) -> void:
	_code_keyboard.anchor_left = 0.03 if compact else 0.04
	_code_keyboard.anchor_top = 0.62
	_code_keyboard.anchor_right = 0.97 if compact else 0.96
	_code_keyboard.anchor_bottom = 0.98
	_code_keyboard.offset_left = 0
	_code_keyboard.offset_top = 0
	_code_keyboard.offset_right = 0
	_code_keyboard.offset_bottom = 0


func _on_code_keyboard_key_pressed(value: String) -> void:
	if code_input.text.length() >= code_input.max_length:
		return
	var caret := clampi(code_input.caret_column, 0, code_input.text.length())
	var new_text := code_input.text.substr(0, caret) + value + code_input.text.substr(caret)
	_set_code_text(new_text, caret + value.length())
	code_input.grab_focus()


func _on_code_keyboard_backspace_pressed() -> void:
	var text := code_input.text
	if text.is_empty():
		return
	var caret := clampi(code_input.caret_column, 0, text.length())
	if caret == 0:
		caret = text.length()
	_set_code_text(text.substr(0, caret - 1) + text.substr(caret), caret - 1)
	code_input.grab_focus()


func _on_code_keyboard_clear_pressed() -> void:
	_set_code_text("", 0)
	code_input.grab_focus()


func _on_code_keyboard_done_pressed() -> void:
	_hide_virtual_keyboard()
	code_input.release_focus()


func _set_code_text(value: String, caret_column := -1) -> void:
	var sanitized := _sanitize_code(value)
	_syncing_code_input = true
	code_input.text = sanitized
	code_input.caret_column = clampi(
		caret_column if caret_column >= 0 else sanitized.length(),
		0,
		sanitized.length()
	)
	_syncing_code_input = false


func _sanitize_code(value: String) -> String:
	var result := ""
	var upper := value.to_upper()
	for i in upper.length():
		var character := upper.substr(i, 1)
		if character.is_valid_hex_number():
			result += character
		if result.length() >= code_input.max_length:
			break
	return result


func _on_paste_pressed() -> void:
	_set_code_text(DisplayServer.clipboard_get().strip_edges())
	code_input.grab_focus()
	_show_virtual_keyboard()


func _on_connect_pressed() -> void:
	var input := code_input.text.strip_edges().to_upper()

	# ВАЖНО: IPv4 в HEX - это всегда 8 символов
	if input.length() != 8 or not input.is_valid_hex_number():
		error_label.text = "Неверный код (нужно 8 символов)"
		return

	var address := NetworkManager.decode_code(input)
	if address == "":
		error_label.text = "Ошибка декодирования"
		return

	error_label.text = "Подключение к " + address + "..."
	# Код комнаты до join: после успеха join_room может быть уже освобождён — не читать code_input в колбэке.
	NetworkManager.lobby_display_code = input

	# Подключаем сигналы один раз
	if not NetworkManager.connected_to_server.is_connected(_on_connected):
		NetworkManager.connected_to_server.connect(_on_connected, CONNECT_ONE_SHOT)
	if not NetworkManager.connection_failed.is_connected(_on_connection_failed):
		NetworkManager.connection_failed.connect(_on_connection_failed, CONNECT_ONE_SHOT)

	NetworkManager.join_game(address)


func _on_connected() -> void:
	_hide_virtual_keyboard()
	get_tree().change_scene_to_file("res://World/UI/lobby.tscn")


func _on_connection_failed() -> void:
	error_label.text = "Сервер не отвечает"


func _on_back_pressed() -> void:
	_hide_virtual_keyboard()
	get_tree().change_scene_to_file("res://World/UI/multiplayer_menu.tscn")
