extends Node2D


func _on_area_2d_area_entered(area: Area2D) -> void:
	var player_node = get_tree().get_first_node_in_group("player")
	player_node.max_speed += 70
	#player.backpack.instance_node(boots_of_travel.sprite)
	queue_free() # Replace with function body.
