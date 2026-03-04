extends Node

@export var attack_ability: PackedScene
var attack_cooldown: float = 0.5  # Кулдаун в секундах
var last_attack_time: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float):
	
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_attack_time < attack_cooldown:
		return
	
	if Input.is_action_just_pressed("attack"):
		var player = get_tree().get_first_node_in_group("player") as Node2D
		if player == null:
			return
		
		
		var movement = Vector2.ZERO
		if player.has_method("movement_vector"):
			movement = player.movement_vector()

		var attack_direction = player.idle_dir  
		
		if movement.length() > 0:
			if abs(movement.x) > abs(movement.y):
				if movement.x > 0:
					attack_direction = player.RIGHT
				else:
					attack_direction = player.LEFT
			else:
				if movement.y > 0:
					attack_direction = player.DOWN
				else:
					attack_direction = player.UP
		

		var attack_rotation = 0.0
		var offset_position = Vector2.ZERO
		var offset_distance = 5.0
		
		match attack_direction:
			player.DOWN:
				attack_rotation = PI / 2
				offset_position = Vector2(0, offset_distance)
			player.UP:
				attack_rotation = -PI / 2
				offset_position = Vector2(0, -offset_distance)
			player.LEFT:
				attack_rotation = PI
				offset_position = Vector2(-offset_distance, 0)
			player.RIGHT:
				attack_rotation = 0.0
				offset_position = Vector2(offset_distance, 0)
		
		
		var attack_instance = attack_ability.instantiate() as Node2D
		
		player.add_child(attack_instance)
		attack_instance.global_position = player.global_position + offset_position
		
		last_attack_time = current_time
		


	
