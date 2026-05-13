extends CharacterBody2D

@export var hp = 10
var max_speed = 0.0
var max_hp = 0

@onready var animP = $AnimationPlayer
@onready var attack_timer = $attack_timer
@onready var anim = $AnimatedSprite2D
@onready var hp_bar = $TextureProgressBar

var player: Node2D = null
var parent_node: Node = null

enum Dir { DOWN, UP, LEFT, RIGHT }
var current_dir = Dir.DOWN

var can_move = true
var can_attack = false
var player_in_range = false
var get_closer = true
var is_dead = false
var can_anim = true

func _ready() -> void:
	add_to_group("enemys")
	
	# Расчет статов при спавне (используем Гоблина как пример)
	var base_hp = GameConstants.GOBLIN_SLINGER_HP
	max_hp = GameConstants.get_scaled_enemy_stat(base_hp)
	hp = max_hp
	
	var min_s = GameConstants.get_scaled_enemy_stat(GameConstants.GOBLIN_SLINGER_SPEED_MIN)
	var max_s = GameConstants.get_scaled_enemy_stat(GameConstants.GOBLIN_SLINGER_SPEED_MAX)
	max_speed = randf_range(min_s, max_s)
	
	hp_bar.update_hp(hp, max_hp)
	
	player = PlayerManager.get_player_for_local_rewards() as Node2D
	parent_node = get_parent()
	attack_timer.start(1.0)

func _physics_process(_delta: float) -> void:
	if is_dead: return

	if NetworkManager.is_multiplayer_active():
		player = PlayerManager.get_player_for_local_rewards() as Node2D

	var is_aggressive = parent_node and parent_node.get("aggression")

	if is_aggressive and player_in_range and can_attack and can_move:
		attack()

	if not player or not is_instance_valid(player) or not can_move:
		velocity = Vector2.ZERO
		if not animP.is_playing() and can_anim:
			anim.play("idle_down")
		move_and_slide()
		return

	var to_player = player.global_position - global_position
	var direction = to_player.normalized()
	update_direction(direction)

	if is_aggressive and get_closer:
		velocity = direction * max_speed
		if can_anim:
			play_run_animation()
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		if can_anim:
			anim.play("idle_down")

func _process(_delta):
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

func attack():
	if not can_attack or not player_in_range or is_dead:
		return
	can_move = false
	can_attack = false
	match current_dir:
		Dir.UP: animP.play("attack_up")
		Dir.DOWN: animP.play("attack_down")
		Dir.LEFT: animP.play("attack_left")
		Dir.RIGHT: animP.play("attack_right")
	
	await animP.animation_finished
	if not is_dead:
		can_move = true
		attack_timer.start()

func shoot_poison() -> void:
	if not player or not is_instance_valid(player) or is_dead:
		return
	var projectile_instance = GameConstants.GOBLIN_SLINGER_PROJECTILE.instantiate()
	projectile_instance.global_position = global_position
	var target_dir := (player.global_position - global_position).normalized()
	if target_dir == Vector2.ZERO:
		target_dir = Vector2.RIGHT
	projectile_instance.direction = target_dir
	projectile_instance.rotation = target_dir.angle()
	get_tree().current_scene.add_child.call_deferred(projectile_instance)
	AudioManager.play_sfx("враг_яд_выстрел")

func take_damage(amount: int):
	if is_dead: return
	hp -= amount
	hp_bar.update_hp(hp, max_hp)
	
	if hp <= 0:
		death()
		return
		
	AudioManager.play_sfx("враг_урон")
	var tween = create_tween()
	tween.tween_property(anim, "modulate", Color(1, 0, 0, 1), 0.0)
	tween.tween_property(anim, "modulate", Color(1, 1, 1, 1), 0.15)

func death():
	if is_dead: return
	is_dead = true
	AudioManager.play_sfx("враг_смерть")
	can_move = false
	can_attack = false
	velocity = Vector2.ZERO
	anim.stop()
	animP.stop()
	
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	
	match current_dir:
		Dir.UP: anim.play("death_up")
		Dir.DOWN: anim.play("death_down")
		Dir.LEFT: anim.play("death_left")
		Dir.RIGHT: anim.play("death_right")
		
	await anim.animation_finished
	_give_exp_to_player()
	queue_free()

func _give_exp_to_player():
	var player_node := PlayerManager.get_player_for_local_rewards()
	if player_node and player_node.has_method("add_experience"):
		# Замените на нужную константу опыта
		var exp_reward = GameConstants.get_scaled_enemy_stat(GameConstants.GOBLIN_SLINGER_EXP_REWARD)
		player_node.add_experience(exp_reward)

func _on_detector_body_entered(body: Node2D) -> void:
	if is_dead: return
	if body.is_in_group("player"):
		player_in_range = true
		get_closer = false
		if can_attack:
			can_attack = false
			attack_timer.start(0.4)

func _on_detector_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		get_closer = true

func _on_attack_timer_timeout():
	if is_dead: return
	can_attack = true

func _on_hitbox_body_entered(body: Node2D) -> void:
	if is_dead: return
	if body.is_in_group("player") and body.has_method("take_damage"):
		# Исправлено: теперь эта переменная есть в GameConstants
		var damage = GameConstants.get_scaled_enemy_stat(GameConstants.GOBLIN_SLINGER_BODY_DAMAGE)
		body.take_damage(damage)
