extends Area2D


# Ссылка на корневую ноду самой комнаты
var parent_room_node: Node2D

func _ready():
	parent_room_node = get_parent()
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var manager = get_tree().get_first_node_in_group("map_manager")
	if manager == null:
		return
	var mp := get_tree().get_multiplayer()
	var gx: int = int(parent_room_node.grid_x)
	var gy: int = int(parent_room_node.grid_y)
	if mp.has_multiplayer_peer():
		if mp.is_server():
			manager.server_handle_coop_room_enter(Vector2i(gx, gy), body.get_multiplayer_authority())
		else:
			NetworkManager.rpc_report_room_enter_to_server.rpc_id(
				NetworkManager.SERVER_ID,
				gx,
				gy,
				body.get_multiplayer_authority()
			)
		return
	manager.change_current_room(gx, gy)
