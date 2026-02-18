extends CharacterBody2D

var max_speed = 200
var is_alive = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("enemy")
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if not is_alive:
		return
	var direction = get_direction_to_player().normalized()
	velocity = max_speed * direction
	move_and_slide()
		
	
func get_direction_to_player():
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		return (player.global_position - self.global_position)
	return Vector2(0,0)

func die():
	if not is_alive:
		return
	is_alive = false
	# Удаляем врага из сцены
	queue_free()	
