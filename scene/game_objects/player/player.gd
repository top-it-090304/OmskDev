extends CharacterBody2D

@export var atack_spawn: Node
@export var gameover: PackedScene
@export var hit_particles: PackedScene
@onready var attack_joystick = $MobileController/VirtualJoystick2

const LEVEL_UP_POPUP = preload("res://scene/ui/level_up_popup.tscn")

@onready var anim = $AnimatedSprite2D
var health_int = 0
var can_take_damage = true
@onready var damage_timer = $can_take_damage
@onready var attack_timer = $can_attack
@onready var animP = $AnimationPlayer

# Система отравления
var is_poisoned = false
var poison_timer = 0.0
var poison_tick_timer = 0.0
var poison_damage_per_tick = 0
var poison_tick_rate = 0.5
var original_modulate = Color(1, 1, 1, 1)

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

	if Input.is_action_just_pressed("ui_focus_next"):  # Tab
		GameConstants.PLAYER_MAX_SPEED = 500
		GameConstants.PLAYER_ATTACK_SPEED = 5.0
	if Input.is_action_just_released("ui_focus_next"):  # Tab отжат
		GameConstants.PLAYER_MAX_SPEED = SaveSystem.BASE_VALUES["PLAYER_MAX_SPEED"]
		GameConstants.PLAYER_ATTACK_SPEED = 1.0

	# Обработка яда
	if is_poisoned:
		poison_timer -= _delta
		poison_tick_timer -= _delta

		# Наносим урон каждый тик
		if poison_tick_timer <= 0:
			take_damage(poison_damage_per_tick)
			poison_tick_timer = poison_tick_rate
			print("Урон от яда: ", poison_damage_per_tick)

		# Проверяем окончание яда
		if poison_timer <= 0:
			remove_poison()

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
	if not can_anim:
		return
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

	var attack_dir = current_dir
	animP.speed_scale = GameConstants.PLAYER_ATTACK_SPEED

	match attack_dir:
		Dir.UP: animP.play("attack_up")
		Dir.DOWN: animP.play("attack_down")
		Dir.LEFT: animP.play("attack_left")
		Dir.RIGHT: animP.play("attack_right")

	AudioManager.play_sfx("игрок_атака")

	await animP.animation_finished

	animP.speed_scale = 1.0
	can_anim = true
	# PLAYER_ATTACK_SPEED: множитель > 1 = быстрее, делим wait_time на него
	attack_timer.start(attack_timer.wait_time / GameConstants.PLAYER_ATTACK_SPEED)
	
func apply_knockback(source_position: Vector2, force: float):
	if is_dead: return
	var knockback_dir = (global_position - source_position).normalized()
	velocity = knockback_dir * force

func take_damage(amount: int):
	if not can_take_damage or is_dead:
		return

	# Уклонение
	if randf() < GameConstants.PLAYER_DODGE_CHANCE:
		return

	# Броня
	var final_amount = max(1, amount - GameConstants.PLAYER_ARMOR)

	can_take_damage = false
	health_int -= final_amount
	health_changed.emit(health_int, GameConstants.PLAYER_MAX_HEALTH)

	if health_int <= 0:
		die()
		return

	var restore_color = Color(0.3, 1, 0.3, 1) if is_poisoned else Color(1, 1, 1, 1)
	var tween = create_tween()
	tween.tween_property(anim, "modulate", Color(1, 0, 0, 1), 0.0)
	tween.tween_property(anim, "modulate", restore_color, 0.15)
	AudioManager.play_sfx("игрок_урон")
	# Particles on hit
	if hit_particles:
		var particles = hit_particles.instantiate()
		particles.global_position = global_position
		get_tree().current_scene.add_child(particles)
	damage_timer.start()

func die():
	if is_dead: return
	is_dead = true
	can_anim = false
	velocity = Vector2.ZERO
	AudioManager.play_sfx("игрок_смерть")
	
	match current_dir:
		Dir.UP: anim.play("death_up")
		Dir.DOWN: anim.play("death_down")
		Dir.LEFT: anim.play("death_left")
		Dir.RIGHT: anim.play("death_right")
	
	await anim.animation_finished
	# Сохраняем состояние при смерти
	SaveSystem.save_game()
	var map_manager = get_tree().get_first_node_in_group("map_manager")
	if map_manager and map_manager.has_method("save_dungeon_state"):
		map_manager.save_dungeon_state()
	
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

	health_int = SaveSystem.saved_player_health if SaveSystem.should_restore_player else GameConstants.PLAYER_MAX_HEALTH
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
	if is_dead: return
	if body.is_in_group("enemys"):
		var dmg = GameConstants.PLAYER_ATTACK_DAMAGE
		# Крит
		if randf() < GameConstants.PLAYER_CRIT_CHANCE:
			dmg = int(dmg * GameConstants.PLAYER_CRIT_MULTIPLIER)
		body.take_damage(dmg)
		# Particles on hit enemy
		if hit_particles:
			var particles = hit_particles.instantiate()
			particles.global_position = body.global_position
			get_tree().current_scene.add_child(particles)
		# Вампиризм
		if GameConstants.PLAYER_LIFESTEAL > 0.0:
			var steal = int(dmg * GameConstants.PLAYER_LIFESTEAL)
			if steal > 0:
				heal(steal)

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
	GameConstants.PLAYER_MAX_HEALTH  = min(GameConstants.PLAYER_MAX_HEALTH  + GameConstants.PLAYER_HEALTH_PER_LEVEL, 9999)
	GameConstants.PLAYER_MAX_SPEED   = min(GameConstants.PLAYER_MAX_SPEED   + GameConstants.PLAYER_SPEED_PER_LEVEL,  600)
	GameConstants.PLAYER_ATTACK_DAMAGE = min(GameConstants.PLAYER_ATTACK_DAMAGE + GameConstants.PLAYER_DAMAGE_PER_LEVEL, 999)

	last_known_max_health = GameConstants.PLAYER_MAX_HEALTH

	# Показываем popup
	_show_level_up_popup()
	AudioManager.play_sfx("игрок_левелап")

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

# =====================================================================
# СИСТЕМА ОТРАВЛЕНИЯ
# =====================================================================

func apply_poison(duration: float, damage_per_tick: int, tick_rate: float):
	if is_poisoned:
		# Если уже отравлен, обновляем таймер (продлеваем яд)
		poison_timer = max(poison_timer, duration)
		print("Яд продлен! Новая длительность: ", poison_timer, "с")
	else:
		# Применяем новый яд
		is_poisoned = true
		poison_timer = duration
		poison_tick_timer = tick_rate
		poison_damage_per_tick = damage_per_tick
		poison_tick_rate = tick_rate

		# Делаем игрока зеленым
		anim.modulate = Color(0.3, 1, 0.3, 1)
		print("Игрок отравлен! Длительность: ", duration, "с, урон за тик: ", damage_per_tick)

func remove_poison():
	is_poisoned = false
	poison_timer = 0.0
	poison_tick_timer = 0.0
	var tween = create_tween()
	tween.tween_property(anim, "modulate", Color(1, 1, 1, 1), 0.3)
