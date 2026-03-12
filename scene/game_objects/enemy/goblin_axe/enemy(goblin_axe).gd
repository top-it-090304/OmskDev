extends CharacterBody2D

# basic stats
var hp = 20
@onready var anim = $AnimatedSprite2D
var max_speed = 70
var damage = 5
var player: Node2D = null
<<<<<<< Updated upstream
const DETECTION_RADIUS := 220.0
=======
var parent_node: Node = null
var cooldown = 1000
# movement / attacking helpers
enum Dir { DOWN, UP, LEFT, RIGHT }
var current_dir : Dir = Dir.DOWN
var can_move : bool = true

@export var attack_cooldown : float = 1.0  # seconds between swings
var last_attack_time : int = 0

@onready var ability : Node2D = $Atack_ability

#const DETECTION_RADIUS := 100
>>>>>>> Stashed changes


func _ready() -> void:
	# Находим игрока по группе
	player = get_tree().get_first_node_in_group("player") as Node2D
<<<<<<< Updated upstream

=======
	parent_node = get_parent()

	# ensure attack areas can see the player group and notify us when he steps in
	for dir_name in ["Top", "Bot", "Left", "Right"]:
		var area = ability.get_node(dir_name) as Area2D
		if area:
			# the player collision layer is 2 in the player scene
			area.collision_mask = 2
			area.connect("body_entered", Callable(self, "_on_attack_area_body_entered"))
>>>>>>> Stashed changes

func _physics_process(delta: float) -> void:
	if player and is_instance_valid(player):
		var to_player: Vector2 = player.position - self.position
		var distance := to_player.length()
<<<<<<< Updated upstream

		if distance <= DETECTION_RADIUS:
			var direction = to_player.normalized()
			velocity = max_speed * direction
			move_and_slide()
			if abs(direction.x) > abs(direction.y):
				if direction.x > 0:
					anim.play("runRight")
				else:
					anim.play("runLeft")
			else:
				if direction.y > 0:
					anim.play("runDown")
				else:
					anim.play("runUp")
=======
		# update facing direction regardless of movement
		update_direction(to_player)

		if parent_node.aggression == true:
			# attempt a swing if the player got close enough
			if can_move and distance < 40 and can_attack():
				perform_attack()
				return # skip movement while attacking

			if can_move:
				var direction = to_player.normalized()
				velocity = max_speed * direction
				move_and_slide()
				play_run_animation(direction)
>>>>>>> Stashed changes
		else:
			velocity = Vector2.ZERO
			anim.play("idleDown")
	else:
		velocity = Vector2.ZERO
		anim.play("idleDown")
		
		
func _process(delta):
	if hp == 0:
		queue_free()
		return
	
	
#func get_direction_to_player():
	#var player=get_tree().get_first_node_in_group("player") as Node2D
	#if player!=null:
		#return (player.global_position-self.global_position).normalized()
	#return Vector2.ZERO


#func _on_area_2d_area_entered(area: Area2D) -> void:
#	hp = hp - 10

# helper that updates `current_dir` based on a vector
func update_direction(dir_vec: Vector2) -> void:
	if dir_vec == Vector2.ZERO:
		return
	if abs(dir_vec.x) > abs(dir_vec.y):
		current_dir = Dir.LEFT if dir_vec.x < 0 else Dir.RIGHT
	else:
		current_dir = Dir.UP if dir_vec.y < 0 else Dir.DOWN

<<<<<<< Updated upstream
func _on_detector_body_entered(body: Node2D) -> void:
	if body.name == "player":
		player = body
		print("detector entered:", body.name)
=======
func play_run_animation(direction: Vector2) -> void:
	if abs(direction.x) > abs(direction.y):
		anim.play("runRight") if direction.x > 0 else anim.play("runLeft")
	else:
		anim.play("runDown") if direction.y > 0 else anim.play("runUp")

func can_attack() -> bool:
	var current_time = Time.get_ticks_msec() 
	if current_time - last_attack_time >= cooldown:
		last_attack_time = current_time
		return true
	return false	

# called when one of the small attack areas picks up a body – this is the actual hitbox
# (enabled briefly in perform_attack()). just deal damage on contact.
func _on_attack_area_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)

# swing animation and optionally toggle hitbox momentarily
func perform_attack() -> void:
	can_move = false
	velocity = Vector2.ZERO
	# choose animation based on direction
	match current_dir:
		Dir.UP: anim.play("attackUp")
		Dir.DOWN: anim.play("attackDown")
		Dir.LEFT: anim.play("attackLeft")
		Dir.RIGHT: anim.play("attackRight")
	# make a brief hit‑window using the ability shapes
	var node_name := ""
	match current_dir:
		Dir.UP: node_name = "Top"
		Dir.DOWN: node_name = "Bot"
		Dir.LEFT: node_name = "Left"
		Dir.RIGHT: node_name = "Right"
	var shape = ability.get_node(node_name).get_node("CollisionShape2D") if ability else null
	if shape:
		shape.disabled = false
		# leave the hitbox up for a small window
		await get_tree().create_timer(0.2).timeout
		shape.disabled = true
	await anim.animation_finished
	can_move = true


func _on_detector_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		# player entered our detection radius, swing if ready
		if can_attack():
			perform_attack()
>>>>>>> Stashed changes
	


func _on_detector_body_exited(body: Node2D) -> void:
<<<<<<< Updated upstream
	if body.name == "player":
		player = null
		print("detector exited:", body.name)
=======
	if body.is_in_group("player"):
		# nothing to clean up
		pass
>>>>>>> Stashed changes
	
