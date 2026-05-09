extends CharacterBody2D

const SKELETON_MINION_SCENE = preload("res://scene/game_objects/enemy/skeleton_bow/skeleton_bow.tscn")
const BONE_PROJECTILE_SCENE = preload("res://scene/game_objects/enemy/skeleton_bow/arrow.tscn")
const HATCH_SCENE = preload("res://scene/pick_up/hatch.tscn")

const MELEE_RANGE      = 70.0   # Дистанция для атаки 01 (ближняя)
const SUMMON_RANGE     = 120.0  # Дистанция для атаки 02 (средняя)
const CHARGE_RANGE     = 180.0  # Дистанция для атаки 03 (дальняя)

const ATTACK_COOLDOWN  = 3.5     # Базовый кулдаун между атаками
const SUMMON_COOLDOWN  = 10.0    # Кулдаун суммона (увеличен для баланса)
const MAX_MINIONS      = 10     # Максимальное количество самонов
const MINION_HP        = 1      # HP миньонов (умирают с одного удара)

var hp: int = 0
var speed: float = 0.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_timer: Timer = $attack_timer
@onready var hp_bar: TextureProgressBar = $TextureProgressBar

enum Dir { DOWN, UP, LEFT, RIGHT }
var current_dir: Dir = Dir.DOWN

var player: Node2D = null
var parent_node: Node = null

# Зоны обнаружения игрока для разных атак
var player_in_melee_zone: bool = false
var player_in_summon_zone: bool = false
var player_in_charge_zone: bool = false

var can_walk: bool = true
var can_anim: bool = true
var is_dead: bool = false
var is_attacking: bool = false

# Асинхронные кулдауны для каждой атаки
var _cd_melee  := 0.0
var _cd_summon := 0.0
var _cd_charge := 0.0

# Для ультимативной атаки (зарядка)
var is_charging: bool = false
var charge_target_pos: Vector2 = Vector2.ZERO
var bone_projectile_instance: Node2D = null

func _ready() -> void:
	add_to_group("enemys")
	hp    = GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_SKELETON_KING_HP)
	speed = GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_SKELETON_KING_MAX_SPEED)
	hp_bar.update_hp(hp, hp)
	player      = get_tree().get_first_node_in_group("player") as Node2D
	parent_node = get_parent()
	attack_timer.one_shot = true
	_play_idle_animation()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Обновляем кулдауны
	_cd_melee  = max(0.0, _cd_melee  - delta)
	_cd_summon = max(0.0, _cd_summon - delta)
	_cd_charge = max(0.0, _cd_charge - delta)

	var is_aggressive = parent_node and parent_node.get("aggression")
	if not is_aggressive or not is_instance_valid(player):
		velocity = Vector2.ZERO
		move_and_slide()
		if can_anim and not is_attacking:
			_play_idle_animation()
		return

	if not can_walk:
		return

	var to_player = player.global_position - global_position
	var dist      = to_player.length()
	var direction = to_player.normalized()

	# Определяем целевую дистанцию по следующей доступной атаке
	var target_dist := _get_target_dist()

	if not is_attacking and not is_charging:
		var move_dir := Vector2.ZERO
		if dist < target_dist - 15.0:
			# Слишком близко — отходим
			move_dir = -direction
		elif dist > target_dist + 15.0:
			# Слишком далеко — подходим
			move_dir = direction

		if move_dir != Vector2.ZERO:
			velocity = move_dir * speed
			move_and_slide()
			if can_anim:
				update_run_animation(move_dir)
		else:
			velocity = Vector2.ZERO
			if can_anim:
				_play_idle_animation()

	# Выбор атаки на основе дистанции и готовности
	if not is_attacking and not is_charging:
		# Приоритет: 1) melee (когда игрок близко) 2) summon (средняя дистанция) 3) charge (далеко)
		if player_in_melee_zone and _cd_melee <= 0.0:
			_cd_melee = ATTACK_COOLDOWN / 1.5
			attack("melee")
		elif player_in_summon_zone and _cd_summon <= 0.0 and _count_minions() < MAX_MINIONS:
			_cd_summon = SUMMON_COOLDOWN
			attack("summon")
		elif player_in_charge_zone and _cd_charge <= 0.0:
			_cd_charge = (ATTACK_COOLDOWN * 2.0) / 1.5
			attack("charge")

