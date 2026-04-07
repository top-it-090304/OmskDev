extends CharacterBody2D

@export var atack_spawn: Node
var max_speed = 200
@onready var anim = $AnimatedSprite2D
var max_health = 100
var health_int = 100
var can_take_damage = true
@onready var damage_timer = $can_take_damage

enum Dir { DOWN, UP, LEFT, RIGHT }
var current_dir = Dir.DOWN
var can_move = true
var can_anim = true
var is_dead = false # Флаг, чтобы не вызывать die() повторно

signal health_changed(new_health, max_health)

func _physics_process(_delta: float) -> void:
	if is_dead: return # Если мертв, физику не обрабатываем
	
	if atack_spawn.ready_for_animation and can_anim:
		attack()

func _process(delta: float) -> void:
	if is_dead: return # Если мертв, ввод и движение не обрабатываем
	
	if health_int <= 0:
		die()
		return

	var direction = movement_vector()
	
	if direction != Vector2.ZERO:
		velocity = direction * max_speed
		update_direction(direction)
		if can_anim:
			play_walk_animation()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, max_speed)
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
	can_anim = false
	match current_dir:
		Dir.UP: anim.play("attack_up")
		Dir.DOWN: anim.play("attack_down")
		Dir.LEFT: anim.play("attack_left")
		Dir.RIGHT: anim.play("attack_right")
	await anim.animation_finished
	atack_spawn.ready_for_animation = false
	can_anim = true
	
func take_damage(amount: int):
	if not can_take_damage or is_dead:
		return
	
	can_take_damage = false
	health_int -= amount
	health_changed.emit(health_int, max_health)
	
	if health_int <= 0:
		die()
		return

	# Анимация получения урона
	can_anim = false
	match current_dir:
		Dir.UP: anim.play("hurt_up")
		Dir.DOWN: anim.play("hurt_down")
		Dir.LEFT: anim.play("hurt_left")
		Dir.RIGHT: anim.play("hurt_right")
	
	await anim.animation_finished
	can_anim = true
	damage_timer.start()
		
func heal(amount: int):
	if is_dead: return
	health_int = min(max_health, health_int + amount)
	health_changed.emit(health_int, max_health)

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
	queue_free()

func _on_hitbox_body_entered(body: Node2D) -> void:
	if is_dead: return
	if body.is_in_group("enemys"):
		take_damage(10)

func _on_can_take_damage_timeout() -> void:
	can_take_damage = true
