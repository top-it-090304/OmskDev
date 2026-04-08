extends CharacterBody2D

@export var atack_spawn: Node

@onready var anim = $AnimatedSprite2D
var health_int = 0
var can_take_damage = true
@onready var damage_timer = $can_take_damage
@onready var attack_timer = $can_attack
@onready var animP = $AnimationPlayer
enum Dir { DOWN, UP, LEFT, RIGHT }
var current_dir = Dir.DOWN
var can_move = true
var can_anim = true
var can_attack = true
var is_dead = false 
var last_known_max_health = 0
var damage = 20

signal health_changed(new_health, max_health)

func _physics_process(_delta: float) -> void:
	if is_dead: return
	

func _process(delta: float) -> void:
	if is_dead: return
	
	if health_int <= 0:
		die()
		return
	if Input.is_action_just_pressed("attack"):
		attack()
	var direction = movement_vector()
	
	if direction != Vector2.ZERO:
		velocity = direction * GameConstants.PLAYER_MAX_SPEED
		update_direction(direction)
		if can_anim:
			play_walk_animation()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, GameConstants.PLAYER_MAX_SPEED)
		if can_anim:
			play_idle_animation()

	move_and_slide()

func movement_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down").normalized()

func update_direction(dir_vec: Vector2):
	if abs(dir_vec.x) > abs(dir_vec.y):
		current_dir = Dir.LEFT if dir_vec.x < 0 else Dir.RIGHT
	else:
		current_dir = Dir.UP if dir_vec.y < 0 else Dir.DOWN

func play_walk_animation():
	match current_dir:
		Dir.UP: anim.play("walk_up")
		Dir.DOWN: anim.play("walk_down")
		Dir.LEFT: anim.play("walk_left")
		Dir.RIGHT: anim.play("walk_right")

func play_idle_animation():
	match current_dir:
		Dir.UP: anim.play("idle_up")
		Dir.DOWN: anim.play("idle_down")
		Dir.LEFT: anim.play("idle_left")
		Dir.RIGHT: anim.play("idle_right")

func attack():
	if not can_attack or is_dead:
		return
	
	can_anim = false
	can_attack = false
	
	# Запускаем анимацию через AnimationPlayer
	match current_dir:
		Dir.UP: animP.play("attack_up")
		Dir.DOWN: animP.play("attack_down")
		Dir.LEFT: animP.play("attack_left")
		Dir.RIGHT: animP.play("attack_right")
	
	# Ждем завершения анимации именно в AnimationPlayer!
	await animP.animation_finished
	


	can_anim = true
	attack_timer.start()
	
func take_damage(amount: int):
	if not can_take_damage or is_dead:
		return
	
	# Сразу сбрасываем всё, чтобы персонаж не "завис"
	can_anim = false 
	
	can_take_damage = false
	health_int -= amount
	health_changed.emit(health_int, GameConstants.PLAYER_MAX_HEALTH)
	
	if health_int <= 0:
		die()
		return

	# Анимация получения урона ПЕРЕБИВАЕТ атаку
	match current_dir:
		Dir.UP: anim.play("hurt_up")
		Dir.DOWN: anim.play("hurt_down")
		Dir.LEFT: anim.play("hurt_left")
		Dir.RIGHT: anim.play("hurt_right")
	
	await anim.animation_finished
	
	# Важно: после завершения анимации боли возвращаем управление
	if not is_dead:
		can_anim = true
		damage_timer.start()

func die():
	if is_dead: return
	is_dead = true
	can_anim = false
	velocity = Vector2.ZERO 
	
	match current_dir:
		Dir.UP: anim.play("death_up")
		Dir.DOWN: anim.play("death_down")
		Dir.LEFT: anim.play("death_left")
		Dir.RIGHT: anim.play("death_right")
	
	await anim.animation_finished
	get_tree().change_scene_to_file("res://world/UI/menu.tscn")
	queue_free()

func _on_hitbox_body_entered(body: Node2D) -> void:
	if is_dead: return
	if body.is_in_group("enemys"):
		take_damage(GameConstants.PLAYER_ENEMY_CONTACT_DAMAGE)

func _on_can_take_damage_timeout() -> void:
	can_take_damage = true

func _ready() -> void:
	health_int = GameConstants.PLAYER_MAX_HEALTH
	last_known_max_health = GameConstants.PLAYER_MAX_HEALTH
	if not GameConstants.constants_changed.is_connected(_on_constants_changed):
		GameConstants.constants_changed.connect(_on_constants_changed)
	health_changed.emit(health_int, GameConstants.PLAYER_MAX_HEALTH)

func _on_constants_changed() -> void:
	var new_max = GameConstants.PLAYER_MAX_HEALTH
	if new_max > last_known_max_health:
		health_int = min(health_int * 2, new_max)
	elif health_int > new_max:
		health_int = new_max
	last_known_max_health = new_max
	health_changed.emit(health_int, new_max)


func _on_can_attack_timeout() -> void:
	can_attack = true


func _on_hitbox_attack_body_entered(body: Node2D) -> void:
	print("Удар по объекту: ", body.name)
	if is_dead: return
	if body.is_in_group("enemies"):
		body.take_damage(damage)
