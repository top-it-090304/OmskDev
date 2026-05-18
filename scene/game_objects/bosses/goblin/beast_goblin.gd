extends CharacterBody2D

const HATCH_SCENE = preload("res://scene/pick_up/hatch.tscn")

# Тематические артефакты для Beast Goblin (природные/зелёные)
const ARTEFACT_SCENES = [
	preload("res://scene/pick_up/artefacts/small_cactus.tscn"),  # Кактус - природный
	preload("res://scene/pick_up/artefacts/lime_juice.tscn"),     # Лаймовый сок - зелёный
	preload("res://scene/pick_up/artefacts/ramen_bowl.tscn"),     # Рамен - еда
	preload("res://scene/pick_up/artefacts/bottle.tscn"),         # Бутылка - зелёная
	preload("res://scene/pick_up/artefacts/coffee_mug.tscn")      # Кофе - энергетик
]

const TELEPORT_INTERVAL = 4.0
const ATTACK_COOLDOWN   = 8.0

var hp = 0
var speed = GameConstants.ENEMY_BEASTGOBLIN_MAX_SPEED
var player_took_damage: bool = false

@onready var anim = $AnimatedSprite2D
@onready var animP = $AnimationPlayer
@onready var attack_timer = $attack_timer
@onready var hp_bar = $TextureProgressBar
@onready var detector_bite: Area2D = $detectorBite
@onready var detector_slap: Area2D = $detectorSlap
@onready var detector_shoot: Area2D = $detectorShoot

enum Dir { DOWN, UP, LEFT, RIGHT }
var current_dir = Dir.DOWN

var player: Node2D = null
var parent_node: Node = null

var player_in_bite_zone  = false
var player_in_slap_zone  = false
var player_in_shoot_zone = false

var can_walk   = true
var can_anim   = true
var is_dead    = false
var is_attacking = false

var smite_instance: Node2D = null

# Асинхронные кулдауны
var _cd_bite  := 0.0
var _cd_slap  := 0.0
var _cd_shoot := 0.0
var _teleport_timer := 0.0

func _ready() -> void:
	add_to_group("enemys")
	add_to_group("boss")
	hp    = GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_BEASTGOBLIN_HP)
	speed = GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_BEASTGOBLIN_MAX_SPEED)
	hp_bar.update_hp(hp, hp)
	player      = PlayerManager.get_nearest_target_player_node(global_position) as Node2D
	parent_node = get_parent()
	attack_timer.one_shot = true
	player_took_damage = false
	_play_idle_animation()

func _physics_process(delta: float) -> void:
	if NetworkManager.enemy_client_interpolate_if_needed(self, delta):
		return
	if is_dead: return

	player = PlayerManager.get_nearest_target_player_node(global_position) as Node2D
	if NetworkManager.is_multiplayer_active():
		player_in_bite_zone = PlayerManager.detector_has_living_player(detector_bite)
		player_in_slap_zone = PlayerManager.detector_has_living_player(detector_slap)
		player_in_shoot_zone = PlayerManager.detector_has_living_player(detector_shoot)

	_cd_bite  = max(0.0, _cd_bite  - delta)
	_cd_slap  = max(0.0, _cd_slap  - delta)
	_cd_shoot = max(0.0, _cd_shoot - delta)

	var is_aggressive = parent_node and parent_node.get("aggression")
	if not is_aggressive or not is_instance_valid(player):
		velocity = Vector2.ZERO
		move_and_slide()
		if can_anim and not is_attacking: _play_idle_animation()
		return

	_teleport_timer += delta
	if _teleport_timer >= TELEPORT_INTERVAL and not is_attacking:
		_teleport_timer = 0.0
		_do_teleport()
		return

	if not can_walk: return

	var ppos := PlayerManager.get_player_world_pos_for_hosting_ai(player)
	var to_player = ppos - global_position
	var dist      = to_player.length()
	var direction = to_player.normalized()

	# Определяем целевую дистанцию по следующей доступной атаке
	var target_dist := _get_target_dist()

	if not is_attacking:
		var move_dir := Vector2.ZERO
		if dist < target_dist - 10.0:
			# Слишком близко — отходим
			move_dir = -direction
		elif dist > target_dist + 10.0:
			# Слишком далеко — подходим
			move_dir = direction

		if move_dir != Vector2.ZERO:
			velocity = move_dir * speed
			move_and_slide()
			if can_anim: update_run_animation(move_dir)
		else:
			velocity = Vector2.ZERO
			if can_anim: _play_idle_animation()
	else:
		velocity = Vector2.ZERO

	if not is_attacking:
		if player_in_bite_zone and _cd_bite <= 0.0:
			_cd_bite = ATTACK_COOLDOWN
			attack("bite")
		elif player_in_slap_zone and _cd_slap <= 0.0:
			_cd_slap = ATTACK_COOLDOWN
			attack("slap")
		elif player_in_shoot_zone and _cd_shoot <= 0.0:
			_cd_shoot = ATTACK_COOLDOWN
			attack("summon" if randf() < 0.4 else "shoot")

