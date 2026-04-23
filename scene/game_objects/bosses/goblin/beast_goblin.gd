extends CharacterBody2D

const HATCH_SCENE = preload("res://scene/pick_up/hatch.tscn")

# Дистанции поведения
const APPROACH_DIST  = 118.0   # ближе — подходим
const TELEPORT_INTERVAL = 8.0  # каждые N секунд телепортируется

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

var smite_instance: Node2D = null
var is_attacking = false

var _teleport_timer := 0.0

func _ready() -> void:
	add_to_group("enemys")
	hp = GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_BEASTGOBLIN_HP)
	speed = GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_BEASTGOBLIN_MAX_SPEED)
	hp_bar.update_hp(hp, hp)
	player = get_tree().get_first_node_in_group("player") as Node2D
	parent_node = get_parent()
	attack_timer.one_shot = true
	_play_idle_animation()

func _physics_process(delta: float) -> void:
	if is_dead: return

	var is_aggressive = parent_node and parent_node.get("aggression")
	if not is_aggressive or not is_instance_valid(player):
		velocity = Vector2.ZERO
		move_and_slide()
		if can_anim and not is_attacking: _play_idle_animation()
		return

	# --- ТЕЛЕПОРТ ---
	_teleport_timer += delta
	if _teleport_timer >= TELEPORT_INTERVAL and not is_attacking:
		_teleport_timer = 0.0
		_do_teleport()
		return

	if not can_walk: return

	var to_player = player.global_position - global_position
	var dist = to_player.length()
	var direction = to_player.normalized()

	# --- ДВИЖЕНИЕ ---
	if player_in_bite_zone or player_in_slap_zone:
		# В зоне ближней атаки — стоим
		velocity = Vector2.ZERO
		if can_anim: _play_idle_animation()
	elif dist <= APPROACH_DIST:
		# Близко — подходим вплотную
		velocity = direction * speed
		move_and_slide()
		if can_anim: update_run_animation(direction)
	else:
		# Далеко — отходим от игрока
		velocity = -direction * speed
		move_and_slide()
		if can_anim: update_run_animation(-direction)

	# --- АТАКА ---
	if can_attack and not is_attacking:
		can_attack = false
		if player_in_bite_zone:
			attack("bite")
		elif player_in_slap_zone:
			attack("slap")
		elif player_in_shoot_zone:
			# 40% шанс summon вместо обычного shoot
			if randf() < 0.4:
				attack("summon")
			else:
				attack("shoot")
		else:
			can_attack = true

func _do_teleport():
	if not is_instance_valid(player) or is_dead: return
	can_walk = false
	can_anim = false

	var tween_out = create_tween()
	tween_out.tween_property(anim, "modulate:a", 0.0, 0.2)
	await tween_out.finished

	# Получаем границы комнаты через room_shape
	var room = get_parent().get_parent() if get_parent() else null
	var room_rect: Rect2 = Rect2()
	if room:
		var room_shape_node = room.find_child("room_shape", true, false)
		if room_shape_node:
			var col = room_shape_node.get_child(0) as CollisionShape2D
			if col and col.shape is RectangleShape2D:
				var half = (col.shape as RectangleShape2D).size / 2.0
				var center = room_shape_node.global_position + col.position
				room_rect = Rect2(center - half, half * 2.0)

	var new_pos = global_position
	if room_rect.size != Vector2.ZERO:
		var margin = 60.0
		var inner = room_rect.grow(-margin)
		for _attempt in range(15):
			var candidate = Vector2(
				randf_range(inner.position.x, inner.end.x),
				randf_range(inner.position.y, inner.end.y)
			)
			# Не телепортируемся прямо на игрока
			if candidate.distance_to(player.global_position) > 100.0:
				new_pos = candidate
				break

	global_position = new_pos

	var tween_in = create_tween()
	tween_in.tween_property(anim, "modulate:a", 1.0, 0.2)
	await tween_in.finished

	can_walk = true
	can_anim = true

func attack(type: String):
	if is_dead or is_attacking: return
	is_attacking = true
	can_walk = false
	can_anim = false
	# summon использует анимацию shoot
	var anim_type = "shoot" if type == "summon" else type
	var anim_name = anim_type + "_" + _get_dir_string()
	if animP.has_animation(anim_name):
		animP.play(anim_name)
		# Для summon — спавним снаряды в середине анимации
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
		if attack_timer.is_stopped():
			attack_timer.start()

