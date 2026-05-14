extends CharacterBody2D

@export var hp = 10
var max_speed = 0.0
var max_hp = 0

@onready var animP = $AnimationPlayer
@onready var attack_timer = $attack_timer
@onready var anim = $AnimatedSprite2D
@onready var hp_bar = $TextureProgressBar
@onready var detector_area: Area2D = $detector

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
	
	player = PlayerManager.get_nearest_target_player_node(global_position) as Node2D
	parent_node = get_parent()
	attack_timer.start(1.0)

func _physics_process(_delta: float) -> void:
	if NetworkManager.enemy_client_interpolate_if_needed(self, _delta):
		return
	if is_dead: return

	player = PlayerManager.get_nearest_target_player_node(global_position) as Node2D
	if NetworkManager.is_multiplayer_active():
		player_in_range = PlayerManager.detector_has_living_player(detector_area)

	var is_aggressive = parent_node and parent_node.get("aggression")

	if is_aggressive and player_in_range and can_attack and can_move:
		attack()

	if not player or not is_instance_valid(player) or not can_move:
		velocity = Vector2.ZERO
		if not animP.is_playing() and can_anim:
			anim.play("idle_down")
		move_and_slide()
		return

	var ppos := PlayerManager.get_player_world_pos_for_hosting_ai(player)
	var to_player = ppos - global_position
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


func _sync_facing_dir_from_sprite_animation() -> void:
	var s := str(anim.animation)
	for suf_key in ["_up", "_down", "_left", "_right"]:
		if s.ends_with(suf_key):
			match suf_key:
				"_up":
					current_dir = Dir.UP
				"_down":
					current_dir = Dir.DOWN
				"_left":
					current_dir = Dir.LEFT
				"_right":
					current_dir = Dir.RIGHT
			return


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
	var target_dir := (PlayerManager.get_player_world_pos_for_hosting_ai(player) - global_position).normalized()
	if target_dir == Vector2.ZERO:
		target_dir = Vector2.RIGHT
	projectile_instance.direction = target_dir
	projectile_instance.rotation = target_dir.angle()
	get_tree().current_scene.add_child.call_deferred(projectile_instance)
	AudioManager.play_sfx("враг_яд_выстрел")
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() and mp.is_server():
		NetworkManager.host_mirror_projectile_if_coop(
			GameConstants.GOBLIN_SLINGER_PROJECTILE.resource_path,
			projectile_instance.global_position,
			target_dir
		)

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

	if is_instance_valid(player):
		update_direction(PlayerManager.get_player_world_pos_for_hosting_ai(player) - global_position)
	elif velocity.length_squared() > 4.0:
		update_direction(velocity)
	else:
		_sync_facing_dir_from_sprite_animation()

	velocity = Vector2.ZERO
	anim.stop()
	animP.stop(true)

	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)

	var death_key := "death_down"
	match current_dir:
		Dir.UP:
			death_key = "death_up"
		Dir.DOWN:
			death_key = "death_down"
		Dir.LEFT:
			death_key = "death_left"
		Dir.RIGHT:
			death_key = "death_right"

	# В библиотеке AnimationPlayer уже есть death_* с треками кадров — так надёжнее, чем только AnimatedSprite2D.play().
	animP.active = true
	if animP.has_animation(death_key):
		animP.play(death_key)
		await animP.animation_finished
	else:
		await _await_local_death_sprite(anim, death_key)
	animP.stop(true)
	animP.active = false
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
		if not PlayerManager.is_player_nearest_hosting_target(global_position, body):
			return
		var damage = GameConstants.get_scaled_enemy_stat(GameConstants.GOBLIN_SLINGER_BODY_DAMAGE)
		NetworkManager.server_apply_damage_to_player_from_enemy(body, damage)


func _await_local_death_sprite(
	sprite: AnimatedSprite2D,
	anim_name: String,
	fallback_sec: float = 0.75,
	max_wait_sec: float = 3.5
) -> void:
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
		var deadline_ms := Time.get_ticks_msec() + int(max_wait_sec * 1000.0)
		while sprite.is_playing() and Time.get_ticks_msec() < deadline_ms:
			await get_tree().process_frame
		if sprite.is_playing():
			sprite.stop()
	else:
		await get_tree().create_timer(fallback_sec).timeout
