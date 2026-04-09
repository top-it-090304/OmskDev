extends CharacterBody2D

var hp = 0
var speed = GameConstants.ENEMY_BEASTGOBLIN_MAX_SPEED

@onready var anim = $AnimatedSprite2D
@onready var animP = $AnimationPlayer
@onready var attack_timer = $attack_timer
@onready var hp_bar = $TextureProgressBar

enum Dir { DOWN, UP, LEFT, RIGHT }
var current_dir = Dir.DOWN

var player: Node2D = null
var parent_node: Node = null

var player_in_bite_zone = false
var player_in_slap_zone = false
var player_in_shoot_zone = false

var can_walk = true
var can_attack = true
var can_anim = true 
var is_dead = false 
var is_attacking = false

var smite_instance: Node2D = null

func _ready() -> void:
	hp = GameConstants.ENEMY_BEASTGOBLIN_HP
	hp_bar.update_hp(hp, GameConstants.ENEMY_BEASTGOBLIN_HP)
	
	player = get_tree().get_first_node_in_group("player") as Node2D
	parent_node = get_parent()
	
	attack_timer.one_shot = true
	_play_idle_animation()

func _physics_process(_delta: float) -> void:
	if is_dead or is_attacking: 
		return # Если атакуем — физика и поиск игрока не работают, ждем конца анимации
	
	var is_aggressive = parent_node and parent_node.get("aggression")
	
	if can_walk and is_instance_valid(player) and is_aggressive:
		var to_player = player.global_position - global_position
		var direction = to_player.normalized()
		
		# Обновляем направление взгляда даже в простое
		_update_direction(direction)
		
		if player_in_bite_zone or player_in_slap_zone:
			velocity = Vector2.ZERO
			if can_anim: _play_idle_animation()
		else:
			velocity = direction * speed
			move_and_slide()
			if can_anim: update_run_animation(direction)
			
		# Логика атак
		if can_attack:
			if player_in_bite_zone:
				attack("bite")
			elif player_in_slap_zone:
				attack("slap")
			elif player_in_shoot_zone:
				attack("shoot")
	else:
		velocity = Vector2.ZERO
		move_and_slide()
		if can_anim and not is_dead: _play_idle_animation()

# --- СИСТЕМА АТАК ---

func attack(type: String):
	if not can_attack or is_dead or is_attacking: return
	
	is_attacking = true
	can_attack = false
	can_walk = false
	can_anim = false
	
	var anim_name = type + "_" + _get_dir_string()
	
	if animP.has_animation(anim_name):
		animP.play(anim_name)
		# ВНИМАНИЕ: await убран. Сброс состояния произойдет либо по завершению (Signal), 
		# либо через AnimationPlayer (Call Method Track).
		if not animP.is_connected("animation_finished", _on_animation_finished):
			animP.animation_finished.connect(_on_animation_finished, CONNECT_ONE_SHOT)
	else:
		_reset_after_attack()

# Безопасный сброс через сигнал или принудительно
func _on_animation_finished(_name):
	_reset_after_attack()

func _reset_after_attack():
	if is_instance_valid(smite_instance):
		smite_instance.queue_free()
		smite_instance = null
	
	is_attacking = false
	
	if not is_dead:
		can_walk = true
		can_anim = true
		# В Idle здесь больше не заходим принудительно, 
		# physics_process сам решит, какую анимацию включить в следующем кадре
		if attack_timer.is_stopped():
			attack_timer.start()

# --- УРОН ---

func take_damage(amount: int):
	if is_dead: return
	hp -= amount
	hp_bar.update_hp(hp, GameConstants.ENEMY_BEASTGOBLIN_HP)
	
	# Если нас ударили, мгновенно сбрасываем состояние атаки, чтобы не зависнуть
	if is_attacking:
		animP.stop()
		_reset_after_attack()
	
	if hp <= 0:
		death()
		return

	# Анимация боли через AnimatedSprite2D (не мешает AnimationPlayer)
	can_anim = false
	can_walk = false
	anim.play("hurt_" + _get_dir_string())
	
	# Используем таймер или сигнал AnimatedSprite2D, это безопаснее для Hurt
	await anim.animation_finished
	if not is_dead:
		can_anim = true
		can_walk = true

# --- ОСТАЛЬНАЯ ЛОГИКА (без изменений) ---

func _on_attack_timer_timeout():
	can_attack = true

func _update_direction(direction: Vector2):
	if abs(direction.x) > abs(direction.y):
		current_dir = Dir.RIGHT if direction.x > 0 else Dir.LEFT
	else:
		current_dir = Dir.DOWN if direction.y > 0 else Dir.UP

func update_run_animation(direction: Vector2):
	_update_direction(direction)
	anim.play("run_" + _get_dir_string())

func _get_dir_string() -> String:
	match current_dir:
		Dir.UP: return "up"
		Dir.DOWN: return "down"
		Dir.LEFT: return "left"
		Dir.RIGHT: return "right"
	return "down"

func _play_idle_animation():
	anim.play("idle_" + _get_dir_string())

func death():
	is_dead = true
	is_attacking = false
	can_walk = false
	can_attack = false
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	animP.stop()
	if is_instance_valid(smite_instance): smite_instance.queue_free()
	
	var d_anim = "death_" + _get_dir_string()
	if _get_dir_string() == "down": d_anim = "death_dowm"
	anim.play(d_anim)
	await anim.animation_finished
	queue_free()

# Функции выстрела и укуса остаются такими же (spawn_bite_swing, activate_bite, shoot)
# Подключения детекторов остаются такими же
