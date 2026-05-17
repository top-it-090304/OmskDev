extends "res://scene/game_objects/enemy/enemy_base.gd"

const HP_BAR_SCRIPT = preload("res://scene/game_objects/enemy/goblin_axe/texture_progress_bar.gd")
const ENEMY_LEVEL_DISPLAY = preload("res://scene/ui/enemy_level_display.tscn")

enum Dir { DOWN, UP, LEFT, RIGHT }

var hp := 0
var max_hp := 0
var speed: float = GameConstants.ENEMY_MAN_STICK_MAX_SPEED
var current_dir := Dir.DOWN
var player: Node2D = null
var parent_node: Node = null
var can_walk := true
var can_attack := true
var can_anim := true
var player_in_range := false
var smite_instance: Node2D = null

@onready var anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var animP: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
@onready var detector_area: Area2D = get_node_or_null("detector") as Area2D
@onready var attack_timer: Timer = get_node_or_null("attack_timer") as Timer
@onready var hp_bar: TextureProgressBar = get_node_or_null("TextureProgressBar") as TextureProgressBar


func _ready() -> void:
	_ensure_runtime_nodes()
	add_to_group("enemys")
	max_hp = GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_MAN_STICK_HP)
	hp = max_hp
	speed = GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_MAN_STICK_MAX_SPEED)
	hp_bar.update_hp(hp, max_hp)
	player = PlayerManager.get_nearest_target_player_node(global_position) as Node2D
	parent_node = get_parent()
	play_idle_animation()


func _is_player_in_attack_radius() -> bool:
	if not is_instance_valid(player):
		return false
	return global_position.distance_squared_to(PlayerManager.get_player_world_pos_for_hosting_ai(player)) <= GameConstants.ENEMY_MAN_STICK_ATTACK_RANGE * GameConstants.ENEMY_MAN_STICK_ATTACK_RANGE


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

	var aggressive := parent_node != null and GameConstants.variant_to_bool(parent_node.get("aggression"))
	if is_instance_valid(player) and aggressive:
		var ppos := PlayerManager.get_player_world_pos_for_hosting_ai(player)
		var to_player := ppos - global_position
		var direction := to_player.normalized()
		velocity = direction * speed + knockback_velocity
		move_and_slide()
		if can_anim:
			update_run_animation(direction)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed)
		move_and_slide()
		if can_anim:
			play_idle_animation()


func attack() -> void:
	if not can_attack or not player_in_range or is_dead:
		return
	if not _is_player_in_attack_radius():
		attack_timer.start(0.2)
		return
	can_attack = false
	can_anim = false
	anim.stop()
	var attack_anim_name := "attack_" + _dir_string()
	match current_dir:
		Dir.UP:
			attack_anim_name = "attack_up"
		Dir.DOWN:
			attack_anim_name = "attack_down"
		Dir.LEFT:
			attack_anim_name = "attack_left"
		Dir.RIGHT:
			attack_anim_name = "attack_right"
	if animP != null and animP.has_animation(attack_anim_name):
		animP.play(attack_anim_name)
	else:
		_play_anim_from_start(attack_anim_name, "attack_down")
	if animP != null and animP.is_playing():
		await _wait_anim_player_or_timeout(_get_sprite_anim_duration(attack_anim_name) + 0.2)
	else:
		await _wait_sprite_animation_finished_or_timeout(attack_anim_name, _get_sprite_anim_duration(attack_anim_name) + 0.2)
	can_anim = true
	if is_instance_valid(smite_instance):
		smite_instance.queue_free()
		smite_instance = null
	if not is_dead and can_anim:
		attack_timer.start()


func update_run_animation(direction: Vector2) -> void:
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0.0:
			current_dir = Dir.RIGHT
		else:
			current_dir = Dir.LEFT
	else:
		if direction.y > 0.0:
			current_dir = Dir.DOWN
		else:
			current_dir = Dir.UP
	_play_anim("walk_" + _dir_string(), "walk_down")


func play_idle_animation() -> void:
	if is_dead:
		return
	_play_anim("idle_" + _dir_string(), "idle_down")