# Возвращает дистанцию до игрока, к которой нужно стремиться
func _get_target_dist() -> float:
	# Приоритет: bite → slap → shoot
	# Если атака готова — идём к её зоне, иначе — к следующей готовой
	var bite_ready  = _cd_bite  <= 0.0
	var slap_ready  = _cd_slap  <= 0.0
	var shoot_ready = _cd_shoot <= 0.0

	if bite_ready:
		return 58.0   # зона укуса — вплотную
	elif slap_ready:
		return 86.0   # зона удара — средняя
	elif shoot_ready:
		return 136.0  # зона выстрела — далеко
	else:
		# Всё на кд — держимся на средней дистанции
		return 136.0

func attack(type: String):
	if is_dead or is_attacking: return
	is_attacking = true
	can_walk = false
	can_anim = false
	_show_attack_warning(Color(0.3, 1.0, 0.25, 0.5), 105.0, 0.28)
	var anim_type = "shoot" if type == "summon" else type
	var anim_name = anim_type + "_" + _get_dir_string()
	if animP.has_animation(anim_name):
		animP.play(anim_name)
		if type == "summon":
			await get_tree().create_timer(0.4).timeout
			summon_projectiles()
			await animP.animation_finished
		else:
			await animP.animation_finished
	else:
		await get_tree().create_timer(0.5).timeout
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
		_play_idle_animation()

func _do_teleport():
	if not is_instance_valid(player) or is_dead: return
	can_walk = false
	can_anim = false

	var tween_out = create_tween()
	tween_out.tween_property(anim, "modulate:a", 0.0, 0.2)
	await tween_out.finished

	var room = get_parent().get_parent() if get_parent() else null
	var room_rect := Rect2()
	if room:
		var rs = room.find_child("room_shape", true, false)
		if rs:
			var col = rs.get_child(0) as CollisionShape2D
			if col and col.shape is RectangleShape2D:
				var half = (col.shape as RectangleShape2D).size / 2.0
				var center = rs.global_position + col.position
				room_rect = Rect2(center - half, half * 2.0)

	var new_pos = global_position
	if room_rect.size != Vector2.ZERO:
		var inner = room_rect.grow(-60.0)
		for _i in range(15):
			var candidate = Vector2(
				randf_range(inner.position.x, inner.end.x),
				randf_range(inner.position.y, inner.end.y)
			)
			if candidate.distance_to(PlayerManager.get_player_world_pos_for_hosting_ai(player)) > 100.0:
				new_pos = candidate
				break

	global_position = new_pos

	var tween_in = create_tween()
	tween_in.tween_property(anim, "modulate:a", 1.0, 0.2)
	await tween_in.finished

	can_walk = true
	can_anim = true

func spawn_bite_swing():
	if not is_instance_valid(player) or is_dead: return
	smite_instance = GameConstants.ENEMY_GOBLIN_AXE_SMITE.instantiate()
	get_tree().current_scene.add_child(smite_instance)
	smite_instance.global_position = global_position
	smite_instance.visible = false
	smite_instance.monitoring = false
	smite_instance.scale = Vector2(2.5, 2.5)
	var target_dir = (PlayerManager.get_player_world_pos_for_hosting_ai(player) - global_position).normalized()
	if "direction" in smite_instance:
		smite_instance.direction = target_dir
	smite_instance.rotation = target_dir.angle()
	smite_instance.global_position += target_dir * 35

func spawn_bite_smite():
	spawn_bite_swing()

func activate_bite():
	if is_instance_valid(smite_instance) and not is_dead:
		smite_instance.visible = true
		smite_instance.monitoring = true
	AudioManager.play_sfx("босс_атака_укус")

