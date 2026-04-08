extends Node2D


func _on_area_2d_area_entered(area: Area2D) -> void:
	
	GameConstants.PLAYER_MAX_SPEED += 70
	#player.backpack.instance_node(boots_of_travel.sprite)
	queue_free() # Replace with function body.
