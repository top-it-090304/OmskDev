extends Node
@export var player_scene: PackedScene
var multiplayer: MultiplayerAPI
func _ready():
    multiplayer = get_tree().multiplayer
    multiplayer.peer_connected.connect(_on_player_connected)
    multiplayer.peer_disconnected.connect(_on_player_disconnected)
    if multiplayer.is_server():
        for pid in multiplayer.get_peers():
            _spawn_player(pid)
    if not OS.has_feature("dedicated_server"):
        _spawn_player(multiplayer.get_unique_id())
func _on_player_connected(id):
    _spawn_player(id)
func _on_player_disconnected(id):
    var player_node = find_player(id)
    if player_node:
        player_node.queue_free()
func _spawn_player(player_id):
    var instance = player_scene.instantiate()
    instance.player = player_id   # triggers setter in Player.gd to set authority
    var players = get_node_or_null("Players")
    if players:
        players.add_child(instance)
    else:
        add_child(instance)
    # Optional random spawn:
    # instance.global_transform.origin = Vector3(randf()*10-5, 0, randf()*10-5)
func find_player(player_id):
    var players = get_node_or_null("Players")
    if players:
        return players.get_node_or_null(str(player_id))
    return get_node_or_null(str(player_id))
Save each file with UTF‑8 encoding (no BOM) and LF line endings. Then attach the scripts as described earlier. This should avoid any decode errors.