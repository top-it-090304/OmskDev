extends CharacterBody2D
var max_speed=200
func _process(delta) :
	var movement=movement_vector()
	var direction=movement.normalized()
	velocity=max_speed*direction
	return move_and_slide()
func movement_vector():
	var movement_x=Input.get_action_raw_strength("move_right")-Input.get_action_raw_strength("move_left")
	var movement_y=Input.get_action_raw_strength("move_down")-Input.get_action_raw_strength("move_up")
	return Vector2(movement_x,movement_y)
