extends CharacterBody2D
const SMITE = preload("res://scene/game_objects/enemy/goblin_axe/smite.tscn")
var hp = 20
@onready var detector_shape = $detector/CollisionShape2D
@onready var anim = $AnimatedSprite2D
@onready var animP = $AnimationPlayer
@onready var attack_timer = $attack_timer
enum Dir { DOWN, UP, LEFT, RIGHT }
var current_dir = Dir.DOWN
var max_speed = 150
var damage = 10
var player: Node2D = null
var parent_node: Node = null
var room_node: Node2D = null
var can_walk = true
var direction = Vector2.ZERO
var can_attack = true
var player_in_range = false
var z = false
var smite_instance: Node2D = null

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D
	parent_node = get_parent()
	room_node = parent_node.get_parent()

func _physics_process(delta: float) -> void:
	if not can_walk:
		velocity = Vector2.ZERO # Останавливаем гоблина, чтобы он не скользил во время удара
		move_and_slide()
		play_idle_animation()
	if player and is_instance_valid(player):
		var to_player: Vector2 = player.global_position - global_position

		if parent_node.aggression!=null:
			if parent_node.aggression:
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
	
	var old_speed = max_speed
	max_speed *= 1.3
	anim.stop()
	match current_dir:
		Dir.UP: animP.play("attack_up")
		Dir.DOWN: animP.play("attack_down")
		Dir.LEFT: animP.play("attack_left")
		Dir.RIGHT: animP.play("attack_right")
	await animP.animation_finished
	if smite_instance and is_instance_valid(smite_instance):
		smite_instance.queue_free()
	smite_instance = null
	max_speed = old_speed
	can_walk = true
	attack_timer.start()

func _on_detector_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") :
		player_in_range = true
		if can_attack:
			attack()
			
func play_idle_animation():
	match current_dir:
		Dir.UP: anim.play("idle_up")
		Dir.DOWN: anim.play("idle_down")
		Dir.LEFT: anim.play("idle_left")
		Dir.RIGHT: anim.play("idle_right")
		
func _on_detector_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false

func _on_attack_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.take_damage(damage)

func _on_attack_timer_timeout():
	if player_in_range:
		attack()
		
func swing():
	if not player: return
	smite_instance = SMITE.instantiate()
	add_child(smite_instance)
	smite_instance.visible = false
	smite_instance.monitoring = false
	var target_dir = (player.global_position - global_position).normalized()
	smite_instance.direction = target_dir
	smite_instance.position = target_dir * detector_shape.shape.radius
	smite_instance.rotation = target_dir.angle()
	
func activate_smite():
	if is_instance_valid(smite_instance):
		smite_instance.visible = true
		smite_instance.monitoring = true
		
func _on_hitbox_area_entered(area: Area2D) -> void:
	hp -= 10