# Возвращает дистанцию до игрока, к которой нужно стремиться
func _get_target_dist() -> float:
	# Приоритет атак по дистанциям: melee → summon → charge
	var melee_ready  = _cd_melee  <= 0.0 and player_in_melee_zone
	var summon_ready = _cd_summon <= 0.0 and player_in_summon_zone
	var charge_ready = _cd_charge <= 0.0 and player_in_charge_zone

	if melee_ready:
		return MELEE_RANGE      # зона ближней атаки
	elif summon_ready:
		return SUMMON_RANGE     # зона средних атак/суммона
	elif charge_ready:
		return CHARGE_RANGE     # зона ультимативной атаки
	else:
		# Если все на кулдауне — держимся на средней дистанции
		return SUMMON_RANGE

func attack(type: String):
	if is_dead or is_attacking or is_charging:
		return
	is_attacking = true
	can_walk = false
	can_anim = false

	var anim_type := "attack_01" if type == "melee" else ("attack_02" if type == "summon" else "attack_03")
	var anim_name = anim_type + "_" + _get_dir_string()

	if anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)
		# Запускаем эффекты в середине анимации
		match type:
			"melee":
				await get_tree().create_timer(0.2).timeout
				spawn_melee_hitbox()
				await get_tree().create_timer(0.6).timeout  # длительность анимации ~0.8с
			"summon":
				await get_tree().create_timer(0.4).timeout
				summon_minions()
				await get_tree().create_timer(0.4).timeout
			"charge":
				await get_tree().create_timer(0.3).timeout
				await start_charge_attack()
	else:
		await get_tree().create_timer(0.5).timeout

	_reset_after_attack()

func _reset_after_attack():
	is_attacking = false
	if not is_dead:
		can_walk = true
		can_anim = true
		_play_idle_animation()

# ============ АТАКА 01: Быстрая ближняя атака (Bone Smash) ============
func spawn_melee_hitbox() -> void:
	# Создаем Area2D для обнаружения удара вблизи
	var hitbox = Area2D.new()
	hitbox.z_index = 2
	var shape = CircleShape2D.new()
	shape.radius = 50.0
	var col = CollisionShape2D.new()
	col.shape = shape
	hitbox.add_child(col)
	hitbox.global_position = global_position
	hitbox.collision_layer = 0
	hitbox.collision_mask = 1  # игрок
	get_tree().current_scene.add_child(hitbox)

	# Визуальный эффект — вспышка
	var flash = Polygon2D.new()
	var pts = PackedVector2Array()
	for i in 16:
		var a = (TAU / 16.0) * i
		pts.append(Vector2(cos(a), sin(a)) * 45.0)
	flash.polygon = pts
	flash.color = Color(0.9, 0.9, 0.95, 0.7)
	flash.z_index = 10
	flash.global_position = global_position
	get_tree().current_scene.add_child(flash)

	var tween = create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.25)
	tween.tween_callback(flash.queue_free)

	# Наносим урон при столкновении с игроком
	hitbox.body_entered.connect(_on_melee_hitbox_body_entered)
	# Автоудаление через 0.1 сек
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(hitbox):
		hitbox.queue_free()

func _on_melee_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		AudioManager.play_sfx("босс_атака_удар")
		if body.has_method("take_damage"):
			body.take_damage(GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_SKELETON_KING_MELEE_DAMAGE))
		if body.has_method("apply_knockback"):
			body.apply_knockback(global_position, 500.0)

# ============ АТАКА 02: Призыв миньонов (Raise Dead) ============
func _count_minions() -> int:
	return get_tree().get_nodes_in_group("enemys").size() - 1  # -1 это сам босс