# --- АТАКИ ---

func spawn_bite_swing():
	if not is_instance_valid(player) or is_dead: return
	smite_instance = GameConstants.ENEMY_GOBLIN_AXE_SMITE.instantiate()
	get_tree().current_scene.add_child(smite_instance)
	smite_instance.global_position = global_position
	smite_instance.visible = false
	smite_instance.monitoring = false
	var target_dir = (player.global_position - global_position).normalized()
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
	var dir = (player.global_position - global_position).normalized()
	proj.direction = dir
	proj.global_position = global_position
	proj.rotation = dir.angle()
	proj.scale = Vector2(2.5, 2.5)
	get_tree().current_scene.add_child(proj)

# Summon — спавн 8 снарядов goblin_slinger по кругу
func summon_projectiles():
	if is_dead: return
	var count = 8
	for i in range(count):
		var angle = (TAU / count) * i
		var dir = Vector2(cos(angle), sin(angle))
		var proj = GameConstants.GOBLIN_SLINGER_PROJECTILE.instantiate()
		proj.global_position = global_position
		proj.direction = dir
		proj.rotation = angle
		proj.scale = Vector2(2.5, 2.5)
		get_tree().current_scene.add_child(proj)

func _on_slap_body_entered(body: Node2D) -> void:
	if is_dead: return
	if body.is_in_group("player"):
		AudioManager.play_sfx("босс_атака_удар")
		if body.has_method("take_damage"):
			var damage = GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_BEASTGOBLIN_SLAP_DAMAGE)
			body.take_damage(damage)
		if body.has_method("apply_knockback"):
			body.apply_knockback(global_position, 800.0)

func take_damage(amount: int):
	if is_dead: return
	hp -= amount
	var max_hp = GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_BEASTGOBLIN_HP)
	hp_bar.update_hp(hp, max_hp)
	if hp <= 0:
		death()
		return
	AudioManager.play_sfx("враг_урон")
	var tween = create_tween()
	tween.tween_property(anim, "modulate", Color(1, 0, 0, 1), 0.0)
	tween.tween_property(anim, "modulate", Color(1, 1, 1, 1), 0.15)

func _on_detector_bite_body_entered(body): if body.is_in_group("player"): player_in_bite_zone = true
func _on_detector_bite_body_exited(body): if body.is_in_group("player"): player_in_bite_zone = false
func _on_detector_slap_body_entered(body): if body.is_in_group("player"): player_in_slap_zone = true
func _on_detector_slap_body_exited(body): if body.is_in_group("player"): player_in_slap_zone = false
func _on_detector_shoot_body_entered(body): if body.is_in_group("player"): player_in_shoot_zone = true
func _on_detector_shoot_body_exited(body): if body.is_in_group("player"): player_in_shoot_zone = false

func _on_hitbox_area_entered(_area): take_damage(GameConstants.ENEMY_BEASTGOBLIN_TAKE_DAMAGE)
func _on_attack_timer_timeout(): can_attack = true

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
	AudioManager.play_sfx("босс_смерть")
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	animP.stop()
	if is_instance_valid(smite_instance): smite_instance.queue_free()
	var d_anim = "death_" + _get_dir_string()
	if _get_dir_string() == "down": d_anim = "death_dowm"
	anim.play(d_anim)
	await anim.animation_finished
	_give_exp_to_player()
	if randf() <= 0.75:
		_spawn_loot()
	_spawn_hatch()
	queue_free()

func _spawn_hatch():
	var hatch = HATCH_SCENE.instantiate()
	hatch.global_position = global_position
	get_tree().current_scene.add_child(hatch)
	hatch.open_hatch()

func _give_exp_to_player():
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node and player_node.has_method("add_experience"):
		var exp_reward = GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_BEASTGOBLIN_EXP_REWARD)
		player_node.add_experience(exp_reward)

func _spawn_loot():
	var potion = GameConstants.HEALTH_POTION.instantiate()
	potion.global_position = global_position
	get_tree().current_scene.add_child(potion)
