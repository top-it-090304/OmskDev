extends TextureButton
@export var scene_to_open: PackedScene

var _opened_scene: Node = null

func _on_pressed() -> void:
	if scene_to_open == null:
		return
	if _opened_scene != null and is_instance_valid(_opened_scene):
		return
	if NetworkManager.is_game_online() and scene_to_open.resource_path == NetworkManager.PAUSED_SCENE.resource_path:
		NetworkManager.open_coop_pause()
		return
	_opened_scene = scene_to_open.instantiate()
	get_parent().add_child(_opened_scene)
	_opened_scene.tree_exited.connect(_on_opened_scene_closed)


func _on_opened_scene_closed() -> void:
	_opened_scene = null


func _on_player_child_exiting_tree(_node: Node) -> void:
	disabled = false
	visible = true
