extends Area2D

var is_open = false

func _ready() -> void:
	modulate.a = 0.0
	monitoring = false
	body_entered.connect(_on_body_entered)


func open_hatch() -> void:
	if is_open:
		return
	var mp := get_tree().get_multiplayer()
	if not mp.has_multiplayer_peer():
		_apply_hatch_open_visual()
	elif mp.is_server():
		rpc_hatch_opened.rpc()


func _apply_hatch_open_visual() -> void:
	is_open = true
	monitoring = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.6)


@rpc("authority", "call_local", "reliable")
func rpc_hatch_opened() -> void:
	_apply_hatch_open_visual()


func _on_body_entered(body: Node2D) -> void:
	if not is_open or not body.is_in_group("player"):
		return
	# Object.get() принимает только имя свойства; нет свойства — считаем одиночную игру (как «локальный»)
	var local_flag: Variant = body.get("is_local_player")
	if local_flag == false:
		return
	var mp := get_tree().get_multiplayer()
	if not mp.has_multiplayer_peer():
		_go_to_next_floor()
		return
	if mp.is_server():
		_go_to_next_floor.rpc()
	else:
		rpc_hatch_request_next_floor.rpc_id(NetworkManager.SERVER_ID)


@rpc("any_peer", "call_remote", "reliable")
func rpc_hatch_request_next_floor() -> void:
	if not multiplayer.is_server():
		return
	_go_to_next_floor.rpc()


@rpc("authority", "call_local", "reliable")
func _go_to_next_floor() -> void:
	GameConstants.CURRENT_FLOOR += 1
	GameConstants.ROOMS_CLEARED = 0
	GameConstants.save_to_disk()
	get_tree().change_scene_to_file("res://World/layer.tscn")
