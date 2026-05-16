extends "res://scene/game_objects/enemy/enemy_base.gd"

const WAVE_SCENE = preload("res://scene/game_objects/bosses/skeletonSwordman/skeleton_sword_wave.tscn")
const MINION_SCENE = preload("res://scene/game_objects/enemy/skeleton_grunt/enemy(skeleton_grunt).tscn")
const ARTEFACT_SCENES = [
	preload("res://scene/pick_up/artefacts/old_book.tscn"),
	preload("res://scene/pick_up/artefacts/clock.tscn"),
	preload("res://scene/pick_up/artefacts/crown.tscn"),
	preload("res://scene/pick_up/artefacts/metal_shield.tscn"),
	preload("res://scene/pick_up/artefacts/diamond.tscn")
]

const TARGET_DISTANCE := 120.0
const ATTACK_1_RANGE := 170.0
const MANY_SWING_RANGE := 115.0
const ATTACK_COOLDOWN := 2.4
const SPAN_ATTACK_COOLDOWN := 8.0

enum Dir { DOWN, UP, LEFT, RIGHT }

var hp := 0
var max_hp := 0
var speed := 120.0
var current_dir: int = Dir.DOWN
var player: Node2D = null
var parent_node: Node = null
var is_attacking := false
var can_anim := true
var _attack_cd := 1.0
var _span_cd := 4.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hp_bar: TextureProgressBar = $TextureProgressBar


func _ready() -> void:
	add_to_group("enemys")
	add_to_group("boss")
	max_hp = GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_SKELETON_SWORDMAN_HP)
	hp = max_hp
	speed = GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_SKELETON_SWORDMAN_MAX_SPEED)
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
	_span_cd = maxf(0.0, _span_cd - delta)
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
	if _span_cd <= 0.0:
		_span_cd = SPAN_ATTACK_COOLDOWN
		_attack_cd = ATTACK_COOLDOWN
		attack_span()
		return
	if _attack_cd <= 0.0 and dist <= ATTACK_1_RANGE:
		_attack_cd = ATTACK_COOLDOWN
		if dist <= MANY_SWING_RANGE and randf() < 0.55:
			attack_swings()
		else:
			attack_swing()
		return
	if dist > TARGET_DISTANCE + 16.0:
		velocity = dir * speed + knockback_velocity
		move_and_slide()
		if can_anim:
			update_run_animation(dir)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed)
		move_and_slide()
		if can_anim:
			_play_idle_animation()


func attack_swing() -> void:
	if is_dead or is_attacking:
		return
	is_attacking = true
	can_anim = false
	_face_player()
	_play_anim("attack_swing_" + _dir_string(), "attack_swing_down")
	await get_tree().create_timer(0.36).timeout
	_strong_melee_hit()
	_spawn_wave_to_player(GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_SKELETON_SWORDMAN_WAVE_DAMAGE))
	await _wait_anim_or_timeout(0.65)
	_reset_after_attack()


func attack_swings() -> void:
	if is_dead or is_attacking:
		return
	is_attacking = true
	can_anim = false
	_face_player()
	_play_anim("attack_swings_" + _dir_string(), "attack_swings_down")
	for _i in range(3):
		if is_dead or not is_instance_valid(player):
			break
		var dir := (PlayerManager.get_player_world_pos_for_hosting_ai(player) - global_position).normalized()
		update_run_animation(dir)
		velocity = dir * speed * 3.0
		move_and_slide()
		_normal_melee_hit()
		await get_tree().create_timer(0.18).timeout
	velocity = Vector2.ZERO
	await _wait_anim_or_timeout(0.35)
	_reset_after_attack()


func attack_span() -> void:
	if is_dead or is_attacking:
		return
	is_attacking = true
	can_anim = false
	_face_player()
	_play_anim("attack_spawn_" + _dir_string(), "attack_spawn_down")
	await get_tree().create_timer(0.35).timeout
	_spawn_minions(2)
	_spawn_waves_8()
	await _wait_anim_or_timeout(0.75)
	_reset_after_attack()


func _reset_after_attack() -> void:
	if is_dead:
		return
	is_attacking = false
	can_anim = true
	_play_idle_animation()


func _strong_melee_hit() -> void:
	_apply_melee_damage(GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_SKELETON_SWORDMAN_STRONG_DAMAGE), 760.0)


