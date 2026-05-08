extends Control

# Reference to the NetworkManager instance (we'll try to get it from root)
var network_manager

# Keep track of connected players count
var connected_players = 0

func _ready() -> void:
    # Try to get existing NetworkManager from root
    network_manager = get_node("/root/NetworkManager")
    if not network_manager:
        # If not found, create one and add to root
        network_manager = NetworkManager.new()
        get_tree().root.add_child(network_manager)
        network_manager.set_as_toplevel(true)
    
    # Connect to signals
    network_manager.connected_to_server.connect(_on_connected)
    network_manager.disconnected_from_server.connect(_on_disconnected)
    network_manager.player_connected.connect(_on_player_connected)
    network_manager.player_disconnected.connect(_on_player_disconnected)
    network_manager.connection_failed.connect(_on_connection_failed)
    
    # Initialize UI
    update_my_id_label()
    update_status_label("Статус: отключено")
    update_players_label()
    $start_button.disabled = true

func _on_host_button_pressed() -> void:
    network_manager.host_game()
    update_status_label("Статус: хостинг...")

func _on_join_button_pressed() -> void:
    var address = $ip_input.text.strip_edges()
    if address == "":
        address = "127.0.0.1"
    network_manager.join_game(address)
    update_status_label("Статус: подключение...")

func _on_start_button_pressed() -> void:
    # Start the game for all players
    get_tree().change_scene_to_file("res://World/layer.tscn")

func _on_connected() -> void:
    update_my_id_label()
    update_status_label("Статус: подключено как " + str(network_manager.my_id))
    # If we are the server, we already count ourselves
    if network_manager.my_id == network_manager.SERVER_ID:
        connected_players = 1
    else:
        connected_players = 1  # we are a client, but we don't know others yet
    update_players_label()
    check_start_button()

func _on_disconnected() -> void:
    update_my_id_label()
    update_status_label("Статус: отключено")
    connected_players = 0
    update_players_label()
    $start_button.disabled = true

func _on_connection_failed() -> void:
    update_status_label("Статус: ошибка подключения")
    $start_button.disabled = true

func _on_player_connected(id) -> void:
    connected_players += 1
    update_players_label()
    check_start_button()

func _on_player_disconnected(id) -> void:
    connected_players -= 1
    update_players_label()
    check_start_button()

func update_my_id_label() -> void:
    if network_manager and network_manager.my_id:
        $my_id_label.text = str(network_manager.my_id)
    else:
        $my_id_label.text = "—"

func update_status_label(text) -> void:
    $status_label.text = text

func update_players_label() -> void:
    $players_label.text = "Игроки: %d/4" % [connected_players]

func check_start_button() -> void:
    # Enable start button if we are the host and have at least 2 players (including self)
    if network_manager and network_manager.connection_state == network_manager.ConnectionState.HOSTING:
        $start_button.disabled = connected_players < 2
    else:
        $start_button.disabled = true  # only host can start
