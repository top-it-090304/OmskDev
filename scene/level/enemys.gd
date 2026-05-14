extends Node

var aggression: bool = false
var _players_in_room: int = 0
var _room_was_cleared = false  # Флаг для отслеживания зачистки комнаты
var _had_alive_enemy: bool = false  # Были живые враги (после queue_free детей уже 0)
var _network_clear_in_flight: bool = false  # Уже отправили зачистку в сеть (хост/клиент)


func _process(_delta: float) -> void:
	_update_aggression()

func _is_player_area(area: Area2D) -> bool:
	var p := area.get_parent()
	return p != null and p.is_in_group("player")

func _on_room_shape_area_entered(area: Area2D) -> void:
	if _is_player_area(area):
		_players_in_room += 1
		_update_aggression()

func _on_room_shape_area_exited(area: Area2D) -> void:
	if _is_player_area(area):
		_players_in_room = maxi(0, _players_in_room - 1)
		_update_aggression()

func _update_aggression() -> void:
	var alive_enemies = 0
	var boss_type = ""
	for child in get_children():
		if child.has_method("take_damage") and not child.get("is_dead"):
			alive_enemies += 1
			_had_alive_enemy = true
			# Определяем тип босса по имени файла сцены
			if child.scene_file_path:
				if "skeleton_king" in child.scene_file_path:
					boss_type = "skeleton_king"
				elif "beastGoblin" in child.scene_file_path or "beast_goblin" in child.scene_file_path:
					boss_type = "beast_goblin"

	var player_in_room: bool = _players_in_room > 0
	var new_aggression: bool = player_in_room and alive_enemies > 0
	var prev_aggression: bool = aggression
	if new_aggression != aggression:
		aggression = new_aggression
		if aggression:
			var room = get_parent()
			if room and room.get("is_boss_room"):
				AudioManager.play_boss(boss_type)
			else:
				AudioManager.play_combat()
		else:
			AudioManager.play_explore()

	# Кооп: при закрытии дверей подтягиваем союзника к тем, кто уже в комнате (только на хосте)
	if aggression and not prev_aggression:
		var mp := get_tree().get_multiplayer()
		if NetworkManager.is_game_offline() or mp.is_server():
			PlayerManager.host_pull_co_players_into_combat_room(self)

	if alive_enemies == 0 and not _room_was_cleared and _had_alive_enemy:
		var mp := get_tree().get_multiplayer()
		var room = get_parent()
		if NetworkManager.is_game_online() and room != null and "grid_x" in room and "grid_y" in room:
			if not _network_clear_in_flight:
				_network_clear_in_flight = true
				if mp.is_server():
					NetworkManager.rpc_cleanup_cleared_room.rpc(room.grid_x, room.grid_y)
				else:
					NetworkManager.rpc_request_room_cleared.rpc_id(NetworkManager.SERVER_ID, room.grid_x, room.grid_y)
		else:
			_room_was_cleared = true
			GameConstants.on_room_cleared()


func mark_cleared_by_network() -> void:
	_room_was_cleared = true
	_network_clear_in_flight = false
