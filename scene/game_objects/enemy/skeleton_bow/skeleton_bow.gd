extends CharacterBody2D

# Настройки из глобальных констант
@export var hp = 0
var max_speed = 0.0
var damage = 20

@onready var animP = $AnimationPlayer
@onready var attack_timer = $attack_timer
@onready var anim = $AnimatedSprite2D

# Ссылки на окружение
var player: Node2D = null
var parent_node: Node = null
var room_node: Node2D = null

# Направления
enum Dir { DOWN, UP, LEFT, RIGHT }
var current_dir = Dir.DOWN

# Флаги состояний
var can_move = true
var can_attack = true
var player_in_range = false
var get_closer = true
var is_dead = false 
var can_anim = true # Позволяет анимациям урона перебивать бег

func _ready() -> void:
	# Инициализация параметров
	hp = GameConstants.SKELETON_BOW_HP
	max_speed = randf_range(GameConstants.SKELETON_BOW_SPEED_MIN, GameConstants.SKELETON_BOW_SPEED_MAX)
	player = get_tree().get_first_node_in_group("player") as Node2D
	parent_node = get_parent()

	if parent_node:
		room_node = parent_node.get_parent()

func _physics_process(_delta: float) -> void:
	if is_dead: return 

	# Логика остановки, если нельзя двигаться или игрок слишком близко
	if not player or not is_instance_valid(player) or not can_move or not get_closer:
		velocity = Vector2.ZERO
		if not animP.is_playing() and can_anim:
			play_idle_animation()
		move_and_slide() 
		return

	var to_player: Vector2 = player.global_position - global_position
	var direction = to_player.normalized()
	
	update_direction(direction)

	# Проверка агрессии из родительского узла (комнаты)
	var is_aggressive = parent_node and parent_node.get("aggression")

	if is_aggressive and get_closer:
		velocity = direction * max_speed
		if can_anim:
			play_run_animation()
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		if can_anim:
			play_idle_animation()

func _process(_delta):
	# Проверка смерти в каждом кадре
	if hp <= 0 and not is_dead:
		death()

func update_direction(dir: Vector2):
	if abs(dir.x) > abs(dir.y):
		current_dir = Dir.LEFT if dir.x < 0 else Dir.RIGHT
	else:
		current_dir = Dir.UP if dir.y < 0 else Dir.DOWN

func play_run_animation():
	match current_dir:
		Dir.UP: anim.play("run_up")
		Dir.DOWN: anim.play("run_down")
		Dir.LEFT: anim.play("run_left")
		Dir.RIGHT: anim.play("run_right")

func play_idle_animation():
	if is_dead: return
	# Обычно скелет стоит лицом вниз в покое
	if anim.animation != "idle_down":
		anim.play("idle_down")

func attack():
	if not can_attack or not player_in_range or is_dead:
		return

	var is_aggressive = parent_node and parent_node.get("aggression")
	if not is_aggressive:
		return
		
	can_move = false
	can_attack = false
	
	# Запуск анимации стрельбы через AnimationPlayer
	match current_dir:
		Dir.UP: animP.play("attack_up")
		Dir.DOWN: animP.play("attack_down")
		Dir.LEFT: animP.play("attack_left")
		Dir.RIGHT: animP.play("attack_right")
	
	await animP.animation_finished
	
	if not is_dead:
		can_move = true
		attack_timer.start()
		
func take_damage(amount: int):
	if is_dead: return
	
	hp -= amount
	can_anim = false 
	animP.stop()    
	
	if hp <= 0:
		death()
		return

	
	match current_dir:
		Dir.UP: anim.play("hurt_up")
		Dir.DOWN: anim.play("hurt_down")
		Dir.LEFT: anim.play("hurt_left")
		Dir.RIGHT: anim.play("hurt_right")
	
	await anim.animation_finished
	
	if not is_dead:
		can_anim = true # Возвращаем контроль анимациям бега/покоя
		
func shoot():
	# ВЫЗЫВАЕТСЯ ИЗ КЛЮЧА В AnimationPlayer
	if not player or not is_instance_valid(player) or is_dead: return
	
	var arrow_instance = GameConstants.SKELETON_BOW_ARROW.instantiate()
	arrow_instance.global_position = global_position
	
	var target_dir = (player.global_position - global_position).normalized()
	arrow_instance.direction = target_dir
	arrow_instance.rotation = target_dir.angle()
	
	# Добавляем стрелу в корень сцены, чтобы она не двигалась вместе со скелетом
	get_tree().current_scene.add_child.call_deferred(arrow_instance)

func death():
	if is_dead: return
	is_dead = true
	can_move = false

	can_attack = false
	velocity = Vector2.ZERO 
	
	anim.stop()
	animP.stop()
	
	# Отключаем коллизии
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)

	match current_dir:
		Dir.UP: anim.play("death_up")
		Dir.DOWN: anim.play("death_down")
		Dir.LEFT: anim.play("death_left")
		Dir.RIGHT: anim.play("death_right")
		
	await anim.animation_finished
	GameConstants.register_enemy_kill()
	GameConstants.register_enemy_kill()
	if randf() <= 0.25:
		_spawn_loot()
	
	# 3. И только в самом конце удаляем врага
	queue_free()
	
func _spawn_loot():
	var potion = GameConstants.HEALTH_POTION.instantiate()
	potion.global_position = global_position
	get_parent().add_child(potion)

# Сигналы детекторов
func _on_detector_body_entered(body: Node2D) -> void:
	if is_dead: return
	if body.is_in_group("player"):
		player_in_range = true
		get_closer = false 
		if can_attack:
			attack()

func _on_detector_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		get_closer = true 

func _on_attack_timer_timeout():
	if is_dead: return
	can_attack = true
	if player_in_range:
		attack()

func _on_hitbox_body_entered(body: Node2D) -> void:
	if is_dead: return
	# Урон игроку при касании тела скелета
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(GameConstants.SKELETON_BOW_BODY_DAMAGE)
