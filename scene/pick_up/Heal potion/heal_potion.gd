extends Node2D

func _on_area_2d_area_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	if not parent.is_in_group("player"):
		return
	if parent.has_method("can_heal") and not parent.can_heal():
		return
	if not parent.has_method("heal"):
		return
	parent.heal(20)
	AudioManager.play_sfx("игрок_зелье")
	queue_free()
