extends Node2D
func _on_area_2d_area_entered(area: Area2D) -> void:
	# Получаем первого игрока в группе (более прямой способ)
	var player_node = get_tree().get_first_node_in_group("player")
	player_node.health += 20
	queue_free() # Replace with function body.
