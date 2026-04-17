extends CharacterBody2D

@export var atack_spawn: Node
@export var gameover: PackedScene
@onready var attack_joystick = $MobileController/VirtualJoystick2

const LEVEL_UP_POPUP = preload("res://scene/ui/level_up_popup.tscn")

@onready var anim = $AnimatedSprite2D
var health_int = 0
var can_take_damage = true
@onready var damage_timer = $can_take_damage
@onready var attack_timer = $can_attack
@onready var animP = $AnimationPlayer

# Система уровней
var current_level = 1
var current_exp = 0
var exp_to_next_level = 100

enum Dir { DOWN, UP, LEFT, RIGHT }
var current_dir = Dir.DOWN
var can_move = true
var can_anim = true
var can_attack = true
var is_dead = false 
var last_known_max_health = 0


signal health_changed(new_health, max_health)
signal exp_changed(current_exp, exp_needed)
signal level_up(new_level)

func _physics_process(_delta: float) -> void:
	if is_dead: return
	# ВАЖНО: move_and_slide() ДОЛЖНА быть в _physics_process
	move_and_slide()

func _process(_delta: float) -> void:
	if is_dead: return
	
	if health_int <= 0:
		die()
		return
		
	# --- ЛОГИКА АТАКИ ЧЕРЕЗ ДЖОЙСТИК ---
	if attack_joystick and attack_joystick.is_active:
		var atk_vector = attack_joystick.vector
		if atk_vector != Vector2.ZERO:
			# Поворачиваем игрока в сторону джойстика атаки
			update_direction(atk_vector)
			# Атакуем по кулдауну
			if can_attack:
				attack()
	
	# --- ЛОГИКА ДВИЖЕНИЯ ---
	var direction = movement_vector()
	
	if direction != Vector2.ZERO:
		velocity = direction * GameConstants.PLAYER_MAX_SPEED
		# Обновляем направление только если НЕ атакуем джойстиком
		if not (attack_joystick and attack_joystick.is_active):
			update_direction(direction)
		if can_anim:
			play_walk_animation()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, GameConstants.PLAYER_MAX_SPEED)
		if can_anim:
			play_idle_animation()

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
	if not can_attack or is_dead:
		return
	
	can_anim = false
	can_attack = false
	
	# Запускаем анимацию через AnimationPlayer
	match current_dir:
		Dir.UP: animP.play("attack_up")
		Dir.DOWN: animP.play("attack_down")
		Dir.LEFT: animP.play("attack_left")
		Dir.RIGHT: animP.play("attack_right")
	
	# Ждем завершения анимации
	await animP.animation_finished
	
	can_anim = true
	attack_timer.start()
	
func apply_knockback(source_position: Vector2, force: float):
	if is_dead: return
	var knockback_dir = (global_position - source_position).normalized()
	velocity = knockback_dir * force

func take_damage(amount: int):
	if not can_take_damage or is_dead:
		return
	
	can_anim = false 
	can_take_damage = false
	health_int -= amount
	health_changed.emit(health_int, GameConstants.PLAYER_MAX_HEALTH)
	
	if health_int <= 0:
		die()
		return

	match current_dir:
		Dir.UP: anim.play("hurt_up")
		Dir.DOWN: anim.play("hurt_down")
		Dir.LEFT: anim.play("hurt_left")
		Dir.RIGHT: anim.play("hurt_right")
	
	await anim.animation_finished
	
	if not is_dead:
		can_anim = true
		damage_timer.start()

func die():
	if is_dead: return
	is_dead = true
	can_anim = false
	velocity = Vector2.ZERO 
	
	match current_dir:
		Dir.UP: anim.play("death_up")
		Dir.DOWN: anim.play("death_down")
		Dir.LEFT: anim.play("death_left")
		Dir.RIGHT: anim.play("death_right")
	
	await anim.animation_finished
	var over = gameover.instantiate()
	add_child(over)

func _on_hitbox_body_entered(body: Node2D) -> void:
	if is_dead: return
	if body.is_in_group("enemys"):
		take_damage(GameConstants.PLAYER_ENEMY_CONTACT_DAMAGE)

func _on_can_take_damage_timeout() -> void:
	can_take_damage = true

