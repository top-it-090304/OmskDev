extends Node2D
@export var atack_ability: PackedScene


var last_attack_time :=0
var cooldown =1000
func _process(delta):	


	var at = Input.is_action_just_pressed("mouse_left_click")
	if at:
		if can_attack():
			place_player()	
	return
	
func can_attack() -> bool:
	var current_time = Time.get_ticks_msec() 
	if current_time - last_attack_time >= cooldown:
		last_attack_time = current_time
		return true
	return false	
func place_player():
		
	var player=get_tree().get_first_node_in_group("player") as Node2D
	if player==null:
		return 
	var attack_inst = atack_ability.instantiate() as Node2D
	player.add_child(attack_inst)
	attack_inst.global_position=player.global_position


	
