extends "res://scene/game_objects/enemy/enemy_base.gd"

const WAVE_SCENE = preload("res://scene/effects/big_wave.tscn")
const HP_BAR_SCRIPT = preload("res://scene/game_objects/enemy/goblin_axe/texture_progress_bar.gd")
const ENEMY_LEVEL_DISPLAY = preload("res://scene/ui/enemy_level_display.tscn")

enum Dir { DOWN, UP, LEFT, RIGHT }

var hp := 0
var max_hp := 0
var speed: float = GameConstants.ENEMY_MAGICAN_MAX_SPEED
var current_dir := Dir.DOWN
var player: Node2D = null
var parent_node: Node = null
var can_anim := true
var is_attacking := false
var player_in_range := false
var _attack_cd := 1.0

@onready var anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var animP: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
@onready var detector_area: Area2D = get_node_or_null("detector") as Area2D
@onready var hp_bar: TextureProgressBar = get_node_or_null("TextureProgressBar") as TextureProgressBar


func _ready() -> void:
	_ensure_runtime_nodes()
	add_to_group("enemys")
	max_hp = GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_MAGICAN_HP)
	hp = max_hp
	speed = GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_MAGICAN_MAX_SPEED)
	hp_bar.update_hp(hp, max_hp)
	player = PlayerManager.get_nearest_target_player_node(global_position) as Node2D
	parent_node = get_parent()
	_play_idle_animation()


func _physics_process(delta: float) -> void:
	if NetworkManager.enemy_client_interpolate_if_needed(self, delta):
		return
	_apply_knockback_logic(delta)
	if is_dead:
		return

	player = PlayerManager.get_nearest_target_player_node(global_position) as Node2D
	_attack_cd = maxf(0.0, _attack_cd - delta)
	if NetworkManager.is_multiplayer_active() and detector_area != null:
		player_in_range = PlayerManager.detector_has_living_player(detector_area)

	var aggressive := parent_node != null and GameConstants.variant_to_bool(parent_node.get("aggression"))
	if not aggressive or not is_instance_valid(player):
		velocity = velocity.move_toward(Vector2.ZERO, speed)
		move_and_slide()
		if can_anim and not is_attacking:
			_play_idle_animation()
		return

	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var to_player := PlayerManager.get_player_world_pos_for_hosting_ai(player) - global_position
	var dist := to_player.length()
	var dir := to_player.normalized()
	if not NetworkManager.is_multiplayer_active():
		player_in_range = dist <= GameConstants.ENEMY_MAGICAN_ATTACK_RANGE

	if _attack_cd <= 0.0 and player_in_range and dist <= GameConstants.ENEMY_MAGICAN_ATTACK_RANGE:
		_attack_cd = GameConstants.ENEMY_MAGICAN_ATTACK_COOLDOWN
		attack()
		return

	if dist > GameConstants.ENEMY_MAGICAN_TARGET_DISTANCE:
		velocity = dir * speed + knockback_velocity
		move_and_slide()
		if can_anim:
			update_run_animation(dir)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed)
		move_and_slide()
		if can_anim:
			_play_idle_animation()


func attack() -> void:
	if is_dead or is_attacking or not is_instance_valid(player):
		return
	is_attacking = true
	can_anim = false
	_face_player()
	var anim_name := "attack_" + _dir_string()
	if animP != null and animP.has_animation(anim_name):
		animP.play(anim_name)
		await _wait_anim_player_or_timeout(1.4)
	else:
		_play_anim(anim_name, "attack_down")
		await get_tree().create_timer(0.45).timeout
		send_wave()
		await _wait_anim_or_timeout(0.9)
	_reset_after_attack()