func summon_minions() -> void:
	var current_minions = _count_minions()
	if current_minions >= MAX_MINIONS:
		return
	
	AudioManager.play_sfx("босс_суммон")
	var to_summon = mini(4, MAX_MINIONS - current_minions)
	var summon_positions: Array[Vector2] = []
	var radius = 80.0
	for i in to_summon:
		var angle = (TAU / float(to_summon)) * i - PI/2
		var pos = global_position + Vector2(cos(angle), sin(angle)) * radius
		summon_positions.append(pos)

	for pos in summon_positions:
		var minion = SKELETON_MINION_SCENE.instantiate()
		minion.z_index = 2
		# Добавляем миньона в ту же комнату, что и босс, чтобы наследовать aggression
		var room = get_parent()
		if room:
			room.add_child(minion)
		else:
			get_tree().current_scene.add_child(minion)
		minion.global_position = pos
		
		# Устанавливаем HP после добавления в сцену (перезаписывает _ready)
		minion.set_meta("boss_minion", true)
		minion.hp = MINION_HP
		minion.get_node("TextureProgressBar").update_hp(MINION_HP, MINION_HP)

		# Анимация появления
		var tween = create_tween()
		tween.tween_property(minion, "modulate:a", 0.0, 0.0)
		tween.tween_property(minion, "modulate:a", 1.0, 0.3)

		# Визуальный эффект призыва
		var summon_circle = CPUParticles2D.new()
		summon_circle.emitting = true
		summon_circle.one_shot = true
		summon_circle.explosiveness = 1.0
		summon_circle.amount = 20
		summon_circle.lifetime = 0.4
		summon_circle.spread = 360.0
		summon_circle.initial_velocity_min = 60.0
		summon_circle.initial_velocity_max = 100.0
		summon_circle.scale_amount_min = 2.0
		summon_circle.scale_amount_max = 4.0
		summon_circle.color = Color(0.85, 0.85, 0.9, 0.6)
		summon_circle.z_index = 5
		summon_circle.global_position = pos
		get_tree().current_scene.add_child(summon_circle)

# ============ АТАКА 03: Ультимативная способность (Bone Spear Rush) ============
func start_charge_attack() -> void:
	is_charging = true
	can_walk = false

	var start_pos = global_position
	# Цель — точка за игроком (проходит сквозь)
	var to_player = (player.global_position - global_position).normalized()
	charge_target_pos = player.global_position + to_player * 200.0

	# Анимация рывка
	var charge_tween = create_tween()
	charge_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 0.6), 0.1)
	charge_tween.parallel().tween_property(self, "scale", Vector2(1.3, 1.3), 0.15)

	# Рывок к цели
	var dash_duration = 0.25
	var dash_tween = create_tween()
	dash_tween.tween_property(self, "global_position", charge_target_pos, dash_duration).set_trans(Tween.TRANS_LINEAR)

	# Создание костяного копья (проектиль, который следует за рывком)
	bone_projectile_instance = Node2D.new()
	bone_projectile_instance.z_index = 2
	bone_projectile_instance.global_position = global_position
	get_tree().current_scene.add_child(bone_projectile_instance)

	var line = Line2D.new()
	line.width = 12.0
	line.default_color = Color(0.8, 0.75, 0.7, 0.9)
	line.z_index = 8
	bone_projectile_instance.add_child(line)

	await dash_tween.finished

	# Удар в точке приземления
	spawn_charge_hitbox()

	# Возврат к исходной позиции (частично)
	var return_target = start_pos + (charge_target_pos - start_pos) * 0.3
	var return_tween = create_tween()
	return_tween.tween_property(self, "global_position", return_target, 0.3).set_trans(Tween.TRANS_SINE)
	return_tween.parallel().tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)
	return_tween.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)

	await return_tween.finished

	if bone_projectile_instance:
		bone_projectile_instance.queue_free()
		bone_projectile_instance = null

	is_charging = false

func spawn_charge_hitbox() -> void:
	# Ударная волна в точке приземления
	var hitbox = Area2D.new()
	hitbox.z_index = 2
	var shape = CircleShape2D.new()
	shape.radius = 60.0
	var col = CollisionShape2D.new()
	col.shape = shape
	hitbox.add_child(col)
	hitbox.global_position = global_position
	hitbox.collision_layer = 0
	hitbox.collision_mask = 1
	get_tree().current_scene.add_child(hitbox)

	# Визуальный эффект — взрыв
	var explosion = CPUParticles2D.new()
	explosion.emitting = true
	explosion.one_shot = true
	explosion.explosiveness = 1.0
	explosion.amount = 40
	explosion.lifetime = 0.5
	explosion.spread = 360.0
	explosion.initial_velocity_min = 80.0
	explosion.initial_velocity_max = 150.0
	explosion.scale_amount_min = 3.0
	explosion.scale_amount_max = 6.0
	explosion.color = Color(0.9, 0.8, 0.6, 0.8)
	explosion.z_index = 10
	explosion.global_position = global_position
	get_tree().current_scene.add_child(explosion)

	AudioManager.play_sfx("босс_атака_выстрел")
	hitbox.body_entered.connect(_on_charge_hitbox_body_entered)

	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(hitbox):
		hitbox.queue_free()

