extends Node

var players: Dictionary = {}
var pending_peers: Array = []  # set by lobby before scene change
var _player_scene: PackedScene

func _ready() -> void:
	_player_scene = preload("res://scene/game_objects/player/player.tscn")
	NetworkManager.player_disconnected.connect(_despawn_player)
	NetworkManager.disconnected_from_server.connect(_on_disconnected)
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	# Detect when layer.tscn root node is added (scene finished loading)
	if node.name == "Layer" and node.get_parent() == get_tree().root:
		_on_game_scene_ready()

func _on_game_scene_ready() -> void:
	# Spawn local player
	_spawn_player(NetworkManager.my_id)
	# Host spawns remote peers
	for id in pending_peers:
		if id != NetworkManager.my_id:
			_spawn_player(id)
	pending_peers.clear()
	NetworkManager.game_started.emit()

func spawn_peer(peer_id: int) -> void:
	_spawn_player(peer_id)

func _spawn_player(player_id: int) -> void:
	if players.has(player_id):
		return
	var world := get_tree().current_scene
	if not world:
		push_error("PlayerManager: нет текущей сцены")
		return
	var instance := _player_scene.instantiate()
	instance.name = "Player_%d" % player_id
	instance.set_multiplayer_authority(player_id)
	world.add_child(instance)
	if player_id == NetworkManager.my_id:
		instance.is_local_player = true
	players[player_id] = instance

func _despawn_player(player_id: int) -> void:
	if not players.has(player_id):
		return
	players[player_id].queue_free()
	players.erase(player_id)

func _on_disconnected() -> void:
	for id in players.keys().duplicate():
		_despawn_player(id)
