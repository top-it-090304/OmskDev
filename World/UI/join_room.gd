extends Control

@onready var code_input: LineEdit = $Panel/VBoxContainer/CodeInput
@onready var error_label: Label = $Panel/VBoxContainer/ErrorLabel


func _ready() -> void:
	error_label.text = ""
	# Кросс-платформа: код LAN (8 hex), полный IPv4 или доменное имя / DynDNS + опционально :порт
	code_input.max_length = 0
	code_input.virtual_keyboard_enabled = true
	code_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	code_input.focus_mode = Control.FOCUS_ALL
	if not code_input.focus_entered.is_connected(_on_code_input_focus_entered):
		code_input.focus_entered.connect(_on_code_input_focus_entered)
	if not code_input.focus_exited.is_connected(_on_code_input_focus_exited):
		code_input.focus_exited.connect(_on_code_input_focus_exited)
	code_input.call_deferred("grab_focus")


func _on_code_input_focus_entered() -> void:
	# На Android/iOS иногда не поднимается IME только от LineEdit — дублируем явным запросом.
	if not _want_platform_virtual_keyboard():
		return
	var r := Rect2(code_input.get_global_rect())
	DisplayServer.virtual_keyboard_show(r)


func _on_code_input_focus_exited() -> void:
	if not _want_platform_virtual_keyboard():
		return
	DisplayServer.virtual_keyboard_hide()


func _want_platform_virtual_keyboard() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("Android") or OS.has_feature("iOS")


func _on_paste_pressed() -> void:
	# Не upper() — ломает доменные имена; HEX-код нормализуем при подключении.
	code_input.text = DisplayServer.clipboard_get().strip_edges()


func _on_connect_pressed() -> void:
	var trimmed := code_input.text.strip_edges()
	var parsed: Dictionary = NetworkManager.parse_join_target(trimmed)
	if parsed.get("ok") != true:
		error_label.text = str(parsed.get("err", "Ошибка"))
		return
	var address: String = str(parsed.get("address", ""))
	var port: int = int(parsed.get("port", NetworkManager.DEFAULT_PORT))
	if address.is_empty():
		error_label.text = "Пустой адрес"
		return
	error_label.text = "Подключение к %s:%d..." % [address, port]
	var up := trimmed.to_upper()
	NetworkManager.lobby_display_code = up if up.length() == 8 and up.is_valid_hex_number() else trimmed

	if not NetworkManager.connected_to_server.is_connected(_on_connected):
		NetworkManager.connected_to_server.connect(_on_connected, CONNECT_ONE_SHOT)
	if not NetworkManager.connection_failed.is_connected(_on_connection_failed):
		NetworkManager.connection_failed.connect(_on_connection_failed, CONNECT_ONE_SHOT)

	NetworkManager.join_game(address, port)


func _on_connected() -> void:
	get_tree().change_scene_to_file("res://World/UI/lobby.tscn")


func _on_connection_failed() -> void:
	error_label.text = "Сервер не отвечает"


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://World/UI/multiplayer_menu.tscn")
