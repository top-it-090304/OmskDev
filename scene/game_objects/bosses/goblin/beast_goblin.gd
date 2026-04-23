extends CharacterBody2D

const HATCH_SCENE = preload("res://scene/pick_up/hatch.tscn")

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

func _ready() -> void:
	add_to_group("enemys")
	hp = GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_BEASTGOBLIN_HP)
	speed = GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_BEASTGOBLIN_MAX_SPEED)
	hp_bar.update_hp(hp, hp)
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

		if player_in_bite_zone or player_in_slap_zone:
			velocity = Vector2.ZERO
			if can_anim: _play_idle_animation()
		else:
			velocity = direction * speed
			move_and_slide()
			if can_anim: update_run_animation(direction)

		# Атака только если не атакуем прямо сейчас
		if can_attack and not is_attacking:
			can_attack = false  # блокируем сразу, до вызова coroutine
			if player_in_bite_zone:
				attack("bite")
			elif player_in_slap_zone:
				attack("slap")
			elif player_in_shoot_zone:
				attack("shoot")
			else:
				can_attack = true  # никто не в зоне — возвращаем
	else:
		velocity = Vector2.ZERO
		move_and_slide()
		if can_anim and not is_dead and not is_attacking: _play_idle_animation()

func attack(type: String):
	if is_dead or is_attacking: return
	is_attacking = true
	can_walk = false
	can_anim = false
	var anim_name = type + "_" + _get_dir_string()
	if animP.has_animation(anim_name):
		animP.play(anim_name)
		# Ждём завершения с таймаутом — если animation_finished не придёт, выходим через 3 сек
		var timeout = get_tree().create_timer(3.0)
		await _wait_for_attack_end(timeout)
	else:
		await get_tree().create_timer(0.5).timeout
	animP.stop()
	_reset_after_attack()

func _wait_for_attack_end(timeout: SceneTreeTimer) -> void:
	# Ждём первого из двух сигналов: конец анимации или таймаут
	var done = false
	animP.animation_finished.connect(func(_n): done = true, CONNECT_ONE_SHOT)
	timeout.timeout.connect(func(): done = true, CONNECT_ONE_SHOT)
	while not done:
		await get_tree().process_frame

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

func activate_bite():
	if is_instance_valid(smite_instance) and not is_dead:
		smite_instance.visible = true
		smite_instance.monitoring = true
	AudioManager.play_sfx("босс_атака_укус")

func shoot():
	if is_dead or not is_instance_valid(player): return
	var arrow = GameConstants.SKELETON_BOW_ARROW.instantiate()
	var dir = (player.global_position - global_position).normalized()
	if "direction" in arrow:
		arrow.direction = dir
	arrow.global_position = global_position
	arrow.rotation = dir.angle()
	get_tree().current_scene.add_child(arrow)

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
