extends CharacterBody2D
var hp=20
var max_speed=150
func _process(delta) :
	if hp==0:
		queue_free()
		return
	var direction=get_direction_to_player()
	velocity=max_speed*direction
	return move_and_slide()
	
func get_direction_to_player():
	var player=get_tree().get_first_node_in_group("player") as Node2D
	if player!=null:
		return (player.global_position-self.global_position).normalized()
	return Vector2.ZERO


func _on_area_2d_area_entered(area: Area2D) -> void:
	hp=hp-10
