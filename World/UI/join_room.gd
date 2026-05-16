extends Control

@onready var code_input: LineEdit = $Panel/VBoxContainer/CodeInput
@onready var error_label: Label = $Panel/VBoxContainer/ErrorLabel


func _ready() -> void:
	error_label.text = ""
	code_input.text_changed.connect(_on_code_input_text_changed)
	code_input.focus_entered.connect(_show_virtual_keyboard)
	code_input.gui_input.connect(_on_code_input_gui_input)
	call_deferred("_focus_code_input")


func _focus_code_input() -> void:
	code_input.grab_focus()
	_show_virtual_keyboard()


func _on_code_input_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		code_input.grab_focus()
		_show_virtual_keyboard()


func _on_code_input_text_changed(new_text: String) -> void:
	var upper := new_text.to_upper()
	if upper != new_text:
		var caret := code_input.caret_column
		code_input.text = upper
		code_input.caret_column = mini(caret, upper.length())


func _show_virtual_keyboard() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return
	DisplayServer.virtual_keyboard_show(
		code_input.text,
		DisplayServer.VirtualKeyboardType.KEYBOARD_TYPE_DEFAULT,
		code_input.max_length
	)


func _on_paste_pressed() -> void:
	code_input.text = DisplayServer.clipboard_get().strip_edges().to_upper()
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
	DisplayServer.virtual_keyboard_hide()
	get_tree().change_scene_to_file("res://World/UI/lobby.tscn")


func _on_connection_failed() -> void:
	error_label.text = "Сервер не отвечает"


func _on_back_pressed() -> void:
	DisplayServer.virtual_keyboard_hide()
	get_tree().change_scene_to_file("res://World/UI/multiplayer_menu.tscn")
