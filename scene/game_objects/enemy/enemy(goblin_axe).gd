extends CharacterBody2D

var hp = 0

@onready var detector_shape = $detector/CollisionShape2D
@onready var anim = $AnimatedSprite2D
@onready var animP = $AnimationPlayer
@onready var attack_timer = $attack_timer

enum Dir { DOWN, UP, LEFT, RIGHT }
var current_dir = Dir.DOWN

var player: Node2D = null
var parent_node: Node = null
var room_node: Node2D = null

var can_walk = true
var can_attack = true
var player_in_range = false
var smite_instance: Node2D = null
var is_dead = false # Добавляем флаг смерти

func _ready() -> void:
	hp = GameConstants.ENEMY_GOBLIN_AXE_HP
	player = get_tree().get_first_node_in_group("player") as Node2D
	parent_node = get_parent()
	if parent_node:
		room_node = parent_node.get_parent()

func _physics_process(_delta: float) -> void:
	if is_dead: return # Мертвый гоблин не двигается
	
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
		
		velocity = direction * GameConstants.ENEMY_GOBLIN_AXE_MAX_SPEED
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
	if hp <= 0 and not is_dead: # Проверяем, что еще не начали умирать
		death()

func attack():
	if not can_attack or not player_in_range or is_dead:
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
		
	if not is_dead: # Возвращаем возможность ходить, только если жив
		can_walk = true
		attack_timer.start()

func play_idle_animation():
	if is_dead: return
	var target_idle = "idle_down"
	if anim.animation != target_idle:
		anim.play(target_idle)

func swing():
	if not is_instance_valid(player) or is_dead: return
	
	smite_instance = GameConstants.ENEMY_GOBLIN_AXE_SMITE.instantiate()
	add_child(smite_instance)
	
	smite_instance.visible = false
	smite_instance.monitoring = false
	
	var target_dir = (player.global_position - global_position).normalized()
	if "direction" in smite_instance:
		smite_instance.direction = target_dir
		
	smite_instance.position = target_dir * GameConstants.ENEMY_GOBLIN_AXE_SMITE_OFFSET 
	smite_instance.rotation = target_dir.angle()

func activate_smite():
	if is_instance_valid(smite_instance) and not is_dead:
		smite_instance.visible = true
		smite_instance.monitoring = true

func _on_detector_body_entered(body: Node2D) -> void:
	if is_dead: return
	if body.is_in_group("player"):
		player_in_range = true
		if can_attack:
			attack()

func _on_detector_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false

func _on_attack_timer_timeout():
	if is_dead: return
	can_attack = true
	var is_aggressive = parent_node and parent_node.get("aggression")
	if player_in_range and is_aggressive:
		attack()

func _on_hitbox_area_entered(_area: Area2D) -> void:
	if is_dead: return
	hp -= GameConstants.ENEMY_GOBLIN_AXE_TAKE_DAMAGE
	
func death():
	is_dead = true
	can_walk = false
	can_attack = false
	velocity = Vector2.ZERO # Полная остановка
	
	# Останавливаем все текущие анимации (и спрайта, и плеера)
	anim.stop()
	animP.stop()
	
	# Отключаем коллизии, чтобы труп не мешал игроку и не получал урон
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)

	match current_dir:
		Dir.UP: anim.play("death_up")
		Dir.DOWN: anim.play("death_down")
		Dir.LEFT: anim.play("death_left")
		Dir.RIGHT: anim.play("death_right")
		
	await anim.animation_finished
	GameConstants.register_enemy_kill()
	queue_free()
	
func _on_hitbox_body_entered(body: Node2D) -> void:
	if is_dead: return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(GameConstants.ENEMY_GOBLIN_AXE_DAMAGE)
