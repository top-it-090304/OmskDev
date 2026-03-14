extends Node
var aggression=false

func _on_room_shape_area_entered(area: Area2D) -> void:
	aggression=true


func _on_room_shape_area_exited(area: Area2D) -> void:
	aggression=false