func send_wave() -> void:
	if NetworkManager.enemy_mp_is_network_client():
		return
	if is_dead or not is_instance_valid(player):
		return
	var dir := (PlayerManager.get_player_world_pos_for_hosting_ai(player) - global_position).normalized()
	if dir.length_squared() <= 0.0:
		return
	var wave := WAVE_SCENE.instantiate()
	wave.direction = dir
	wave.speed = GameConstants.ENEMY_MAGICAN_WAVE_SPEED
	wave.damage = GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_MAGICAN_WAVE_DAMAGE)
	wave.global_position = global_position + dir * 34.0
	get_tree().current_scene.add_child(wave)
	AudioManager.play_sfx("враг_выстрел_стрела")
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() and mp.is_server():
		NetworkManager.host_mirror_projectile_if_coop(WAVE_SCENE.resource_path, wave.global_position, dir)


func shoot_wave() -> void:
	send_wave()


func _reset_after_attack() -> void:
	if is_dead:
		return
	is_attacking = false
	can_anim = true
	_play_idle_animation()


func update_run_animation(direction: Vector2) -> void:
	if abs(direction.x) > abs(direction.y):
		current_dir = Dir.RIGHT if direction.x > 0.0 else Dir.LEFT
	else:
		current_dir = Dir.DOWN if direction.y > 0.0 else Dir.UP
	_play_anim("walk_" + _dir_string(), "walk_down")


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
	tween.tween_property(anim, "modulate", Color(1, 1, 1, 1), 0.1)


func death() -> void:
	if is_dead:
		return
	is_dead = true
	is_attacking = false
	velocity = Vector2.ZERO
	AudioManager.play_sfx("враг_смерть")
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	if animP != null:
		animP.stop()
	_play_anim("death_" + _dir_string(), "death_down")
	await _await_enemy_death_sprite(anim, anim.animation)
	_give_exp_to_player()
	if randf() <= 0.25:
		_spawn_loot()
	queue_free()


func _face_player() -> void:
	if not is_instance_valid(player):
		return
	var dir := PlayerManager.get_player_world_pos_for_hosting_ai(player) - global_position
	if abs(dir.x) > abs(dir.y):
		current_dir = Dir.RIGHT if dir.x > 0.0 else Dir.LEFT
	else:
		current_dir = Dir.DOWN if dir.y > 0.0 else Dir.UP


func _play_idle_animation() -> void:
	_play_anim("idle_" + _dir_string(), "idle_down")


func _play_anim(anim_name: String, fallback: String) -> void:
	if anim == null or anim.sprite_frames == null:
		return
	if anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)
	elif anim.sprite_frames.has_animation(fallback):
		anim.play(fallback)


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


func _wait_anim_or_timeout(timeout_sec: float) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while anim != null and anim.is_playing() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _wait_anim_player_or_timeout(timeout_sec: float) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while animP != null and animP.is_playing() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _give_exp_to_player() -> void:
	var p := PlayerManager.get_player_for_local_rewards()
	if p and p.has_method("add_experience"):
		p.add_experience(GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_MAGICAN_EXP_REWARD))


func _on_detector_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true


func _on_detector_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false


func _on_hitbox_area_entered(_area: Area2D) -> void:
	pass


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
	_ensure_attack_animations()
	if get_node_or_null("CollisionShape2D") == null:
		var body_shape := CollisionShape2D.new()
		body_shape.name = "CollisionShape2D"
		var capsule := CapsuleShape2D.new()
		capsule.radius = 10.0
		capsule.height = 28.0
		body_shape.shape = capsule
		add_child(body_shape)
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


func _ensure_attack_animations() -> void:
	if animP == null:
		return
	var library: AnimationLibrary = null
	if animP.has_animation_library(""):
		library = animP.get_animation_library("")
	else:
		library = AnimationLibrary.new()
		animP.add_animation_library("", library)
	for dir: String in ["down", "left", "right", "up"]:
		var anim_name: String = "attack_" + dir
		if animP.has_animation(anim_name):
			continue
		var animation := Animation.new()
		animation.length = 1.1
		var sprite_track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(sprite_track, NodePath("AnimatedSprite2D:animation"))
		animation.track_insert_key(sprite_track, 0.0, anim_name)
		var frame_track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(frame_track, NodePath("AnimatedSprite2D:frame"))
		for i in range(6):
			animation.track_insert_key(frame_track, float(i) * 0.12, i)
		library.add_animation(anim_name, animation)
