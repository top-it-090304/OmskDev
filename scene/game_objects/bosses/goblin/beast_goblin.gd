extends CharacterBody2D

# --- Параметры ---
var hp = 0
var speed = GameConstants.ENEMY_BEASTGOBLIN_MAX_SPEED

# --- Узлы ---
@onready var anim = $AnimatedSprite2D
@onready var animP = $AnimationPlayer
@onready var attack_timer = $attack_timer

# --- Состояния ---
enum Dir { DOWN, UP, LEFT, RIGHT }
var current_dir = Dir.DOWN

var player: Node2D = null
var parent_node: Node = null

# Флаги нахождения игрока в зонах детекторов
var player_in_bite_zone = false
var player_in_slap_zone = false
var player_in_shoot_zone = false

var can_walk = true
var can_attack = true
var can_anim = true 
var is_dead = false 

var smite_instance: Node2D = null

func _ready() -> void:
	hp = GameConstants.ENEMY_BEASTGOBLIN_HP
	player = get_tree().get_first_node_in_group("player") as Node2D
	parent_node = get_parent()
	
	attack_timer.one_shot = true
	if not attack_timer.timeout.is_connected(_on_attack_timer_timeout):
		attack_timer.timeout.connect(_on_attack_timer_timeout)
	
	_play_idle_animation()

func _physics_process(_delta: float) -> void:
	if is_dead: return 
	
	var is_aggressive = parent_node and parent_node.get("aggression")
	
	if can_walk and is_instance_valid(player) and is_aggressive:
		var to_player = player.global_position - global_position
		var direction = to_player.normalized()
		
		# Если игрок слишком близко (в зоне укуса или удара), Гоблин перестает бежать, чтобы атаковать
		if player_in_bite_zone or player_in_slap_zone:
			velocity = Vector2.ZERO
			if can_anim:
				_play_idle_animation()
		else:
			velocity = direction * speed
			move_and_slide()
			if can_anim:
				update_run_animation(direction)
			
		# --- ЛОГИКА ПРИОРИТЕТОВ АТАК ---
		if can_attack:
			# 1 ПРИОРИТЕТ: Укус (самая ближняя зона)
			if player_in_bite_zone:
				attack("bite")
			# 2 ПРИОРИТЕТ: Удар рукой (средняя зона)
			elif player_in_slap_zone:
				attack("slap")
			# 3 ПРИОРИТЕТ: Выстрел (дальняя зона)
			elif player_in_shoot_zone:
				attack("shoot")
	else:
		velocity = Vector2.ZERO
		move_and_slide()
		if can_anim and not is_dead:
			_play_idle_animation()

# --- ЛОГИКА АТАКИ ---

func attack(type: String):
	if not can_attack or is_dead: return
	
	can_attack = false
	can_walk = false
	can_anim = false
	
	var anim_name = type + "_" + _get_dir_string()
	if not animP.has_animation(anim_name):
		anim_name = "attack_" + _get_dir_string()
	
	animP.play(anim_name)
	await animP.animation_finished
	
	# Удаляем Smite укуса, если он остался после анимации
	if is_instance_valid(smite_instance):
		smite_instance.queue_free()
		smite_instance = null
		
	if not is_dead:
		can_walk = true
		can_anim = true
		attack_timer.start()

# --- МЕТОДЫ ДЛЯ ANIMATION PLAYER (Smite и Выстрел) ---

func bite_swing():
	if not is_instance_valid(player) or is_dead: return
	
	smite_instance = GameConstants.ENEMY_GOBLIN_AXE_SMITE.instantiate()
	add_child(smite_instance)
	smite_instance.visible = false
	smite_instance.monitoring = false
	
	var target_dir = (player.global_position - global_position).normalized()
	if "direction" in smite_instance:
		smite_instance.direction = target_dir
		
	smite_instance.position = target_dir * 35 
	smite_instance.rotation = target_dir.angle()

func activate_bite_smite():
	if is_instance_valid(smite_instance) and not is_dead:
		smite_instance.visible = true
		smite_instance.monitoring = true

func shoot():
	if is_dead or not is_instance_valid(player): return
	var arrow = GameConstants.SKELETON_BOW_ARROW.instantiate()
	arrow.global_position = global_position
	var dir = (player.global_position - global_position).normalized()
	if "direction" in arrow: arrow.direction = dir
	arrow.rotation = dir.angle()
	get_tree().current_scene.add_child(arrow)

# --- ПОЛУЧЕНИЕ УРОНА И СМЕРТЬ ---

func take_damage(amount: int):
	if is_dead: return
	hp -= amount
	
	animP.stop()
	if is_instance_valid(smite_instance):
		smite_instance.queue_free()
		smite_instance = null
	
	can_anim = false
	can_walk = false
	
	if hp <= 0:
		death()
		return

	anim.play("hurt_" + _get_dir_string())
	await anim.animation_finished
	
	if not is_dead:
		can_anim = true
		can_walk = true
		if attack_timer.is_stopped():
			can_attack = true

func death():
	is_dead = true
	can_walk = false
	can_attack = false
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	animP.stop()
	
	if is_instance_valid(smite_instance):
		smite_instance.queue_free()
	
	var d_anim = "death_" + _get_dir_string()
	if _get_dir_string() == "down": d_anim = "death_dowm"
	
	anim.play(d_anim)
	await anim.animation_finished
	queue_free()

# --- СИГНАЛЫ ДЕТЕКТОРОВ ---

func _on_detector_bite_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"): player_in_bite_zone = true

func _on_detector_bite_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"): player_in_bite_zone = false

func _on_detector_slap_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"): player_in_slap_zone = true

func _on_detector_slap_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"): player_in_slap_zone = false

func _on_detector_shoot_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"): player_in_shoot_zone = true

func _on_detector_shoot_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"): player_in_shoot_zone = false

# --- ХИТБОКСЫ И ТАЙМЕРЫ ---

func _on_hitbox_area_entered(_area: Area2D) -> void:
	take_damage(GameConstants.ENEMY_BEASTGOBLIN_TAKE_DAMAGE)

func _on_attack_timer_timeout() -> void:
	can_attack = true

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
	if anim.animation != "idle_down":
		anim.play("idle_down")