func _ready() -> void:
	add_to_group("player")

	# Инициализация системы уровней СНАЧАЛА
	current_level = GameConstants.PLAYER_LEVEL
	current_exp = GameConstants.PLAYER_EXPERIENCE
	exp_to_next_level = _calculate_exp_for_level(current_level + 1)

	health_int = GameConstants.PLAYER_MAX_HEALTH
	last_known_max_health = GameConstants.PLAYER_MAX_HEALTH
	if not GameConstants.constants_changed.is_connected(_on_constants_changed):
		GameConstants.constants_changed.connect(_on_constants_changed)

	# Эмитим сигналы ПОСЛЕ инициализации всех переменных
	health_changed.emit(health_int, GameConstants.PLAYER_MAX_HEALTH)
	exp_changed.emit(current_exp, exp_to_next_level)

	# Если это загрузка сохранения, восстанавливаем состояние
	if SaveSystem.should_restore_player:
		SaveSystem.restore_player_state()

func _on_constants_changed() -> void:
	var new_max = GameConstants.PLAYER_MAX_HEALTH
	if new_max > last_known_max_health:
		health_int = min(health_int * 2, new_max)
	elif health_int > new_max:
		health_int = new_max
	last_known_max_health = new_max
	health_changed.emit(health_int, new_max)

func _on_can_attack_timeout() -> void:
	can_attack = true

func _on_hitbox_attack_body_entered(body: Node2D) -> void:
	print("Удар по объекту: ", body.name)
	if is_dead: return
	if body.is_in_group("enemies"):
		body.take_damage(GameConstants.PLAYER_ENEMY_CONTACT_DAMAGE)

func heal(amount: int) -> void:
	health_int += amount
	health_changed.emit(health_int, GameConstants.PLAYER_MAX_HEALTH)

# === СИСТЕМА ОПЫТА И УРОВНЕЙ ===

func add_experience(amount: int) -> void:
	# Применяем множитель опыта от артефактов
	var multiplier = 1.0
	if "PLAYER_EXP_MULTIPLIER_BONUS" in GameConstants:
		multiplier = GameConstants.PLAYER_EXP_MULTIPLIER_BONUS

	var final_amount = int(amount * multiplier)

	print("Получен опыт: ", final_amount, " (базовый: ", amount, ", множитель: x", multiplier, ") | Текущий опыт: ", current_exp, "/", exp_to_next_level)
	current_exp += final_amount
	GameConstants.PLAYER_EXPERIENCE = current_exp
	exp_changed.emit(current_exp, exp_to_next_level)

	# Проверка повышения уровня
	while current_exp >= exp_to_next_level:
		level_up_player()

func _calculate_exp_for_level(level: int) -> int:
	# Формула: базовый_опыт * (множитель ^ (уровень - 1))
	var exp_needed = int(GameConstants.PLAYER_BASE_EXP_TO_LEVEL * pow(GameConstants.PLAYER_EXP_MULTIPLIER, level - 1))
	print("Опыт для уровня ", level, ": ", exp_needed)
	return exp_needed

func level_up_player() -> void:
	print("=== LEVEL UP! ===")
	print("Старый уровень: ", current_level)
	print("Текущий опыт: ", current_exp, " | Требовалось: ", exp_to_next_level)

	current_level += 1
	GameConstants.PLAYER_LEVEL = current_level

	# Вычитаем опыт для текущего уровня
	current_exp -= exp_to_next_level
	exp_to_next_level = _calculate_exp_for_level(current_level + 1)

	# Увеличиваем характеристики
	GameConstants.PLAYER_MAX_HEALTH += GameConstants.PLAYER_HEALTH_PER_LEVEL
	GameConstants.PLAYER_MAX_SPEED += GameConstants.PLAYER_SPEED_PER_LEVEL
	GameConstants.PLAYER_ATTACK_DAMAGE += GameConstants.PLAYER_DAMAGE_PER_LEVEL

	# Восстанавливаем здоровье при повышении уровня
	health_int = GameConstants.PLAYER_MAX_HEALTH
	last_known_max_health = GameConstants.PLAYER_MAX_HEALTH

	# Показываем popup
	_show_level_up_popup()

	# Сигналы
	level_up.emit(current_level)
	health_changed.emit(health_int, GameConstants.PLAYER_MAX_HEALTH)
	exp_changed.emit(current_exp, exp_to_next_level)

	print("Новый уровень: ", current_level)
	print("Остаток опыта: ", current_exp, " | Нужно для следующего: ", exp_to_next_level)
	print("==================")

func _show_level_up_popup():
	print("Показываем Level Up Popup!")
	var popup = LEVEL_UP_POPUP.instantiate()
	popup.global_position = global_position + Vector2(0, -50)
	get_tree().current_scene.add_child(popup)
	print("Popup добавлен в сцену")
