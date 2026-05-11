extends Node

var aggression = false
var _player_in_room = false
var _room_was_cleared = false  # Флаг для отслеживания зачистки комнаты


func _process(delta: float) -> void:
	_update_aggression()

func _on_room_shape_area_entered(_area: Area2D) -> void:
	_player_in_room = true
	_update_aggression()

func _on_room_shape_area_exited(_area: Area2D) -> void:
	_player_in_room = false
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

	var new_aggression = _player_in_room and alive_enemies > 0
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

	if alive_enemies == 0 and not _room_was_cleared and get_child_count() > 0:
		_room_was_cleared = true
		GameConstants.on_room_cleared()