func take_damage(amount: int) -> void:
	if is_dead:
		return
	hp -= amount
	hp_bar.update_hp(maxi(0, hp), max_hp)
	if hp <= 0:
		death()
		return
	AudioManager.play_sfx("враг_урон")
	var tween := create_tween()
	tween.tween_property(anim, "modulate", Color(1, 0, 0, 1), 0.0)
	tween.tween_property(anim, "modulate", Color(1, 1, 1, 1), 0.15)


func death() -> void:
	if is_dead:
		return
	is_dead = true
	can_walk = false
	can_attack = false
	velocity = Vector2.ZERO
	anim.stop()
	if animP != null:
		animP.stop()
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	_play_anim("death_" + _dir_string(), "death_down")
	await _await_enemy_death_sprite(anim, anim.animation)
	_give_exp_to_player()
	if randf() <= 0.25:
		_spawn_loot()
	queue_free()


func swing() -> void:
	if not is_instance_valid(player) or is_dead:
		return
	if not _is_player_in_attack_radius():
		return
	smite_instance = GameConstants.ENEMY_GOBLIN_AXE_SMITE.instantiate()
	add_child(smite_instance)
	smite_instance.visible = false
	smite_instance.monitoring = false
	var target_dir := (PlayerManager.get_player_world_pos_for_hosting_ai(player) - global_position).normalized()
	if "direction" in smite_instance:
		smite_instance.direction = target_dir
	smite_instance.position = target_dir * GameConstants.ENEMY_MAN_STICK_SMITE_OFFSET
	smite_instance.rotation = target_dir.angle()
	AudioManager.play_sfx("враг_атака_ближний")


func activate_smite() -> void:
	if not _is_player_in_attack_radius():
		if is_instance_valid(smite_instance):
			smite_instance.queue_free()
			smite_instance = null
		return
	if is_instance_valid(smite_instance) and not is_dead:
		smite_instance.visible = true
		smite_instance.monitoring = true


func _on_detector_body_entered(body: Node2D) -> void:
	if is_dead:
		return
	if body.is_in_group("player"):
		player_in_range = true
		if can_attack:
			attack()


func _on_detector_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false


func _on_attack_timer_timeout() -> void:
	if is_dead:
		return
	can_attack = true
	var aggressive := parent_node != null and GameConstants.variant_to_bool(parent_node.get("aggression"))
	if player_in_range and aggressive:
		attack()


func _on_hitbox_area_entered(_area: Area2D) -> void:
	pass


func _on_hitbox_body_entered(body: Node2D) -> void:
	if is_dead:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		if not PlayerManager.is_player_nearest_hosting_target(global_position, body):
			return
		if not _is_player_in_attack_radius():
			return
		var damage := GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_MAN_STICK_DAMAGE)
		NetworkManager.server_apply_damage_to_player_from_enemy(body, damage)


func _play_anim(anim_name: String, fallback: String) -> void:
	if anim == null or anim.sprite_frames == null:
		return
	if anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)
	elif anim.sprite_frames.has_animation(fallback):
		anim.play(fallback)


func _play_anim_from_start(anim_name: String, fallback: String) -> void:
	if anim == null or anim.sprite_frames == null:
		return
	if anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)
	elif anim.sprite_frames.has_animation(fallback):
		anim.play(fallback)
	else:
		return
	anim.frame = 0
	anim.frame_progress = 0.0


func _dir_string() -> String:
	match current_dir:
		Dir.UP:
			return "up"
		Dir.DOWN:
			return "down"
		Dir.LEFT:
			return "left"
		Dir.RIGHT:
			return "right"
	return "down"


func _wait_anim_player_or_timeout(timeout_sec: float) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while animP != null and animP.is_playing() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _wait_anim_or_timeout(timeout_sec: float) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while anim != null and anim.is_playing() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _wait_sprite_animation_finished_or_timeout(anim_name: String, timeout_sec: float) -> void:
	if anim == null:
		return
	var finished := [false]
	var on_finished := func() -> void:
		finished[0] = true
	if not anim.animation_finished.is_connected(on_finished):
		anim.animation_finished.connect(on_finished, CONNECT_ONE_SHOT)
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while not finished[0] and anim.animation == anim_name and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if anim.animation_finished.is_connected(on_finished):
		anim.animation_finished.disconnect(on_finished)


