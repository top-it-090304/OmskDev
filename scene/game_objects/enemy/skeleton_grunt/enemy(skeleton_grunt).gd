extends "res://scene/game_objects/enemy/enemy_base.gd"

var hp = 0

@onready var detector_shape = $detector/CollisionShape2D
@onready var detector_area: Area2D = $detector
@onready var anim = $AnimatedSprite2D
@onready var animP = $AnimationPlayer
@onready var attack_timer = $attack_timer
@onready var hp_bar = $TextureProgressBar

var speed = GameConstants.ENEMY_SKELETON_GRUNT_MAX_SPEED
enum Dir { DOWN, UP, LEFT, RIGHT }
var current_dir = Dir.DOWN

var player: Node2D = null
var parent_node: Node = null

var can_walk = true
var can_attack = true
var can_anim = true
var player_in_range = false
var smite_instance: Node2D = null

func _ready() -> void:
	add_to_group("enemys")
	hp = GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_SKELETON_GRUNT_HP)
	speed = GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_SKELETON_GRUNT_MAX_SPEED)
	hp_bar.update_hp(hp, hp)
	player = PlayerManager.get_nearest_target_player_node(global_position) as Node2D
	parent_node = get_parent()

func _is_player_in_attack_radius() -> bool:
	if not is_instance_valid(player):
		return false
	return global_position.distance_squared_to(PlayerManager.get_player_world_pos_for_hosting_ai(player)) <= GameConstants.ENEMY_SKELETON_GRUNT_ATTACK_RANGE * GameConstants.ENEMY_SKELETON_GRUNT_ATTACK_RANGE

func _physics_process(delta: float) -> void:
	if NetworkManager.enemy_client_interpolate_if_needed(self, delta):
		return
	_apply_knockback_logic(delta)
	
	if is_dead: 
		return

	player = PlayerManager.get_nearest_target_player_node(global_position) as Node2D
	if NetworkManager.is_multiplayer_active():
		player_in_range = PlayerManager.detector_has_living_player(detector_area)

	if not can_walk:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var is_aggressive = parent_node and parent_node.get("aggression")

	if is_instance_valid(player) and is_aggressive:
		var ppos := PlayerManager.get_player_world_pos_for_hosting_ai(player)
		var to_player = ppos - global_position
		var direction = to_player.normalized()
		velocity = direction * speed + knockback_velocity
		move_and_slide()
		if can_anim:
			update_run_animation(direction)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed)
		move_and_slide()
		if can_anim:
			play_idle_animation()

func update_run_animation(direction: Vector2):
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0:
			anim.play("run_right")
			current_dir = Dir.RIGHT
		else:
			anim.play("run_left")
			current_dir = Dir.LEFT
	else:
		if direction.y > 0:
			anim.play("run_down")
			current_dir = Dir.DOWN
		else:
			anim.play("run_up")
			current_dir = Dir.UP

func _process(_delta):
	if hp <= 0 and not is_dead:
		death()

func attack():
	if not can_attack or not player_in_range or is_dead:
		return
	if not _is_player_in_attack_radius():
		attack_timer.start(0.2)
		return
	can_attack = false
	can_anim = false
	anim.stop()
	# Weaker dash: multiplier 1.2 instead of goblin's 1.5
	speed *= 1.2
	match current_dir:
		Dir.UP: animP.play("attack_up")
		Dir.DOWN: animP.play("attack_down")
		Dir.LEFT: animP.play("attack_left")
		Dir.RIGHT: animP.play("attack_right")
	await animP.animation_finished
	speed /= 1.2
	can_anim = true
	if is_instance_valid(smite_instance):
		smite_instance.queue_free()
		smite_instance = null
	if not is_dead and can_anim:
		attack_timer.start()

func play_idle_animation():
	if is_dead: return
	if anim.animation != "idle_down":
		anim.play("idle_down")

func take_damage(amount: int):
	if is_dead: return
	hp -= amount
	var max_hp = GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_SKELETON_GRUNT_HP)
	hp_bar.update_hp(hp, max_hp)
	if hp <= 0:
		death()
		return
	AudioManager.play_sfx("враг_урон")
	var tween = create_tween()
	tween.tween_property(anim, "modulate", Color(1, 0, 0, 1), 0.0)
	tween.tween_property(anim, "modulate", Color(1, 1, 1, 1), 0.1)

func apply_knockback(source_position: Vector2, strength: float) -> void:
	super.apply_knockback(source_position, strength)

func death():
	if is_dead: return
	is_dead = true
	AudioManager.play_sfx("враг_смерть")
	can_walk = false
	can_attack = false
	velocity = Vector2.ZERO
	anim.stop()
	animP.active = false
	animP.stop(true)
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	match current_dir:
		Dir.UP: await _await_enemy_death_sprite(anim, "death_up")
		Dir.DOWN: await _await_enemy_death_sprite(anim, "death_down")
		Dir.LEFT: await _await_enemy_death_sprite(anim, "death_left")
		Dir.RIGHT: await _await_enemy_death_sprite(anim, "death_right")
	_give_exp_to_player()
	if randf() <= 0.25:
		_spawn_loot()
	queue_free()

func _give_exp_to_player():
	var player_node := PlayerManager.get_player_for_local_rewards()
	if player_node and player_node.has_method("add_experience"):
		var exp_reward = GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_SKELETON_GRUNT_EXP_REWARD)
		player_node.add_experience(exp_reward)

func _spawn_loot():
	var potion = GameConstants.HEALTH_POTION.instantiate()
	potion.global_position = global_position
	get_tree().current_scene.add_child(potion)

func swing():
	if not is_instance_valid(player) or is_dead:
		return
	if not _is_player_in_attack_radius():
		return
	smite_instance = GameConstants.ENEMY_SKELETON_GRUNT_SMITE.instantiate()
	add_child(smite_instance)
	smite_instance.visible = false
	smite_instance.monitoring = false
	var target_dir = (PlayerManager.get_player_world_pos_for_hosting_ai(player) - global_position).normalized()
	if "direction" in smite_instance:
		smite_instance.direction = target_dir
	smite_instance.position = target_dir * GameConstants.ENEMY_SKELETON_GRUNT_SMITE_OFFSET
	smite_instance.rotation = target_dir.angle()
	AudioManager.play_sfx("враг_атака_ближний")

func activate_smite():
	if not _is_player_in_attack_radius():
		if is_instance_valid(smite_instance):
			smite_instance.queue_free()
			smite_instance = null
		return
	if is_instance_valid(smite_instance) and not is_dead:
		smite_instance.visible = true
		smite_instance.monitoring = true

func _on_detector_body_entered(body: Node2D) -> void:
	if is_dead: return
	if body.is_in_group("player"):
		player_in_range = true
		if can_attack:
			attack()

func _on_detector_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false

func _on_attack_timer_timeout():
	if is_dead: return
	can_attack = true
	var is_aggressive = parent_node and parent_node.get("aggression")
	if player_in_range and is_aggressive:
		attack()

func _on_hitbox_area_entered(_area: Area2D) -> void:
	pass

func _on_hitbox_body_entered(body: Node2D) -> void:
	if is_dead: return
	if body.is_in_group("player") and body.has_method("take_damage"):
		if not PlayerManager.is_player_nearest_hosting_target(global_position, body):
			return
		if not _is_player_in_attack_radius():
			return
		var damage = GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_SKELETON_GRUNT_DAMAGE)
		NetworkManager.server_apply_damage_to_player_from_enemy(body, damage)