func _on_charge_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_SKELETON_KING_BONE_SPEAR_DAMAGE))
		if body.has_method("apply_knockback"):
			body.apply_knockback(global_position, 1200.0)

# ============ УТИЛИТЫ ============
func update_run_animation(direction: Vector2):
	if abs(direction.x) > abs(direction.y):
		current_dir = Dir.RIGHT if direction.x > 0 else Dir.LEFT
	else:
		current_dir = Dir.DOWN if direction.y > 0 else Dir.UP
	anim.play("walk_" + _get_dir_string())

func _get_dir_string() -> String:
	match current_dir:
		Dir.UP:    return "up"
		Dir.DOWN:  return "down"
		Dir.LEFT:  return "left"
		Dir.RIGHT: return "right"
	return "down"

func _play_idle_animation():
	if anim.animation != "idle_down":
		anim.play("idle_down")

func take_damage(amount: int):
	if is_dead:
		return
	hp -= amount
	hp_bar.update_hp(hp, GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_SKELETON_KING_HP))
	if hp <= 0:
		death()
		return
	AudioManager.play_sfx("враг_урон")
	var tween = create_tween()
	tween.tween_property(anim, "modulate", Color(1, 0, 0, 1), 0.0)
	tween.tween_property(anim, "modulate", Color(1, 1, 1, 1), 0.15)

# ============ ДЕТЕКТОРЫ ЗОН АТАКИ ============
func _on_detector_melee_body_entered(body: Node2D) -> void:
	if is_dead: return
	if body.is_in_group("player"):
		player_in_melee_zone = true

func _on_detector_melee_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_melee_zone = false

func _on_detector_summon_body_entered(body: Node2D) -> void:
	if is_dead: return
	if body.is_in_group("player"):
		player_in_summon_zone = true

func _on_detector_summon_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_summon_zone = false

func _on_detector_charge_body_entered(body: Node2D) -> void:
	if is_dead: return
	if body.is_in_group("player"):
		player_in_charge_zone = true

func _on_detector_charge_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_charge_zone = false

func _on_hitbox_area_entered(area: Area2D) -> void:
	if is_dead: return
	# Любая Area2D (атака игрока) наносит урон
	take_damage(GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_SKELETON_KING_TAKE_DAMAGE))

func _on_attack_timer_timeout(): pass  # не используется, кулдауны через delta

func death():
	if is_dead: return
	is_dead = true
	can_walk = false
	is_attacking = false
	is_charging = false
	AudioManager.play_sfx("босс_смерть")
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	anim.stop()
	if bone_projectile_instance and is_instance_valid(bone_projectile_instance):
		bone_projectile_instance.queue_free()
	var d_anim = "death_" + _get_dir_string()
	anim.play(d_anim)
	
	# ТРЯСКА ЭКРАНА при смерти босса!
	var shaker = get_tree().get_first_node_in_group("camera_shaker")
	if not shaker:
		# Пробуем найти просто по пути или имени
		shaker = get_tree().root.find_child("CameraShaker", true, false)
	if shaker and shaker.has_method("add_trauma"):
		shaker.add_trauma(0.8)  # Сильная тряска (0.8 из 1.0)
		print("Тряска камеры: 0.8")
	
	await anim.animation_finished
	_give_exp_to_player()
	if randf() <= 0.75: _spawn_loot()
	_spawn_hatch()
	queue_free()

func _give_exp_to_player():
	var p = get_tree().get_first_node_in_group("player")
	if p and p.has_method("add_experience"):
		p.add_experience(GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_SKELETON_KING_EXP_REWARD))

func _spawn_loot():
	var potion = GameConstants.HEALTH_POTION.instantiate()
	potion.global_position = global_position
	get_tree().current_scene.add_child(potion)

func _spawn_hatch():
	var hatch = HATCH_SCENE.instantiate()
	hatch.global_position = global_position
	get_tree().current_scene.add_child(hatch)
	hatch.open_hatch()
