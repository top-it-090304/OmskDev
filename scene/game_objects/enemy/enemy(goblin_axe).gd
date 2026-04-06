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
var can_attack = true
var player_in_range = false
var smite_instance: Node2D = null

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D
	parent_node = get_parent()
	if parent_node:
		room_node = parent_node.get_parent()

func _physics_process(_delta: float) -> void:
	if not can_walk:
		velocity = Vector2.ZERO
		move_and_slide()
		if not animP.is_playing():
			can_walk = true
			play_idle_animation()
		return

	var is_aggressive = parent_node and parent_node.get("aggression")
	
	if is_instance_valid(player) and is_aggressive:
		var to_player = player.global_position - global_position
		var direction = to_player.normalized()
		
		velocity = direction * max_speed
		move_and_slide()
		update_run_animation(direction)
	else:
		velocity = Vector2.ZERO
		move_and_slide()
		play_idle_animation()

func update_run_animation(direction: Vector2):
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

func _process(_delta):
	if hp <= 0:
		queue_free()

func attack():
	if not can_attack or not player_in_range:
		return
		
	can_walk = false
	can_attack = false
	
	anim.stop()
	
	match current_dir:
		Dir.UP: animP.play("attack_up")
		Dir.DOWN: animP.play("attack_down")
		Dir.LEFT: animP.play("attack_left")
		Dir.RIGHT: animP.play("attack_right")
		
	await animP.animation_finished
	
	if is_instance_valid(smite_instance):
		smite_instance.queue_free()
		smite_instance = null
		
	can_walk = true
	attack_timer.start()

func play_idle_animation():
	var target_idle = "idle_down"
	if anim.animation != target_idle:
		anim.play(target_idle)

func swing():
	if not is_instance_valid(player): return
	
	smite_instance = SMITE.instantiate()
	add_child(smite_instance)
	
	smite_instance.visible = false
	smite_instance.monitoring = false
	
	var target_dir = (player.global_position - global_position).normalized()
	if "direction" in smite_instance:
		smite_instance.direction = target_dir
		
	smite_instance.position = target_dir * 20 
	smite_instance.rotation = target_dir.angle()

func activate_smite():
	if is_instance_valid(smite_instance):
		smite_instance.visible = true
		smite_instance.monitoring = true

func _on_detector_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		if can_attack:
			attack()

func _on_detector_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false

func _on_attack_timer_timeout():
	can_attack = true
	var is_aggressive = parent_node and parent_node.get("aggression")
	if player_in_range and is_aggressive:
		attack()

func _on_hitbox_area_entered(_area: Area2D) -> void:
	hp -= 10

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(10)
