extends CharacterBody2D

var max_speed = 200
@onready var anim = $AnimatedSprite2D
enum{ DOWN, UP, LEFT, RIGHT }
var idle_dir = DOWN
func walk_process(vector:Vector2):
	if vector.x > 0:
		walk_right()
	elif vector.x < 0 :
		walk_left()
	elif vector.y < 0:
		walk_up()
	elif vector.y > 0:
		walk_down()
	else:
		anim_idle(idle_dir)
		
func walk_up():
	anim.play("walk_up")
	idle_dir = UP
func walk_down():
	anim.play("walk_down")
	idle_dir =  DOWN
func walk_left():
	anim.play("walk_left")
	idle_dir = LEFT
func walk_right():
	anim.play("walk_right")
	idle_dir = RIGHT
	
	
func anim_idle(idle_dir):
	match idle_dir:
		DOWN:
			anim.play("idle_down")
		UP:
			anim.play("idle_up")
		LEFT:
			anim.play("idle_left")
		RIGHT:
			anim.play("idle_right")
	
	
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var movement = movement_vector().normalized()
	velocity = max_speed * movement
	walk_process(movement)
	move_and_slide()
	
func movement_vector():
	var movement_x = Input.get_axis("move_left","move_right")
	var movement_y = Input.get_axis("move_up","move_down")
	return Vector2(movement_x, movement_y)
