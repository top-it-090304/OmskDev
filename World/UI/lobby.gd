extends Control

@onready var status_label: Label = $VBoxContainer/status_label
@onready var players_label: Label = $VBoxContainer/players_label
@onready var start_button: Button = $VBoxContainer/start_button
@onready var my_id_label: Label = $VBoxContainer/HBoxContainer/my_id_label

var player_count: int = 0
var is_host: bool = false

func _ready() -> void:
	is_host = NetworkManager.connection_state == NetworkManager.ConnectionState.HOSTING

	my_id_label.text = str(NetworkManager.my_id)
	start_button.visible = is_host
	start_button.disabled = true

	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.disconnected_from_server.connect(_on_disconnected)

	if is_host:
		player_count = 1  # сам хост
		_update_ui("Статус: ожидание игроков...")
	else:
		_update_ui("Статус: подключение...")

func _on_player_connected(_id: int) -> void:
	player_count += 1
	_update_ui("Статус: игрок подключился")
	if is_host:
		start_button.disabled = false

func _on_player_disconnected(_id: int) -> void:
	player_count -= 1
	_update_ui("Статус: игрок отключился")
	if is_host:
		start_button.disabled = player_count < 2

func _on_connection_failed() -> void:
	_update_ui("Статус: ошибка подключения")

func _on_disconnected() -> void:
	_update_ui("Статус: отключено")
	get_tree().change_scene_to_file("res://World/UI/multiplayer_menu.tscn")

func _update_ui(status: String) -> void:
	status_label.text = status
	players_label.text = "Игроки: %d" % player_count

func _on_start_button_pressed() -> void:
	if not is_host:
		return
	rpc("_start_game")
	_start_game()

@rpc("authority", "call_remote", "reliable")
func _start_game() -> void:
	get_tree().change_scene_to_file("res://World/layer.tscn")
