extends TextureButton

@export var scene_to_open: PackedScene

var _opened_scene: Node = null


func _ready() -> void:
	for child in get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_pressed() -> void:
	if scene_to_open == null:
		return
	if _opened_scene != null and is_instance_valid(_opened_scene):
		return
	var host := get_parent().get_parent()
	if host == null:
		return
	_opened_scene = scene_to_open.instantiate()
	host.add_child(_opened_scene)
	host.move_child(_opened_scene, -1)
	_opened_scene.tree_exited.connect(_on_opened_scene_closed)


func _on_opened_scene_closed() -> void:
	_opened_scene = null
