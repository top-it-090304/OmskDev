extends Node2D

func _on_area_2d_area_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	if not parent.is_in_group("player"):
		return
	parent.heal(20)
	AudioManager.play_sfx("игрок_зелье")
	queue_free()
