extends CharacterBody2D

const SKELETON_MINION_SCENE = preload("res://scene/game_objects/enemy/skeleton_bow/skeleton_bow.tscn")
const BONE_PROJECTILE_SCENE = preload("res://scene/game_objects/enemy/skeleton_bow/arrow.tscn")
const ARTEFACT_SCENES = [
	preload("res://scene/pick_up/artefacts/artefact(boots_of_travel).tscn"),
	preload("res://scene/pick_up/artefacts/blue_shroom.tscn"),
	preload("res://scene/pick_up/artefacts/clock.tscn"),
	preload("res://scene/pick_up/artefacts/crown.tscn"),
	preload("res://scene/pick_up/artefacts/diamond.tscn")
]

const MELEE_RANGE      = 70.0   # Дистанция для атаки 01 (ближняя)

const CHARGE_RANGE     = 180.0  # Дистанция для атаки 03 (дальняя)

const ATTACK_COOLDOWN  = 4.5     # Базовый кулдаун между атаками (увеличен)
const SUMMON_COUNT     = 2      # Количество скелетов-миньонов за раз
const MAX_MINIONS      = 4      # Максимум скелетов на арене

var hp: int = 0
var speed: float = 0.0
var player_took_damage: bool = false
var active_minions: Array = []  # Отслеживаем активных миньонов

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
var _initial_attack_delay := 0.5  # Задержка перед первой атакой
var _first_attack_done := false

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
	player_took_damage = false
	_play_idle_animation()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Обновляем кулдауны
	_cd_melee  = max(0.0, _cd_melee  - delta)
	_cd_summon = max(0.0, _cd_summon - delta)
	_cd_charge = max(0.0, _cd_charge - delta)
	
	# Задержка перед первой атакой
	if not _first_attack_done:
		_initial_attack_delay -= delta
		if _initial_attack_delay > 0.0:
			return
		_first_attack_done = true

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

	# Очищаем список от удалённых миньонов
	_cleanup_minions()
	
	# Выбор атаки на основе дистанции и готовности
	if not is_attacking and not is_charging:
		# Приоритет: 1) melee (когда игрок близко) 2) charge (далеко) 3) summon (по кулдауну)
		if player_in_melee_zone and _cd_melee <= 0.0:
			_cd_melee = 3.5
			attack("melee")
		elif player_in_charge_zone and _cd_charge <= 0.0:
			_cd_charge = 3.5
			attack("charge")
		elif _cd_summon <= 0.0:  # summon работает только по кулдауну, без проверки расстояния
			_cd_summon = 7.0  # кулдаун суммона 7 секунд
			attack("summon")

# Возвращает дистанцию до игрока, к которой нужно стремиться
func _get_target_dist() -> float:
	# Приоритет атак по дистанциям: melee → charge
	# summon работает только по кулдауну, не влияет на движение
	var melee_ready  = _cd_melee  <= 0.0 and player_in_melee_zone
	var charge_ready = _cd_charge <= 0.0 and player_in_charge_zone

	if melee_ready:
		return MELEE_RANGE      # зона ближней атаки
	elif charge_ready:
		return CHARGE_RANGE     # зона ультимативной атаки
	else:
		# Если все на кулдауне — держимся на средней дистанции
		return 80.0

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
				# Визуальное предупреждение (каст) перед ударом
				var warning_tween = create_tween()
				warning_tween.tween_property(self, "modulate", Color(1.0, 0.3, 0.3, 1.0), 0.15)
				warning_tween.parallel().tween_property(self, "scale", Vector2(1.2, 1.2), 0.15)
				await get_tree().create_timer(0.35).timeout
				# Возврат к нормальному виду и удар
				var reset_tween = create_tween()
				reset_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)
				reset_tween.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
				spawn_melee_hitbox()
				await get_tree().create_timer(0.3).timeout
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

# ============ АТАКА 02: Призыв миньонов / Стрелы вокруг игрока ============
func _cleanup_minions() -> void:
	# Удаляем из списка мёртвых/удалённых миньонов
	active_minions = active_minions.filter(func(m): return is_instance_valid(m) and not m.is_dead if "is_dead" in m else is_instance_valid(m))

