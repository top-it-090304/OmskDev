extends CharacterBody2D

var hp = 20
@onready var anim = $AnimatedSprite2D
@onready var animP = $AnimationPlayer
@onready var attack_timer = $attack_timer
enum Dir { DOWN, UP, LEFT, RIGHT }
var current_dir = Dir.DOWN
var max_speed = randf_range(70,160)
var damage = 10
var player: Node2D = null
var parent_node: Node = null
var room_node: Node2D = null
var can_walk = true
var direction = Vector2.ZERO
var can_attack = true
var player_in_range = false
var z=false

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D
	parent_node = get_parent()
	room_node = parent_node.get_parent()

func _physics_process(delta: float) -> void:
	
	if player and is_instance_valid(player):
		var to_player: Vector2 = player.global_position - global_position

		if z: #parent_node.aggression
			if can_walk:
				direction = to_player.normalized()

			velocity = max_speed * direction
			move_and_slide()

			if not can_walk:
				return
				
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
		anim.play("idle_down")

func _process(delta):
	if hp <= 0:
		queue_free()

func attack():
	if not can_attack or not player_in_range:
		return
	can_walk = false
	can_attack = false
	attack_timer.start()
	var old_speed = max_speed
	max_speed *= 1.3
	anim.stop()
	match current_dir:
		Dir.UP: animP.play("attack_up")
		Dir.DOWN: animP.play("attack_down")
		Dir.LEFT: animP.play("attack_left")
		Dir.RIGHT: animP.play("attack_right")
	await animP.animation_finished
	max_speed = old_speed
	can_walk = true

func _on_detector_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") :
		player_in_range = true
		if can_attack:
			attack()

func _on_detector_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false

func _on_attack_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.take_damage(damage)

func _on_attack_timer_timeout():
	can_attack = true
	if player_in_range:
		attack()
		

func _on_hitbox_area_entered(area: Area2D) -> void:
	hp -= 10
