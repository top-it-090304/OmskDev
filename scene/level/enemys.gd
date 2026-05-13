extends Node

var aggression: bool = false
var _players_in_room: int = 0
var _room_was_cleared = false  # Флаг для отслеживания зачистки комнаты


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
		if not mp.has_multiplayer_peer() or mp.is_server():
			PlayerManager.host_pull_co_players_into_combat_room(self)

	if alive_enemies == 0 and not _room_was_cleared and get_child_count() > 0:
		_room_was_cleared = true
		GameConstants.on_room_cleared()