func summon_minions() -> void:
	AudioManager.play_sfx("босс_суммон")
	
	# Проверяем, можно ли призвать миньонов
	_cleanup_minions()
	var can_spawn = MAX_MINIONS - active_minions.size()
	
	if can_spawn > 0:
		# Спавним миньонов вокруг босса
		var to_spawn = mini(SUMMON_COUNT, can_spawn)
		var radius = 80.0
		for i in to_spawn:
			var angle = (TAU / float(to_spawn)) * i - PI/2
			var pos = global_position + Vector2(cos(angle), sin(angle)) * radius
			
			var minion = SKELETON_MINION_SCENE.instantiate()
			minion.z_index = 2
			var room = get_parent()
			if room:
				room.add_child(minion)
			else:
				get_tree().current_scene.add_child(minion)
			minion.global_position = pos
			minion.hp = 1
			minion.hp_bar.update_hp(1, 1)
			active_minions.append(minion)
			
			var tween = create_tween()
			tween.tween_property(minion, "modulate:a", 0.0, 0.0)
			tween.tween_property(minion, "modulate:a", 1.0, 0.3)
			
			# Частицы призыва (только если включены)
			if GameConstants.show_particles:
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
	
	# Если миньонов максимум — запускаем стрелы вокруг игрока
	_cleanup_minions()
	if active_minions.size() >= MAX_MINIONS:
		_spawn_arrows_around_player()

# ============ СТРЕЛЫ ВОКРУГ ИГРОКА ============
func _spawn_arrows_around_player() -> void:
	if not is_instance_valid(player):
		return
	
	var arrow_count = 5
	var radius = 60.0
	var arrows: Array = []
	
	# Создаём 5 стрел вокруг игрока с задержкой
	for i in arrow_count:
		var angle = (TAU / float(arrow_count)) * i
		var spawn_pos = player.global_position + Vector2(cos(angle), sin(angle)) * radius
		
		# Создаём стрелу
		var arrow = _create_warning_arrow(spawn_pos, player.global_position)
		arrows.append(arrow)
		
		# Задержка между созданием стрел
		await get_tree().create_timer(0.3).timeout
	
	# Ждём пока все стрелы "зарядятся" (светятся 0.3 сек)
	await get_tree().create_timer(0.3).timeout
	
	# Запускаем все стрелы к игроку
	for arrow in arrows:
		if is_instance_valid(arrow) and is_instance_valid(player):
			_launch_arrow_at_player(arrow)

func _create_warning_arrow(spawn_pos: Vector2, target_pos: Vector2) -> Node2D:
	var arrow = Area2D.new()
	arrow.z_index = 10
	arrow.global_position = spawn_pos
	
	# Направление к игроку (для поворота стрелы)
	var direction = (target_pos - spawn_pos).normalized()
	
	# Визуальная часть стрелы
	var sprite = Sprite2D.new()
	sprite.texture = preload("res://sprites/enemys/skeletonBow/arrow.png")
	sprite.rotation = direction.angle()
	sprite.modulate = Color(1.0, 0.5, 0.5, 1.0)  # Красноватый цвет
	arrow.add_child(sprite)
	
	# Коллизия
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	arrow.add_child(shape)
	arrow.collision_layer = 0
	arrow.collision_mask = 1  # игрок
	
	# Эффект свечения (пульсация)
	var glow_tween = create_tween()
	glow_tween.set_loops()
	glow_tween.tween_property(sprite, "modulate", Color(1.0, 0.3, 0.3, 1.0), 0.15)
	glow_tween.tween_property(sprite, "modulate", Color(1.0, 0.7, 0.7, 1.0), 0.15)
	arrow.set_meta("glow_tween", glow_tween)
	
	# Сохраняем направление для запуска
	arrow.set_meta("direction", direction)
	
	get_tree().current_scene.add_child(arrow)
	
	# Звук появления
	AudioManager.play_sfx("враг_выстрел_стрела")
	
	return arrow

func _launch_arrow_at_player(arrow: Node2D) -> void:
	if not is_instance_valid(arrow):
		return
	
	# Останавливаем свечение
	var glow_tween = arrow.get_meta("glow_tween")
	if glow_tween:
		glow_tween.kill()
	
	# Получаем направление (уже направлено к игроку)
	var direction: Vector2 = arrow.get_meta("direction", Vector2.DOWN)
	var speed = 300.0
	
	# Подключаем сигнал урона
	arrow.body_entered.connect(func(body):
		if body.is_in_group("player"):
			if body.has_method("take_damage"):
				body.take_damage(GameConstants.get_scaled_enemy_stat(GameConstants.SKELETON_BOW_BODY_DAMAGE))
			if is_instance_valid(arrow):
				arrow.queue_free()
	)
	
	# Движение стрелы
	var travel_time = 3.0
	var travel_tween = create_tween()
	travel_tween.tween_property(arrow, "global_position", arrow.global_position + direction * speed * travel_time, travel_time)
	travel_tween.tween_callback(arrow.queue_free)

