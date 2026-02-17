extends Node2D
@export var atack_ability: PackedScene
func _process(delta):
	var at= Input.is_action_just_pressed("mouse_left_click")
	if at:
		
		return place_player()
	return
	
func place_player():
	var player=get_tree().get_first_node_in_group("player") as Node2D
	if player==null:
		return 
	var attack_inst = atack_ability.instantiate() as Node2D
	player.add_child(attack_inst)
	attack_inst.global_position=player.global_position
	
	