func _get_sprite_anim_duration(anim_name: String) -> float:
	if anim == null or anim.sprite_frames == null:
		return 1.0
	var frames := anim.sprite_frames
	if not frames.has_animation(anim_name):
		return 1.0
	var frame_count := frames.get_frame_count(anim_name)
	var fps := frames.get_animation_speed(anim_name)
	if fps <= 0.0:
		return 1.0
	var duration := 0.0
	for i in range(frame_count):
		duration += frames.get_frame_duration(anim_name, i) / fps
	return maxf(duration, 0.1)


func _give_exp_to_player() -> void:
	var p := PlayerManager.get_player_for_local_rewards()
	if p and p.has_method("add_experience"):
		p.add_experience(GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_MAN_STICK_EXP_REWARD))


func _spawn_loot() -> void:
	var potion := GameConstants.HEALTH_POTION.instantiate()
	potion.global_position = global_position
	get_tree().current_scene.add_child(potion)


func _ensure_runtime_nodes() -> void:
	if anim == null:
		anim = AnimatedSprite2D.new()
		anim.name = "AnimatedSprite2D"
		anim.z_index = 1
		add_child(anim)
	if animP == null:
		animP = AnimationPlayer.new()
		animP.name = "AnimationPlayer"
		add_child(animP)
	if get_node_or_null("CollisionShape2D") == null:
		var body_shape := CollisionShape2D.new()
		body_shape.name = "CollisionShape2D"
		var capsule := CapsuleShape2D.new()
		capsule.radius = 10.0
		capsule.height = 28.0
		body_shape.shape = capsule
		add_child(body_shape)
	if get_node_or_null("hitbox") == null:
		var hitbox := Area2D.new()
		hitbox.name = "hitbox"
		hitbox.collision_layer = 0
		hitbox.collision_mask = 4
		var hit_shape := CollisionShape2D.new()
		var hit_capsule := CapsuleShape2D.new()
		hit_capsule.radius = 10.0
		hit_capsule.height = 28.0
		hit_shape.shape = hit_capsule
		hitbox.add_child(hit_shape)
		add_child(hitbox)
		hitbox.area_entered.connect(_on_hitbox_area_entered)
		hitbox.body_entered.connect(_on_hitbox_body_entered)
	if detector_area == null:
		detector_area = Area2D.new()
		detector_area.name = "detector"
		detector_area.collision_mask = 2
		var detector_shape := CollisionShape2D.new()
		var detector_circle := CircleShape2D.new()
		detector_circle.radius = 110.0
		detector_shape.shape = detector_circle
		detector_area.add_child(detector_shape)
		add_child(detector_area)
		detector_area.body_entered.connect(_on_detector_body_entered)
		detector_area.body_exited.connect(_on_detector_body_exited)
	if attack_timer == null:
		attack_timer = Timer.new()
		attack_timer.name = "attack_timer"
		attack_timer.wait_time = GameConstants.ENEMY_MAN_STICK_ATTACK_COOLDOWN
		attack_timer.one_shot = true
		add_child(attack_timer)
		attack_timer.timeout.connect(_on_attack_timer_timeout)
	if hp_bar == null:
		hp_bar = TextureProgressBar.new()
		hp_bar.name = "TextureProgressBar"
		hp_bar.offset_left = -18.0
		hp_bar.offset_top = 17.0
		hp_bar.offset_right = 26.0
		hp_bar.offset_bottom = 23.0
		hp_bar.scale = Vector2(0.8, 0.8)
		hp_bar.texture_under = load("res://assets/hpUnderEnemy.png")
		hp_bar.texture_progress = load("res://assets/hpProgressEnemy.png")
		hp_bar.set_script(HP_BAR_SCRIPT)
		add_child(hp_bar)
	if get_node_or_null("EnemyLevelDisplay") == null:
		var level_display := ENEMY_LEVEL_DISPLAY.instantiate()
		level_display.name = "EnemyLevelDisplay"
		add_child(level_display)
