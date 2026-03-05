extends Node2D

@export var ability:Node
var ready_for_animation=false
var last_attack_time :=0
var cooldown = 1000



func _process(delta):	



	if  Input.is_action_just_pressed("attack"):
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
	match player.current_dir:
		player.Dir.UP: ability.get_node("Top").get_node("CollisionShape2D").disabled = false
		player.Dir.DOWN:ability.get_node("Bot").get_node("CollisionShape2D").disabled = false
		player.Dir.LEFT: ability.get_node("Left").get_node("CollisionShape2D").disabled = false
		player.Dir.RIGHT: ability.get_node("Right").get_node("CollisionShape2D").disabled = false
		
	ready_for_animation=true
	await get_tree().create_timer(0.05).timeout
	ability.get_node("Top").get_node("CollisionShape2D").disabled = true
	ability.get_node("Bot").get_node("CollisionShape2D").disabled = true
	ability.get_node("Left").get_node("CollisionShape2D").disabled = true
	ability.get_node("Right").get_node("CollisionShape2D").disabled = true
