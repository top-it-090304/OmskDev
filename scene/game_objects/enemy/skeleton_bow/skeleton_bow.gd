extends CharacterBody2D

const ARROW = preload("res://scene/game_objects/enemy/skeleton_bow/arrow.tscn")

@export var hp = 20
@export var damage = 20
@onready var animP = $AnimationPlayer
@onready var attack_timer = $attack_timer
@onready var anim = $AnimatedSprite2D

var max_speed = randf_range(70, 160)
var player: Node2D = null
var parent_node: Node = null
var room_node: Node2D = null

enum Dir { DOWN, UP, LEFT, RIGHT }
var current_dir = Dir.DOWN

var can_move = true
var can_attack = true
var player_in_range = false
var get_closer = true

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D
	parent_node = get_parent()
	room_node = parent_node.get_parent()

func _physics_process(_delta: float) -> void:
	if not player or not is_instance_valid(player) or not can_move:
		velocity = Vector2.ZERO
		return

	var to_player: Vector2 = player.global_position - global_position
	var direction = to_player.normalized()
	
	update_direction(direction)

	if parent_node.aggression and get_closer:
		velocity = direction * max_speed
		play_run_animation()
		move_and_slide()
	else:
		velocity = Vector2.ZERO

func _process(_delta):
	if hp <= 0:
		queue_free()

func update_direction(dir: Vector2):
	if abs(dir.x) > abs(dir.y):
		current_dir = Dir.LEFT if dir.x < 0 else Dir.RIGHT
	else:
		current_dir = Dir.UP if dir.y < 0 else Dir.DOWN

func play_run_animation():
	match current_dir:
		Dir.UP: anim.play("run_up")
		Dir.DOWN: anim.play("run_down")
		Dir.LEFT: anim.play("run_left")
		Dir.RIGHT: anim.play("run_right")

func play_idle_animation():
	match current_dir:
		Dir.UP: anim.play("idle_up")
		Dir.DOWN: anim.play("idle_down")
		Dir.LEFT: anim.play("idle_left")
		Dir.RIGHT: anim.play("idle_right")

func attack():
	if not can_attack or not player_in_range:
		return
		
	can_move = false
	can_attack = false
	anim.stop()
	match current_dir:
		Dir.UP: animP.play("attack_up")
		Dir.DOWN: animP.play("attack_down")
		Dir.LEFT: animP.play("attack_left")
		Dir.RIGHT: animP.play("attack_right")
	
	await animP.animation_finished
	
	can_move = true
	attack_timer.start()

func shoot():
	if not player: return
	var arrow_instance = ARROW.instantiate()
	arrow_instance.global_position = global_position 
	
	var target_dir = (player.global_position - global_position).normalized()
	arrow_instance.direction = target_dir
	arrow_instance.rotation = target_dir.angle()
	arrow_instance.z_index = 1
	get_parent().add_child(arrow_instance)

	

func _on_detector_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		get_closer = true 

func _on_attack_timer_timeout():
	can_attack = true
	if player_in_range:
		attack()

func _on_hitbox_area_entered(_area: Area2D) -> void:
	hp -= 10


func _on_detector_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		get_closer = false 
		if can_attack:
			attack()
