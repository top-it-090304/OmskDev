extends CharacterBody2D
var hp = 20
@onready var anim = $AnimatedSprite2D
var max_speed = randf_range(70,160)
var damage = 5
var player: Node2D = null
var parent_node: Node = null
var room_node: Node2D = null
#const DETECTION_RADIUS := 100


func _ready() -> void:
	# Находим игрока по группе
	player = get_tree().get_first_node_in_group("player") as Node2D
	parent_node=get_parent()
	room_node=parent_node.get_parent()

func _physics_process(delta: float) -> void:
	if player and is_instance_valid(player):
		var to_player: Vector2 = player.position - self.position -room_node.position
		var distance := to_player.length()
		
		if parent_node.aggression==true:
			var direction = to_player.normalized()
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


func _on_area_2d_area_entered(area: Area2D) -> void:
	hp = hp - 10


#func _on_detector_body_entered(body: Node2D) -> void:
	#if body.name == "player":
		#player = body
		#print("detector entered:", body.name)
	


#func _on_detector_body_exited(body: Node2D) -> void:
	#if body.name == "player":
		#player = null
		#print("detector exited:", body.name)
	
