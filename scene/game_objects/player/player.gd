extends CharacterBody2D
@export var atack_spawn:Node
var max_speed = 200
@onready var anim = $AnimatedSprite2D
var max_health = 100

enum Dir { DOWN, UP, LEFT, RIGHT }
var current_dir = Dir.DOWN
var can_move = true
signal health_changed(new_health, max_health)
var health_int = 50

#func _ready():
#	health_int = max_health
	
	
func _physics_process(_delta: float) -> void:
	if !can_move:

		return
	
	
	if atack_spawn.ready_for_animation==true:
		attack()
		return 

	var direction = movement_vector()
	
	if direction != Vector2.ZERO:
		velocity = direction * max_speed
		update_direction(direction)
		play_walk_animation()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, max_speed) #
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
	can_move = false
	match current_dir:
		Dir.UP: anim.play("attack_up")
		Dir.DOWN: anim.play("attack_down")
		Dir.LEFT: anim.play("attack_left")
		Dir.RIGHT: anim.play("attack_right")
	await anim.animation_finished
	
	
	atack_spawn.ready_for_animation=false
	can_move = true
func take_damage(amount: int):
	health_int = max(0, health_int - amount)
	health_changed.emit(health_int, max_health)
	if health_int == 0:
		die() 
func heal(amount: int):
	health_int = min(max_health, health_int + amount)
	health_changed.emit(health_int, max_health)
func _on_attack_placed(attack_instance: Node2D):
	# Здесь делайте то, что хотели (например, атаку)
	attack()
func die():
	queue_free()