func shoot():
	if is_dead or not is_instance_valid(player): return
	var proj = GameConstants.GOBLIN_SLINGER_PROJECTILE.instantiate()
	var dir = (PlayerManager.get_player_world_pos_for_hosting_ai(player) - global_position).normalized()
	proj.direction = dir
	proj.global_position = global_position
	proj.rotation = dir.angle()
	proj.scale = Vector2(2.5, 2.5)
	get_tree().current_scene.add_child(proj)
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() and mp.is_server():
		NetworkManager.host_mirror_projectile_if_coop(
			GameConstants.GOBLIN_SLINGER_PROJECTILE.resource_path,
			proj.global_position,
			dir
		)

func summon_projectiles():
	if is_dead: return
	for i in range(8):
		var angle = (TAU / 8.0) * i
		var dir = Vector2(cos(angle), sin(angle))
		var proj = GameConstants.GOBLIN_SLINGER_PROJECTILE.instantiate()
		proj.global_position = global_position
		proj.direction = dir
		proj.rotation = angle
		proj.scale = Vector2(2.5, 2.5)
		get_tree().current_scene.add_child(proj)
		var mp2 := get_tree().get_multiplayer()
		if mp2.has_multiplayer_peer() and mp2.is_server():
			NetworkManager.host_mirror_projectile_if_coop(
				GameConstants.GOBLIN_SLINGER_PROJECTILE.resource_path,
				proj.global_position,
				dir
			)

func spawn_slap_effect():
	if is_dead: return

	# Видимый круг — повторяет форму коллизии slap (radius 48 * scale 2 = 96)
	var circle = Polygon2D.new()
	var pts = PackedVector2Array()
	for i in 24:
		var a = (TAU / 24.0) * i
		pts.append(Vector2(cos(a), sin(a)) * 96.0)
	circle.polygon = pts
	circle.color = Color(0.78, 0.74, 0.70, 0.55)
	circle.z_index = 10
	circle.global_position = global_position
	get_tree().current_scene.add_child(circle)

	# Много частиц-осколков во все стороны (только если включены)
	if GameConstants.show_particles:
		var particles = CPUParticles2D.new()
		particles.emitting = true
		particles.one_shot = true
		particles.explosiveness = 1.0
		particles.amount = 60
		particles.lifetime = 0.5
		particles.spread = 180.0
		particles.initial_velocity_min = 90.0
		particles.initial_velocity_max = 180.0
		particles.scale_amount_min = 3.0
		particles.scale_amount_max = 7.0
		particles.color = Color(0.65, 0.62, 0.58, 1.0)
		particles.gravity = Vector2(0, 60)
		particles.z_index = 10
		particles.global_position = global_position
		get_tree().current_scene.add_child(particles)

	var tween = create_tween()
	tween.tween_property(circle, "color:a", 0.0, 0.3)
	tween.tween_callback(circle.queue_free)

func _on_slap_body_entered(body: Node2D) -> void:
	if is_dead: return
	if body.is_in_group("player"):
		if not PlayerManager.is_player_nearest_hosting_target(global_position, body):
			return
		AudioManager.play_sfx("босс_атака_удар")
		var dmg := GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_BEASTGOBLIN_SLAP_DAMAGE)
		NetworkManager.server_apply_damage_to_player_from_enemy(body, dmg)
		NetworkManager.server_apply_knockback_to_player_from_enemy(body, global_position, 800.0)

func take_damage(amount: int):
	if is_dead: return
	hp -= amount
	player_took_damage = true
	hp_bar.update_hp(hp, GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_BEASTGOBLIN_HP))
	if hp <= 0:
		death()
		return
	AudioManager.play_sfx("враг_урон")
	var tween = create_tween()
	tween.tween_property(anim, "modulate", Color(1, 0, 0, 1), 0.0)
	tween.tween_property(anim, "modulate", Color(1, 1, 1, 1), 0.1)

func _on_detector_bite_body_entered(body):  if body.is_in_group("player"): player_in_bite_zone  = true
func _on_detector_bite_body_exited(body):   if body.is_in_group("player"): player_in_bite_zone  = false
func _on_detector_slap_body_entered(body):  if body.is_in_group("player"): player_in_slap_zone  = true
func _on_detector_slap_body_exited(body):   if body.is_in_group("player"): player_in_slap_zone  = false
func _on_detector_shoot_body_entered(body): if body.is_in_group("player"): player_in_shoot_zone = true
func _on_detector_shoot_body_exited(body):  if body.is_in_group("player"): player_in_shoot_zone = false

func _on_hitbox_area_entered(_area) -> void:
	pass
