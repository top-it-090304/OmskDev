# This is a basic level setup script for multiplayer spawning.
# Attach this to a node in your main scene (e.g., Root node).

extends Node

# Export the player scene to spawn.
@export var player_scene: PackedScene

# Multiplayer reference.
var multiplayer: MultiplayerAPI

func _ready():
	multiplayer = get_tree().multiplayer
	
	# Connect to multiplayer signals.
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	
	# If we are the host, also spawn for already connected peers.
	if multiplayer.is_server():
		for peer_id in multiplayer.get_peers():
			_spawn_player(peer_id)
	
	# Spawn the local player (unless it's a dedicated server).
	if not OS.has_feature("dedicated_server"):
		_spawn_player(multiplayer.get_unique_id())

func _on_player_connected(id):
	_spawn_player(id)

func _on_player_disconnected(id):
	# Find and remove the player node for the disconnected peer.
	var player_node = find_player(id)
	if player_node:
		player_node.queue_free()

func _spawn_player(player_id):
	var player_instance = player_scene.instantiate()
	# Set the player ID (this will set the multiplayer authority for the input via the setter in Player.gd).
	player_instance.player = player_id
	
	# Add the player to the scene (under a "Players" node for organization).
	var players_node = get_node_or_null("Players")
	if players_node:
		players_node.add_child(player_instance)
	else:
		add_child(player_instance)
	
	# Optional: set a random spawn position.
	# var spawn_pos = Vector3(randf() * 10 - 5, 0, randf() * 10 - 5)
	# player_instance.global_transform.origin = spawn_pos

func find_player(player_id):
	# Assuming player nodes are under a "Players" node or directly under this node.
	var players_node = get_node_or_null("Players")
	if players_node:
		return players_node.get_node_or_null(str(player_id))
	return get_node_or_null(str(player_id))