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
const SUMMON_COUNT := 2
const MAX_MINIONS := 4
const MINION_Z_OFFSET := 1

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
var player_in_swing_zone := false
var player_in_swings_zone := false
var player_in_spawn_zone := false
var active_minions: Array = []

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var animP: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
@onready var hp_bar: TextureProgressBar = $TextureProgressBar
@onready var detector_swing: Area2D = $detector_swing
@onready var detector_swings: Area2D = $detector_swings
@onready var detector_spawn: Area2D = $detector_spawn


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
	if NetworkManager.is_multiplayer_active():
		player_in_swing_zone = PlayerManager.detector_has_living_player(detector_swing)
		player_in_swings_zone = PlayerManager.detector_has_living_player(detector_swings)
		player_in_spawn_zone = PlayerManager.detector_has_living_player(detector_spawn)
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
	if _span_cd <= 0.0 and player_in_spawn_zone:
		_span_cd = SPAN_ATTACK_COOLDOWN
		_attack_cd = ATTACK_COOLDOWN
		attack_span()
		return
	if _attack_cd <= 0.0 and (player_in_swing_zone or dist <= ATTACK_1_RANGE):
		_attack_cd = ATTACK_COOLDOWN
		if (player_in_swings_zone or dist <= MANY_SWING_RANGE) and randf() < 0.55:
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
	_show_attack_warning(Color(0.65, 0.85, 1.0, 0.55), 82.0, 0.28)
	_play_boss_anim("attack_swing_" + _dir_string(), "attack_swing_down")
	if _anim_player_has_current_attack():
		await get_tree().create_timer(0.36).timeout
		activate_strong_swing()
		await _wait_anim_player_or_timeout(0.9)
	else:
		await get_tree().create_timer(0.36).timeout
		activate_strong_swing()
		spawn_swing_wave()
		await _wait_anim_or_timeout(0.65)
	_reset_after_attack()


func attack_swings() -> void:
	if is_dead or is_attacking:
		return
	is_attacking = true
	can_anim = false
	_face_player()
	_show_attack_warning(Color(0.95, 0.95, 1.0, 0.5), 110.0, 0.22)
	_play_boss_anim("attack_swings_" + _dir_string(), "attack_swings_down")
	for _i in range(3):
		if is_dead or not is_instance_valid(player):
			break
		await get_tree().create_timer(0.18).timeout
		dash_many_swing()
		activate_normal_swing()
	velocity = Vector2.ZERO
	if _anim_player_has_current_attack():
		await _wait_anim_player_or_timeout(0.35)
	else:
		await _wait_anim_or_timeout(0.35)
	_reset_after_attack()


func attack_span() -> void:
	if is_dead or is_attacking:
		return
	is_attacking = true
	can_anim = false
	_face_player()
	_show_attack_warning(Color(0.45, 0.75, 1.0, 0.55), 145.0, 0.35)
	_play_boss_anim("attack_spawn_" + _dir_string(), "attack_spawn_down")
	if _anim_player_has_current_attack():
		await _wait_anim_player_or_timeout(1.1)
	else:
		await get_tree().create_timer(0.35).timeout
		spawn_sword_minions()
		spawn_radial_waves()
		await _wait_anim_or_timeout(0.75)
	_reset_after_attack()


func _reset_after_attack() -> void:
	if is_dead:
		return
	is_attacking = false
	can_anim = true
	_play_idle_animation()


func activate_strong_swing() -> void:
	_apply_melee_damage(GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_SKELETON_SWORDMAN_STRONG_DAMAGE), 760.0)


func activate_normal_swing() -> void:
	_apply_melee_damage(GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_SKELETON_SWORDMAN_DAMAGE), 420.0)


func spawn_swing_wave() -> void:
	_spawn_wave_to_player(GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_SKELETON_SWORDMAN_WAVE_DAMAGE))


func dash_many_swing() -> void:
	if is_dead or not is_instance_valid(player):
		return
	var dir := (PlayerManager.get_player_world_pos_for_hosting_ai(player) - global_position).normalized()
	update_run_animation(dir)
	velocity = dir * speed * 3.0
	move_and_slide()


func spawn_sword_minions() -> void:
	_spawn_minions(SUMMON_COUNT)


func spawn_radial_waves() -> void:
	_spawn_waves_8()


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
	_cleanup_minions()
	var can_spawn := MAX_MINIONS - active_minions.size()
	if can_spawn <= 0:
		return
	var to_spawn: int = mini(count, can_spawn)
	AudioManager.play_sfx("босс_суммон")
	var parent := get_parent()
	if parent == null:
		parent = get_tree().current_scene
	for i in range(to_spawn):
		var minion := MINION_SCENE.instantiate()
		parent.add_child(minion)
		if minion is CanvasItem:
			(minion as CanvasItem).z_index = z_index + MINION_Z_OFFSET
		var angle := TAU * float(i) / float(to_spawn)
		minion.global_position = global_position + Vector2(cos(angle), sin(angle)) * 62.0
		active_minions.append(minion)
		var tween := create_tween()
		tween.tween_property(minion, "modulate:a", 0.0, 0.0)
		tween.tween_property(minion, "modulate:a", 1.0, 0.3)


func _cleanup_minions() -> void:
	active_minions = active_minions.filter(func(m): return is_instance_valid(m) and (not ("is_dead" in m) or not m.is_dead))


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
	AudioManager.play_sfx("босс_смерть")
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	if animP != null:
		animP.stop()
	_play_anim("death_" + _dir_string(), "death_down")
	await _wait_anim_or_timeout(1.6)
	_give_exp_to_player()
	if randf() <= 0.75:
		_spawn_loot()
	_spawn_artefact_near_hatch()
	_open_hatch_via_map_manager()
	queue_free()


func _on_hitbox_area_entered(_area: Area2D) -> void:
	pass


func _on_detector_swing_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_swing_zone = true


func _on_detector_swing_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_swing_zone = false


func _on_detector_swings_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_swings_zone = true


func _on_detector_swings_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_swings_zone = false


func _on_detector_spawn_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_spawn_zone = true


func _on_detector_spawn_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_spawn_zone = false


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


func _wait_anim_player_or_timeout(timeout_sec: float) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while animP != null and animP.is_playing() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _play_anim(anim_name: String, fallback: String) -> void:
	if anim.sprite_frames == null:
		return
	if anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)
	elif anim.sprite_frames.has_animation(fallback):
		anim.play(fallback)


func _play_boss_anim(anim_name: String, fallback: String) -> void:
	if animP != null and animP.has_animation(anim_name):
		animP.play(anim_name)
	else:
		_play_anim(anim_name, fallback)


func _anim_player_has_current_attack() -> bool:
	return animP != null and animP.is_playing()


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
	var ps := _pick_boss_artefact_scene()
	if ps == null:
		return
	NetworkManager.server_spawn_boss_loot_for_coop(ps.resource_path, parent_n, spawn_pos)


func _spawn_artefact_fallback() -> void:
	var root := get_tree().current_scene
	var parent_n := root as Node2D
	var ps := _pick_boss_artefact_scene()
	if ps == null:
		return
	if parent_n != null:
		NetworkManager.server_spawn_boss_loot_for_coop(ps.resource_path, parent_n, global_position)


func _pick_boss_artefact_scene() -> PackedScene:
	var scenes := GameConstants.get_random_boss_artefact_scenes(1)
	if scenes.is_empty():
		return null
	return scenes[0]


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
