extends CharacterBody2D
var hp = 20
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
var max_speed = randf_range(70,160)
var damage = 5
@onready var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D


func _physics_process(delta: float) -> void:
	if player :
		var direction = (player.position - self.position).normalized()
		velocity = max_speed * direction
		move_and_slide()
		if abs(direction.x) > abs(direction.y):
			if direction.x > 0:
				anim.play("runRight")
			else:
				anim.play("runLeft")
		else:
			if direction.y > 0:
				anim.play("runDown")
			else:
				anim.play("runUp")
	else:
		velocity = Vector2.ZERO
		anim.play("idleDown")
		
		
func _process(delta):
	if hp == 0:
		queue_free()
		return
	
	
#func get_direction_to_player():
	#var player=get_tree().get_first_node_in_group("player") as Node2D
	#if player!=null:
		#return (player.global_position-self.global_position).normalized()
	#return Vector2.ZERO


#func _on_area_2d_area_entered(area: Area2D) -> void:
#	hp = hp - 10


func _on_detector_body_entered(body: Node2D) -> void:
	if body.name == "player":
		player = body
	


func _on_detector_body_exited(body: Node2D) -> void:
	if body.name == "player":
		player = null
	
