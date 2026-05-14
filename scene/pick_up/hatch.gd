extends Area2D

var is_open = false


func _ready() -> void:
	modulate.a = 0.0
	monitoring = false
	body_entered.connect(_on_body_entered)


func open_hatch() -> void:
	if is_open:
		return
	if NetworkManager.is_game_offline():
		_apply_hatch_open_visual()
		return
	if get_tree().get_multiplayer().is_server():
		rpc_hatch_opened.rpc()


func _apply_hatch_open_visual() -> void:
	is_open = true
	monitoring = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.6)


## Публичная обёртка для MapManager / RPC (приватный _apply не виден has_method на некоторых версиях Godot).
func apply_hatch_open_visual() -> void:
	_apply_hatch_open_visual()


## Восстановление после загрузки сейва (без RPC / твина)
func apply_save_open_state() -> void:
	is_open = true
	monitoring = true
	modulate.a = 1.0


@rpc("authority", "call_local", "reliable")
func rpc_hatch_opened() -> void:
	_apply_hatch_open_visual()


func _on_body_entered(body: Node2D) -> void:
	if not is_open or not body.is_in_group("player"):
		return
	var local_flag: Variant = body.get("is_local_player")
	if local_flag == false:
		return
	if NetworkManager.is_game_offline():
		_go_to_next_floor_solo()
		return
	var mp := get_tree().get_multiplayer()
	if mp.is_server():
		NetworkManager.rpc_coop_transition_next_floor.rpc()
	else:
		NetworkManager.rpc_request_coop_next_floor.rpc_id(NetworkManager.SERVER_ID)


func _go_to_next_floor_solo() -> void:
	AudioManager.play_sfx("люк_переход")
	# Новый этаж — люк босса снова закрыт (иначе флаг из прошлого этажа открывает люк сразу).
	SaveSystem.set_boss_hatch_opened(false)
	# Синхронизируем рюкзак и артефакты в SaveSystem до смены сцены (иначе новый backpack пустой)
	SaveSystem.save_game()
	GameConstants.CURRENT_FLOOR += 1
	GameConstants.ROOMS_CLEARED = 0
	GameConstants.save_to_disk()
	get_tree().change_scene_to_file("res://World/layer.tscn")
