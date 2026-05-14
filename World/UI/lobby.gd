extends Control

@onready var code_label: Label = $Panel/VBoxContainer/CodeRow/code_label
@onready var status_label: Label = $Panel/VBoxContainer/status_label
@onready var players_title: Label = $Panel/VBoxContainer/PlayersLabel
@onready var player_list: VBoxContainer = $Panel/VBoxContainer/PlayerList
@onready var start_button: TextureButton = $Panel/VBoxContainer/start_button

var _peers: Array[int] = []


func _ready() -> void:
	if NetworkManager.is_multiplayer_active():
		set_multiplayer_authority(NetworkManager.SERVER_ID)

	start_button.visible = true
	start_button.disabled = true

	NetworkManager.player_connected.connect(_on_peer_connected)
	NetworkManager.player_disconnected.connect(_on_peer_disconnected)
	NetworkManager.disconnected_from_server.connect(_on_disconnected)

	if NetworkManager.is_hosting():
		var code: String = NetworkManager.encode_ip(_get_local_ip())
		code_label.text = code
		NetworkManager.lobby_display_code = code
	else:
		code_label.text = NetworkManager.lobby_display_code if not NetworkManager.lobby_display_code.is_empty() else "——"
		SaveSystem.delete_dungeon_state()

	_refresh_peers_from_multiplayer()
	call_deferred("_refresh_peers_from_multiplayer")


func _get_local_ip() -> String:
	for addr in IP.get_local_addresses():
		if addr.begins_with("192.") or addr.begins_with("10.") or addr.begins_with("172."):
			return addr
	return "127.0.0.1"


func _room_capacity() -> int:
	return 1 + NetworkManager.MAX_CLIENT_PEERS


func _apply_unified_status() -> void:
	var cap := _room_capacity()
	_set_status("В комнате участников: %d из %d." % [_peers.size(), cap])


func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(code_label.text)


func _on_peer_connected(_id: int) -> void:
	_refresh_peers_from_multiplayer()


func _on_peer_disconnected(_id: int) -> void:
	_refresh_peers_from_multiplayer()


func _on_disconnected() -> void:
	get_tree().change_scene_to_file("res://World/UI/multiplayer_menu.tscn")


func _on_back_pressed() -> void:
	NetworkManager.disconnect_game()
	get_tree().change_scene_to_file("res://World/UI/multiplayer_menu.tscn")


func _set_status(text: String) -> void:
	status_label.text = "Статус: " + text


func _refresh_peers_from_multiplayer() -> void:
	var mp := get_tree().get_multiplayer()
	if not mp.has_multiplayer_peer():
		return
	var ids: Array[int] = []
	if mp.is_server():
		ids.append(NetworkManager.SERVER_ID)
		for p in mp.get_peers():
			if not ids.has(p):
				ids.append(p)
	else:
		if not ids.has(NetworkManager.SERVER_ID):
			ids.append(NetworkManager.SERVER_ID)
		var uid := mp.get_unique_id()
		if not ids.has(uid):
			ids.append(uid)
	ids.sort()
	_peers.clear()
	for id in ids:
		_peers.append(id)
	_rebuild_player_list()
	_apply_unified_status()
	_update_start_button_state()


func _rebuild_player_list() -> void:
	for child in player_list.get_children():
		child.queue_free()
	var cap := _room_capacity()
	players_title.text = "Игроки (%d/%d):" % [_peers.size(), cap]
	var mp := get_tree().get_multiplayer()
	var my_id := mp.get_unique_id() if mp.has_multiplayer_peer() else 0
	for i in _peers.size():
		var pid: int = _peers[i]
		var lbl := Label.new()
		var is_host := pid == NetworkManager.SERVER_ID
		var is_me := pid == my_id
		var tag := ""
		if is_host:
			tag = " (хост)"
		elif is_me:
			tag = " (вы)"
		lbl.text = "Игрок %d — id %d%s" % [i + 1, pid, tag]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		player_list.add_child(lbl)


func _update_start_button_state() -> void:
	if not NetworkManager.is_hosting():
		start_button.disabled = true
		start_button.tooltip_text = "Начать может только хост."
		return
	start_button.tooltip_text = "Запустить игру для всех в комнате."
	start_button.disabled = _peers.size() < 2


func _on_start_button_pressed() -> void:
	if not NetworkManager.is_hosting():
		return
	var peers_to_spawn: Array = _peers.duplicate()
	var coop_sync: Dictionary = GameConstants.capture_coop_start_state()
	_rpc_start_game.rpc(peers_to_spawn, coop_sync)


@rpc("authority", "call_local", "reliable")
func _rpc_start_game(peers_to_spawn: Array, coop_sync: Dictionary = {}) -> void:
	if NetworkManager.is_hosting():
		SaveSystem.delete_dungeon_state()
	if not coop_sync.is_empty():
		GameConstants.apply_coop_start_state(coop_sync)
	var norm: Array = []
	for v in peers_to_spawn:
		if typeof(v) == TYPE_INT:
			norm.append(v)
		elif typeof(v) == TYPE_FLOAT:
			norm.append(int(v))
	PlayerManager.pending_peers = norm
	# Не менять сцену синхронно из RPC: нода Lobby ещё в стеке вызова, возможны гонки с автозагрузами.
	get_tree().call_deferred("change_scene_to_file", "res://World/layer.tscn")
