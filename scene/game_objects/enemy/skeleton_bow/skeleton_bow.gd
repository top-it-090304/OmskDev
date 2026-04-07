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
var is_dead = false # Добавляем флаг смерти

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D
	parent_node = get_parent()

	if parent_node:
		room_node = parent_node.get_parent()

func _physics_process(_delta: float) -> void:
	if is_dead: return # Мертвые не ходят

	if not player or not is_instance_valid(player) or not can_move or not get_closer:
		velocity = Vector2.ZERO
		
		if not animP.is_playing():
			play_idle_animation()
		move_and_slide() 
		return

	var to_player: Vector2 = player.global_position - global_position
	var direction = to_player.normalized()
	
	update_direction(direction)

	if parent_node and parent_node.get("aggression") and get_closer:
		velocity = direction * max_speed
		play_run_animation()
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		play_idle_animation()

func _process(_delta):
	if hp <= 0 and not is_dead:
		death()

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
	if is_dead: return
	if anim.animation != "idle_down":
		anim.play("idle_down")

func attack():
	if not can_attack or not player_in_range or is_dead:
		return

	if parent_node and not parent_node.get("aggression"):
		return
		
	can_move = false
	can_attack = false
	
	match current_dir:
		Dir.UP: animP.play("attack_up")
		Dir.DOWN: animP.play("attack_down")
		Dir.LEFT: animP.play("attack_left")
		Dir.RIGHT: animP.play("attack_right")
	
	await animP.animation_finished
	
	if not is_dead:
		can_move = true
		attack_timer.start()

func shoot():
	# Эта функция вызывается из AnimationPlayer
	if not player or not is_instance_valid(player) or is_dead: return
	
	var arrow_instance = ARROW.instantiate()
	arrow_instance.global_position = global_position
	
	var target_dir = (player.global_position - global_position).normalized()
	arrow_instance.direction = target_dir
	arrow_instance.rotation = target_dir.angle()
	
	get_tree().current_scene.add_child(arrow_instance)

func _on_detector_body_entered(body: Node2D) -> void:
	if is_dead: return
	if body.is_in_group("player"):
		player_in_range = true
		get_closer = false 
		if can_attack:
			attack()

func _on_detector_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		get_closer = true 

func _on_attack_timer_timeout():
	if is_dead: return
	can_attack = true
	if player_in_range:
		attack()

func _on_hitbox_area_entered(_area: Area2D) -> void:
	if is_dead: return
	hp -= 10

func _on_hitbox_body_entered(body: Node2D) -> void:
	if is_dead: return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(10)

func death():
	is_dead = true
	can_move = false
	can_attack = false
	velocity = Vector2.ZERO
	
	# Отключаем физическое присутствие
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	
	# Останавливаем анимацию стрельбы, если она шла
	animP.stop()
	anim.stop()

	# Запускаем анимацию смерти
	match current_dir:
		Dir.UP: anim.play("death_up")
		Dir.DOWN: anim.play("death_down")
		Dir.LEFT: anim.play("death_left")
		Dir.RIGHT: anim.play("death_right")
		
	await anim.animation_finished
	queue_free()