# ============ АТАКА 03: Ультимативная способность (Bone Spear Rush) ============
func start_charge_attack() -> void:
	is_charging = true
	can_walk = false

	var start_pos = global_position
	# Цель — позиция игрока на момент начала атаки (не обновляется)
	charge_target_pos = player.global_position

	# Задержка перед рывком для возможности увернуться
	var warning_tween = create_tween()
	warning_tween.tween_property(self, "modulate", Color(1.0, 0.3, 0.3, 1.0), 0.15)
	warning_tween.parallel().tween_property(self, "scale", Vector2(1.2, 1.2), 0.15)
	await get_tree().create_timer(0.35).timeout

	# Анимация рывка
	var charge_tween = create_tween()
	charge_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 0.6), 0.05)
	charge_tween.parallel().tween_property(self, "scale", Vector2(1.3, 1.3), 0.05)

	# Рывок к цели (в 2 раза быстрее)
	var dash_duration = 0.125
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

	# Небольшая пауза перед возвратом
	await get_tree().create_timer(0.1).timeout

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

	# Визуальный эффект — подсветка области песочным цветом (как в melee)
	var flash = Polygon2D.new()
	var pts = PackedVector2Array()
	for i in 20:
		var a = (TAU / 20.0) * i
		pts.append(Vector2(cos(a), sin(a)) * 55.0)
	flash.polygon = pts
	flash.color = Color(0.9, 0.9, 0.95, 0.7)
	flash.z_index = 10
	flash.global_position = global_position
	get_tree().current_scene.add_child(flash)

	var tween = create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.25)
	tween.tween_callback(flash.queue_free)

	# Визуальный эффект — взрыв частиц (только если включены)
	if GameConstants.show_particles:
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
	player_took_damage = true
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
	_spawn_loot_near_hatch()
	_open_hatch_via_map_manager()
	queue_free()

func _give_exp_to_player():
	var p = get_tree().get_first_node_in_group("player")
	if p and p.has_method("add_experience"):
		p.add_experience(GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_SKELETON_KING_EXP_REWARD))

func _spawn_loot_near_hatch():
	var map_manager = get_tree().get_first_node_in_group("map_manager")
	if not map_manager:
		# Fallback - спавн на месте смерти босса
		_spawn_loot_fallback()
		return
	
	var hatch = map_manager.boss_hatch
	if not hatch or not is_instance_valid(hatch):
		_spawn_loot_fallback()
		return
	
	# Спавним артефакты на 32 пикселя ниже люка
	if player_took_damage:
		var artefact = ARTEFACT_SCENES[randi() % ARTEFACT_SCENES.size()].instantiate()
		artefact.z_index = 2
		var spawn_pos = hatch.global_position + Vector2(0, 32)
		hatch.get_parent().add_child(artefact)
		artefact.global_position = spawn_pos
	else:
		var artefact1 = ARTEFACT_SCENES[randi() % ARTEFACT_SCENES.size()].instantiate()
		var artefact2 = ARTEFACT_SCENES[randi() % ARTEFACT_SCENES.size()].instantiate()
		artefact1.z_index = 2
		artefact2.z_index = 2
		var spawn_pos = hatch.global_position + Vector2(0, 32)
		hatch.get_parent().add_child(artefact1)
		hatch.get_parent().add_child(artefact2)
		artefact1.global_position = spawn_pos + Vector2(-20, 0)
		artefact2.global_position = spawn_pos + Vector2(20, 0)

func _spawn_loot_fallback():
	# Старый метод - спавн на месте смерти босса
	if player_took_damage:
		var artefact = ARTEFACT_SCENES[randi() % ARTEFACT_SCENES.size()].instantiate()
		artefact.global_position = global_position
		get_tree().current_scene.add_child(artefact)
	else:
		var artefact1 = ARTEFACT_SCENES[randi() % ARTEFACT_SCENES.size()].instantiate()
		var artefact2 = ARTEFACT_SCENES[randi() % ARTEFACT_SCENES.size()].instantiate()
		artefact1.global_position = global_position + Vector2(-20, 0)
		artefact2.global_position = global_position + Vector2(20, 0)
		get_tree().current_scene.add_child(artefact1)
		get_tree().current_scene.add_child(artefact2)

func _open_hatch_via_map_manager():
	var map_manager = get_tree().get_first_node_in_group("map_manager")
	if map_manager and map_manager.has_method("open_boss_hatch"):
		map_manager.open_boss_hatch()
