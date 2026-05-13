extends Control

@onready var code_input: LineEdit = $Panel/VBoxContainer/CodeInput
@onready var error_label: Label = $Panel/VBoxContainer/ErrorLabel

func _ready() -> void:
	error_label.text = ""
	code_input.grab_focus()

func _on_paste_pressed() -> void:
	code_input.text = DisplayServer.clipboard_get().strip_edges().to_upper()

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
	
	# Подключаем сигналы один раз
	if not NetworkManager.connected_to_server.is_connected(_on_connected):
		NetworkManager.connected_to_server.connect(_on_connected, CONNECT_ONE_SHOT)
	if not NetworkManager.connection_failed.is_connected(_on_connection_failed):
		NetworkManager.connection_failed.connect(_on_connection_failed, CONNECT_ONE_SHOT)
	
	NetworkManager.join_game(address)

func _on_connected() -> void:
	NetworkManager.lobby_display_code = code_input.text.strip_edges().to_upper()
	get_tree().change_scene_to_file("res://World/UI/lobby.tscn")

func _on_connection_failed() -> void:
	error_label.text = "Сервер не отвечает"

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://World/UI/multiplayer_menu.tscn")
