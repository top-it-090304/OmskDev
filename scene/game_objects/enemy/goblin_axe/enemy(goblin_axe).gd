extends CharacterBody2D
var hp = 20
@onready var anim = $AnimatedSprite2D
@onready var animP = $AnimationPlayer
var max_speed = randf_range(70,160)
var damage = 5
var player: Node2D = null
var parent_node: Node = null
var room_node: Node2D = null
enum Dir { DOWN, UP, LEFT, RIGHT }
var current_dir = Dir.DOWN
var can_move = true



func _ready() -> void:
	# Находим игрока по группе
	player = get_tree().get_first_node_in_group("player") as Node2D
	parent_node = get_parent()
	room_node = parent_node.get_parent()

func _physics_process(delta: float) -> void:
	
	if player and is_instance_valid(player) and can_move:
		var to_player: Vector2 = player.position - self.position - room_node.position
		var distance := to_player.length()
		
		if parent_node.aggression==true:
			var direction = to_player.normalized()
			velocity = max_speed * direction
			move_and_slide()
			if abs(direction.x) > abs(direction.y):
				if direction.x > 0:
					anim.play("run_right")
					current_dir = Dir.RIGHT
				else:
					anim.play("run_left")
					current_dir = Dir.LEFT
			else:
				if direction.y > 0:
					anim.play("run_down")
					current_dir = Dir.DOWN
				else:
					anim.play("run_up")
					current_dir = Dir.UP
		else:
			velocity = Vector2.ZERO
			anim.play("idle_down")
	else:
		velocity = Vector2.ZERO
		if can_move: 
			anim.play("idle_down")
		
		
func _process(delta):
	if hp == 0:
		queue_free()
		return
	
func attack():
	can_move = false
	anim.stop()
	match current_dir:
		Dir.UP: animP.play("attack_up")
		Dir.DOWN: animP.play("attack_down")
		Dir.LEFT: animP.play("attack_left")
		Dir.RIGHT: animP.play("attack_right")
		_: print("Ну как?")
	await animP.animation_finished
	can_move = true	


func _on_detector_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		attack()


func _on_attack_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player = get_tree().get_first_node_in_group("player") as Node2D
		player.health_int = player.health_int - 20
