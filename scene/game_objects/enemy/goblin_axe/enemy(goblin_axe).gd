extends CharacterBody2D
var hp = 20
@onready var anim = $AnimatedSprite2D
@onready var animP = $AnimationPlayer
var max_speed = randf_range(100,130)
var damage = 10
var player: Node2D = null
var parent_node: Node = null
var room_node: Node2D = null
#enum Dir { DOWN, UP, LEFT, RIGHT }
#var current_dir = Dir.DOWN
var can_anim = true
var direction


func _ready() -> void:
	# Находим игрока по группе
	player = get_tree().get_first_node_in_group("player") as Node2D
	parent_node = get_parent()
	room_node = parent_node.get_parent()

func _physics_process(delta: float) -> void:
	
	if player and is_instance_valid(player) :
		var to_player: Vector2 = player.position - self.position - room_node.position
		var distance := to_player.length()
		
		if parent_node.aggression==true:
			if can_anim:
				direction = to_player.normalized()
			velocity = max_speed * direction
			move_and_slide()
			
			if abs(direction.x) > abs(direction.y):
				if direction.x > 0:
					if can_anim:
						anim.play("run_right")
					else:
						animP.play("attack_right")
					
				else:
					if can_anim:
						anim.play("run_left")
					else:
						animP.play("attack_left")
					
			else:
				if direction.y > 0:
					if can_anim:
						anim.play("run_down")
					else:
						animP.play("attack_down")
					
				else:
					if can_anim:
						anim.play("run_up")
					else:
						animP.play("attack_up")
					
		else:
			
			velocity = Vector2.ZERO
			anim.play("idle_down")
			
	else:
		velocity = Vector2.ZERO
		anim.play("idle_down")
		
		
func _process(delta):
	if hp == 0:
		queue_free()
		return
	
func attack():
	can_anim = false
	
	
	max_speed=max_speed*1.7
	
	await animP.animation_finished
	max_speed=max_speed/1.7
	can_anim = true	


func _on_detector_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		attack()


func _on_attack_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player = get_tree().get_first_node_in_group("player") as Node2D
		player.take_damage(damage)

func _on_attack_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player = get_tree().get_first_node_in_group("player") as Node2D
		player.take_damage(damage)

#func _on_hitbox_body_entered(body: Node2D) -> void:
	#if body.name == "Player":
		#player = get_tree().get_first_node_in_group("player") as Node2D
		#player.take_damage(10)





func _on_hitbox_area_entered(area: Area2D) -> void:
	hp=hp-10 # Replace with function body.
