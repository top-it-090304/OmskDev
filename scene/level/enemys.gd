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
	# Считаем только живых врагов (у которых нет флага is_dead)
	var alive_enemies = 0
	for child in get_children():
		if child.has_method("take_damage") and not child.get("is_dead"):
			alive_enemies += 1

	aggression = _player_in_room and alive_enemies > 0

	# Если все враги убиты и комната еще не была зачищена
	if alive_enemies == 0 and not _room_was_cleared and get_child_count() > 0:
		_room_was_cleared = true
		GameConstants.on_room_cleared()
		print("Комната зачищена! Уровень врагов: ", GameConstants.ENEMY_LEVEL)
