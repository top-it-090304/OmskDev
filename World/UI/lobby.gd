extends Control

@onready var code_label: Label = $Panel/VBoxContainer/CodeRow/code_label
@onready var status_label: Label = $Panel/VBoxContainer/status_label
@onready var player_list: VBoxContainer = $Panel/VBoxContainer/PlayerList
@onready var start_button: TextureButton = $Panel/VBoxContainer/start_button

var _peers: Array[int] = []

func _ready() -> void:
	# Иначе @rpc("authority") из лобби может не уходить с хоста (authority != SERVER_ID)
	if NetworkManager.is_multiplayer_active():
		set_multiplayer_authority(NetworkManager.SERVER_ID)

	start_button.visible = NetworkManager.is_hosting()
	start_button.disabled = true

	NetworkManager.player_connected.connect(_on_peer_connected)
	NetworkManager.player_disconnected.connect(_on_peer_disconnected)
	NetworkManager.disconnected_from_server.connect(_on_disconnected)

	if NetworkManager.is_hosting():
		_peers.append(NetworkManager.my_id)
		code_label.text = NetworkManager.encode_ip(_get_local_ip())
		_set_status("Ожидание игроков...")
	else:
		code_label.text = "——"
		_set_status("Подключено. Ожидание хоста...")
		SaveSystem.delete_dungeon_state()

	_rebuild_player_list()

func _get_local_ip() -> String:
	for addr in IP.get_local_addresses():
		if addr.begins_with("192.") or addr.begins_with("10.") or addr.begins_with("172."):
			return addr
	return "127.0.0.1"

func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(code_label.text)

func _on_peer_connected(id: int) -> void:
	_peers.append(id)
	_rebuild_player_list()
	_set_status("Игрок подключился!")
	start_button.disabled = false

func _on_peer_disconnected(id: int) -> void:
	_peers.erase(id)
	_rebuild_player_list()
	_set_status("Игрок отключился")
	start_button.disabled = _peers.size() < 2

func _on_disconnected() -> void:
	get_tree().change_scene_to_file("res://World/UI/multiplayer_menu.tscn")

func _on_back_pressed() -> void:
	NetworkManager.disconnect_game()
	get_tree().change_scene_to_file("res://World/UI/multiplayer_menu.tscn")

func _set_status(text: String) -> void:
	status_label.text = "Статус: " + text

func _rebuild_player_list() -> void:
	for child in player_list.get_children():
		child.queue_free()
	for i in _peers.size():
		var lbl := Label.new()
		var is_host := _peers[i] == NetworkManager.SERVER_ID
		lbl.text = "Игрок %d%s" % [i + 1, " (хост)" if is_host else ""]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		player_list.add_child(lbl)

func _on_start_button_pressed() -> void:
	if not NetworkManager.is_hosting():
		return
	var peers_to_spawn: Array = _peers.duplicate()
	_rpc_start_game.rpc(peers_to_spawn)

@rpc("authority", "call_local", "reliable")
func _rpc_start_game(peers_to_spawn: Array) -> void:
	_load_game(peers_to_spawn)

func _load_game(peers_to_spawn: Array) -> void:
	# Новый кооп-ран: данж генерирует только хост; старый dungeon_state у гостя перезапишется по RPC
	if NetworkManager.is_hosting():
		SaveSystem.delete_dungeon_state()
	PlayerManager.pending_peers = peers_to_spawn
	get_tree().change_scene_to_file("res://World/layer.tscn")