func _on_attack_timer_timeout(): pass  # кулдауны теперь через delta

func update_run_animation(direction: Vector2):
	if abs(direction.x) > abs(direction.y):
		current_dir = Dir.RIGHT if direction.x > 0 else Dir.LEFT
	else:
		current_dir = Dir.DOWN if direction.y > 0 else Dir.UP
	anim.play("run_" + _get_dir_string())

func _get_dir_string() -> String:
	match current_dir:
		Dir.UP:    return "up"
		Dir.DOWN:  return "down"
		Dir.LEFT:  return "left"
		Dir.RIGHT: return "right"
	return "down"

func _play_idle_animation():
	if anim.animation != "idle_down": anim.play("idle_down")


func _show_attack_warning(color: Color, radius: float, duration: float) -> void:
	var warning := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(32):
		var angle := TAU * float(i) / 32.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	warning.polygon = points
	warning.color = color
	warning.z_index = z_index + 4
	warning.global_position = global_position
	get_tree().current_scene.add_child(warning)
	var tween := warning.create_tween()
	tween.tween_property(warning, "color:a", 0.0, duration)
	tween.tween_callback(warning.queue_free)

func death():
	if is_dead:
		return
	is_dead = true
	can_walk = false
	is_attacking = false
	AudioManager.play_sfx("босс_смерть")
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	animP.stop()
	if is_instance_valid(smite_instance): smite_instance.queue_free()
	var d_anim = "death_" + _get_dir_string()
	await _await_boss_death_animation(d_anim)
	_give_exp_to_player()
	if randf() <= 0.75: _spawn_loot()
	_spawn_artefact_near_hatch()
	_open_hatch_via_map_manager()
	queue_free()

func _spawn_artefact_near_hatch():
	var map_manager := _find_map_manager()
	if not map_manager:
		_spawn_artefact_fallback()
		return

	var hatch = map_manager.boss_hatch
	if not hatch or not is_instance_valid(hatch):
		_spawn_artefact_fallback()
		return

	var parent_n := hatch.get_parent() as Node2D
	if parent_n == null:
		_spawn_artefact_fallback()
		return
	var spawn_pos: Vector2 = (hatch as Node2D).global_position + Vector2(0, 48)
	var ps := _pick_boss_artefact_scene()
	if ps == null:
		return
	NetworkManager.server_spawn_boss_loot_for_coop(ps.resource_path, parent_n, spawn_pos)


func _spawn_artefact_fallback() -> void:
	var scene_root := get_tree().current_scene
	var parent_n := scene_root as Node2D
	var ps := _pick_boss_artefact_scene()
	if ps == null:
		return
	if parent_n != null:
		NetworkManager.server_spawn_boss_loot_for_coop(ps.resource_path, parent_n, global_position)
	else:
		var inst: Node2D = ps.instantiate() as Node2D
		inst.global_position = global_position
		scene_root.add_child(inst)


func _pick_boss_artefact_scene() -> PackedScene:
	var scenes := GameConstants.get_random_boss_artefact_scenes(1)
	if scenes.is_empty():
		return null
	return scenes[0]


func _open_hatch_via_map_manager():
	var map_manager := _find_map_manager()
	if map_manager and map_manager.has_method("open_boss_hatch"):
		map_manager.open_boss_hatch()


func _find_map_manager() -> Node:
	var mm := get_tree().get_first_node_in_group("map_manager")
	if mm != null:
		return mm
	mm = get_tree().root.find_child("MapManager", true, false)
	if mm != null:
		return mm
	return get_tree().root.find_child("MapManager2", true, false)


func _await_boss_death_animation(anim_name: String) -> void:
	if animP:
		animP.active = false
		animP.stop(true)
	if anim.sprite_frames != null and anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)
		var deadline_ms := Time.get_ticks_msec() + int(4000.0)
		while anim.is_playing() and Time.get_ticks_msec() < deadline_ms:
			await get_tree().process_frame
		if anim.is_playing():
			anim.stop()
	else:
		push_warning("beast_goblin: нет анимации %s" % anim_name)
		await get_tree().create_timer(1.0).timeout

func _give_exp_to_player():
	var p := PlayerManager.get_player_for_local_rewards()
	if p and p.has_method("add_experience"):
		p.add_experience(GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_BEASTGOBLIN_EXP_REWARD))

func _spawn_loot():
	var potion = GameConstants.HEALTH_POTION.instantiate()
	potion.global_position = global_position
	get_tree().current_scene.add_child(potion)
