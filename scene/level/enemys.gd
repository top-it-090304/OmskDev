extends Node

var aggression = false
var _player_in_room = false


func _process(delta: float) -> void:
	_update_aggression()
func _on_room_shape_area_entered(_area: Area2D) -> void:
	_player_in_room = true
	_update_aggression()

func _on_room_shape_area_exited(_area: Area2D) -> void:
	_player_in_room = false
	_update_aggression()




func _update_aggression() -> void:
	aggression = _player_in_room and get_child_count() > 0
