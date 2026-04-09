extends CharacterBody2D

var hp = 0
var speed = GameConstants.ENEMY_BEASTGOBLIN_MAX_SPEED

@onready var anim = $AnimatedSprite2D
@onready var animP = $AnimationPlayer
@onready var attack_timer = $attack_timer
# --- НОВОЕ ---
@onready var hp_bar = $TextureProgressBar

enum Dir { DOWN, UP, LEFT, RIGHT }
var current_dir = Dir.DOWN

var player: Node2D = null
var parent_node: Node = null

# Флаги детекторов
var player_in_bite_zone = false
var player_in_slap_zone = false
var player_in_shoot_zone = false

var can_walk = true
var can_attack = true
var can_anim = true 
var is_dead = false 

var smite_instance: Node2D = null

# Флаг для предотвращения повторных вызовов attack() во время анимации
var is_attacking = false

func _ready() -> void:
	hp = GameConstants.ENEMY_BEASTGOBLIN_HP
	# --- НОВОЕ ---
	hp_bar.update_hp(hp, GameConstants.ENEMY_BEASTGOBLIN_HP)
	
	player = get_tree().get_first_node_in_group("player") as Node2D
	parent_node = get_parent()
	
	attack_timer.one_shot = true
	_play_idle_animation()

func _physics_process(_delta: float) -> void:
	if is_dead: return 
	
	var is_aggressive = parent_node and parent_node.get("aggression")
	
	if can_walk and is_instance_valid(player) and is_aggressive:
		var to_player = player.global_position - global_position
		var direction = to_player.normalized()
		
		# Логика движения: стоим, если игрок в зоне укуса или удара
		if player_in_bite_zone or player_in_slap_zone:
			velocity = Vector2.ZERO
			if can_anim: _play_idle_animation()
		else:
			velocity = direction * speed
			move_and_slide()
			if can_anim: update_run_animation(direction)
			
		# ПРИОРИТЕТЫ АТАК
		if can_attack and not is_attacking:
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
		await animP.animation_finished
	
	# Гарантированно останавливаем AnimationPlayer после анимации
	animP.stop()
	
	_reset_after_attack()

func _reset_after_attack():
	if is_instance_valid(smite_instance):
		smite_instance.queue_free()
		smite_instance = null
	
	is_attacking = false
			
	if not is_dead:
		can_walk = true
		can_anim = true
		# Явно возвращаемся к idle анимации
		_play_idle_animation()
		if attack_timer.is_stopped():
			attack_timer.start()

# --- МЕТОДЫ ДЛЯ АНИМАЦИЙ ---

func bite_swing():
	if not is_instance_valid(player) or is_dead: return
	smite_instance = GameConstants.ENEMY_GOBLIN_AXE_SMITE.instantiate()
	# Добавляем в сцену, чтобы эффект не "бегал" за гоблином
	get_tree().current_scene.add_child(smite_instance)
	
	smite_instance.global_position = global_position
	smite_instance.visible = false
	smite_instance.monitoring = false
	
	var target_dir = (player.global_position - global_position).normalized()
	if "direction" in smite_instance:
		smite_instance.direction = target_dir
	
	smite_instance.rotation = target_dir.angle()
	smite_instance.global_position += target_dir * 35

func activate_bite_smite():
	if is_instance_valid(smite_instance) and not is_dead:
		smite_instance.visible = true
		smite_instance.monitoring = true

func shoot():
	if is_dead or not is_instance_valid(player): return
	var arrow = GameConstants.SKELETON_BOW_ARROW.instantiate()
	
	# 1. Сначала определяем направление ОДИН РАЗ
	var dir = (player.global_position - global_position).normalized()
	
	# 2. Передаем направление в стрелу
	if "direction" in arrow:
		arrow.direction = dir
	
	# 3. Настраиваем позицию и вращение
	arrow.global_position = global_position
	arrow.rotation = dir.angle()
	
	# 4. Добавляем в корень сцены (не в гоблина!)
	get_tree().current_scene.add_child(arrow)

# --- УРОН И СИГНАЛЫ ---

func _on_slap_body_entered(body: Node2D) -> void:
	if is_dead: return
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(GameConstants.ENEMY_BEASTGOBLIN_SLAP_DAMAGE)
		if body.has_method("apply_knockback"):
			body.apply_knockback(global_position, 800.0)

func take_damage(amount: int):
	if is_dead: return
	hp -= amount
	
	# --- НОВОЕ ---
	hp_bar.update_hp(hp, GameConstants.ENEMY_BEASTGOBLIN_HP)
	
	# Прерываем анимацию атаки, если гоблина ударили
	animP.stop()
	is_attacking = false
	
	if hp <= 0:
		death()
		return

	can_anim = false
	can_walk = false
	anim.play("hurt_" + _get_dir_string())
	await anim.animation_finished
	_reset_after_attack()

# --- ПОДКЛЮЧЕНИЕ ДЕТЕКТОРОВ ---

func _on_detector_bite_body_entered(body): if body.is_in_group("player"): player_in_bite_zone = true
func _on_detector_bite_body_exited(body): if body.is_in_group("player"): player_in_bite_zone = false
func _on_detector_slap_body_entered(body): if body.is_in_group("player"): player_in_slap_zone = true
func _on_detector_slap_body_exited(body): if body.is_in_group("player"): player_in_slap_zone = false
func _on_detector_shoot_body_entered(body): if body.is_in_group("player"): player_in_shoot_zone = true
func _on_detector_shoot_body_exited(body): if body.is_in_group("player"): player_in_shoot_zone = false

func _on_hitbox_area_entered(_area): take_damage(GameConstants.ENEMY_BEASTGOBLIN_TAKE_DAMAGE)
func _on_attack_timer_timeout(): can_attack = true

# --- ОБНОВЛЕНИЕ АНИМАЦИЙ ---

func update_run_animation(direction: Vector2):
	if abs(direction.x) > abs(direction.y):
		current_dir = Dir.RIGHT if direction.x > 0 else Dir.LEFT
	else:
		current_dir = Dir.DOWN if direction.y > 0 else Dir.UP
	anim.play("run_" + _get_dir_string())

func _get_dir_string() -> String:
	match current_dir:
		Dir.UP: return "up"
		Dir.DOWN: return "down"
		Dir.LEFT: return "left"
		Dir.RIGHT: return "right"
	return "down"

func _play_idle_animation():
	if anim.animation != "idle_down": anim.play("idle_down")

func death():
	is_dead = true
	can_walk = false
	can_attack = false
	is_attacking = false
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	animP.stop()
	if is_instance_valid(smite_instance): smite_instance.queue_free()
	
	var d_anim = "death_" + _get_dir_string()
	if _get_dir_string() == "down": d_anim = "death_dowm" # <--- (Небольшая опечатка у тебя тут была: "dowm" вместо "down", оставил как есть, чтобы не сломать твои спрайты, но на будущее имей в виду)
	anim.play(d_anim)
	await anim.animation_finished
	queue_free()
