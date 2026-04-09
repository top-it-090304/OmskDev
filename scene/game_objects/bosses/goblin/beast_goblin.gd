extends CharacterBody2D

var hp = 0

@onready var anim = $AnimatedSprite2D
@onready var animP = $AnimationPlayer
@onready var attack_timer = $attack_timer

var speed = GameConstants.ENEMY_BEASTGOBLIN_MAX_SPEED
enum Dir { DOWN, UP, LEFT, RIGHT }
var current_dir = Dir.DOWN

var player: Node2D = null
var parent_node: Node = null

var can_walk = true
var can_attack = true
var can_anim = true 
var is_dead = false 

func _ready() -> void:
	hp = GameConstants.ENEMY_BEASTGOBLIN_HP
	player = get_tree().get_first_node_in_group("player") as Node2D
	parent_node = get_parent()
	
	# При старте сразу включаем покой
	_play_idle_animation()

func _physics_process(_delta: float) -> void:
	if is_dead: return 
	
	if not can_walk:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var is_aggressive = parent_node and parent_node.get("aggression")
	
	if is_instance_valid(player) and is_aggressive:
		var to_player = player.global_position - global_position
		var distance = to_player.length()
		var direction = to_player.normalized()
		
		velocity = direction * speed
		move_and_slide()
		
		if can_anim:
			update_run_animation(direction)
			
		# ВЫБОР АТАКИ
		if can_attack:
			if distance < 75:
				attack("bite")
			elif distance < 170:
				attack("slap")
			elif distance > 260:
				attack("shoot")
	else:
		velocity = Vector2.ZERO
		move_and_slide()
		if can_anim:
			_play_idle_animation()

func update_run_animation(direction: Vector2):
	if abs(direction.x) > abs(direction.y):
		current_dir = Dir.RIGHT if direction.x > 0 else Dir.LEFT
	else:
		current_dir = Dir.DOWN if direction.y > 0 else Dir.UP
	
	anim.play("run_" + _get_dir_string())

func attack(type: String):
	if not can_attack or is_dead: return
	
	can_attack = false
	can_walk = false
	can_anim = false
	anim.stop()
	
	var anim_name = type + "_" + _get_dir_string()
	
	if animP.has_animation(anim_name):
		animP.play(anim_name)
	else:
		animP.play("attack_" + _get_dir_string())
		
	await animP.animation_finished
	
	can_anim = true
	can_walk = true
	if not is_dead:
		attack_timer.start()

func _get_dir_string() -> String:
	match current_dir:
		Dir.UP: return "up"
		Dir.DOWN: return "down"
		Dir.LEFT: return "left"
		Dir.RIGHT: return "right"
	return "down"

# НОВАЯ РЕАЛИЗАЦИЯ: Только idle_down
func _play_idle_animation():
	if anim.animation != "idle_down":
		anim.play("idle_down")

func take_damage(amount: int):
	if is_dead: return
	hp -= amount
	can_walk = false
	can_anim = false 
	animP.stop() 
	
	if hp <= 0:
		death()
		return

	anim.play("hurt_" + _get_dir_string())
	await anim.animation_finished
	
	if not is_dead:
		can_anim = true
		can_walk = true
		can_attack = true

func death():
	if is_dead: return
	is_dead = true
	can_walk = false
	can_attack = false
	velocity = Vector2.ZERO 
	
	anim.stop()
	animP.stop()
	
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)

	# Учитываем опечатку death_dowm из твоего списка
	var d_string = _get_dir_string()
	var d_anim = "death_" + d_string
	if d_string == "down": d_anim = "death_dowm" # фикс под твой список
	
	anim.play(d_anim)
		
	await anim.animation_finished
	queue_free()

# --- ПРОВЕРКА ПОПАДАНИЙ С ОТЛЕТОМ ---

func _on_slap_body_entered(body: Node2D) -> void:
	if is_dead: return
	if body.is_in_group("player"):
		if body.has_method("apply_knockback"):
			body.apply_knockback(global_position, 800.0)
		if body.has_method("take_damage"):
			body.take_damage(GameConstants.ENEMY_BEASTGOBLIN_SLAP_DAMAGE)

func _on_bite_body_entered(body: Node2D) -> void:
	if is_dead: return
	if body.is_in_group("player"):
		if body.has_method("apply_knockback"):
			body.apply_knockback(global_position, 400.0)
		if body.has_method("take_damage"):
			body.take_damage(GameConstants.ENEMY_BEASTGOBLIN_BITE_DAMAGE)

func shoot():
	if is_dead or not is_instance_valid(player): return
	var arrow = GameConstants.SKELETON_BOW_ARROW.instantiate()
	arrow.global_position = global_position
	var dir = (player.global_position - global_position).normalized()
	if "direction" in arrow: arrow.direction = dir
	arrow.rotation = dir.angle()
	get_tree().current_scene.add_child(arrow)

func _on_attack_timer_timeout():
	can_attack = true

func _on_hitbox_area_entered(_area: Area2D) -> void:
	take_damage(GameConstants.ENEMY_BEASTGOBLIN_TAKE_DAMAGE)