func _normal_melee_hit() -> void:
	_apply_melee_damage(GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_SKELETON_SWORDMAN_DAMAGE), 420.0)


func _apply_melee_damage(damage: int, knockback: float) -> void:
	for body in get_tree().get_nodes_in_group("player"):
		if not (body is Node2D):
			continue
		if global_position.distance_squared_to((body as Node2D).global_position) > 92.0 * 92.0:
			continue
		if not PlayerManager.is_player_nearest_hosting_target(global_position, body):
			continue
		NetworkManager.server_apply_damage_to_player_from_enemy(body, damage)
		NetworkManager.server_apply_knockback_to_player_from_enemy(body, global_position, knockback)


func _spawn_wave_to_player(damage: int) -> void:
	if not is_instance_valid(player):
		return
	var dir := (PlayerManager.get_player_world_pos_for_hosting_ai(player) - global_position).normalized()
	_spawn_wave(dir, damage)


func _spawn_waves_8() -> void:
	var damage := GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_SKELETON_SWORDMAN_WAVE_DAMAGE)
	for i in range(8):
		var angle := TAU * float(i) / 8.0
		_spawn_wave(Vector2(cos(angle), sin(angle)), damage)


func _spawn_wave(dir: Vector2, damage: int) -> void:
	if dir.length_squared() <= 0.0:
		return
	var wave := WAVE_SCENE.instantiate()
	wave.direction = dir.normalized()
	wave.damage = damage
	wave.global_position = global_position + wave.direction * 34.0
	get_tree().current_scene.add_child(wave)
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() and mp.is_server():
		NetworkManager.host_mirror_projectile_if_coop(WAVE_SCENE.resource_path, wave.global_position, wave.direction)


func _spawn_minions(count: int) -> void:
	var parent := get_parent()
	if parent == null:
		parent = get_tree().current_scene
	for i in range(count):
		var minion := MINION_SCENE.instantiate()
		parent.add_child(minion)
		var angle := TAU * float(i) / float(count)
		minion.global_position = global_position + Vector2(cos(angle), sin(angle)) * 62.0


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
	is_attacking = false
	velocity = Vector2.ZERO
	AudioManager.play_sfx("босс_смерть")
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	_play_anim("death_" + _dir_string(), "death_down")
	await _wait_anim_or_timeout(1.6)
	_give_exp_to_player()
	if randf() <= 0.75:
		_spawn_loot()
	_spawn_artefact_near_hatch()
	_open_hatch_via_map_manager()
	queue_free()


func _on_hitbox_area_entered(_area: Area2D) -> void:
	if is_dead:
		return
	NetworkManager.apply_melee_damage_to_enemy_from_player(self, GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_SKELETON_SWORDMAN_TAKE_DAMAGE))


func update_run_animation(direction: Vector2) -> void:
	if abs(direction.x) > abs(direction.y):
		current_dir = Dir.RIGHT if direction.x > 0.0 else Dir.LEFT
	else:
		current_dir = Dir.DOWN if direction.y > 0.0 else Dir.UP
	_play_anim("walk_" + _dir_string(), "walk_down")


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
	while anim.is_playing() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _play_anim(anim_name: String, fallback: String) -> void:
	if anim.sprite_frames == null:
		return
	if anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)
	elif anim.sprite_frames.has_animation(fallback):
		anim.play(fallback)


func _give_exp_to_player() -> void:
	var p := PlayerManager.get_player_for_local_rewards()
	if p and p.has_method("add_experience"):
		p.add_experience(GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_SKELETON_SWORDMAN_EXP_REWARD))


func _spawn_loot() -> void:
	var potion = GameConstants.HEALTH_POTION.instantiate()
	potion.global_position = global_position
	get_tree().current_scene.add_child(potion)


func _spawn_artefact_near_hatch() -> void:
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
	var ps: PackedScene = ARTEFACT_SCENES[randi() % ARTEFACT_SCENES.size()]
	NetworkManager.server_spawn_boss_loot_for_coop(ps.resource_path, parent_n, spawn_pos)


func _spawn_artefact_fallback() -> void:
	var root := get_tree().current_scene
	var parent_n := root as Node2D
	var ps: PackedScene = ARTEFACT_SCENES[randi() % ARTEFACT_SCENES.size()]
	if parent_n != null:
		NetworkManager.server_spawn_boss_loot_for_coop(ps.resource_path, parent_n, global_position)


func _open_hatch_via_map_manager() -> void:
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
