extends "res://scene/game_objects/enemy/enemy_base.gd"

const WAVE_SCENE = preload("res://scene/effects/big_wave.tscn")
const ROCK_PROJECTILE_SCENE = preload("res://scene/game_objects/bosses/govlinRaider/raider_rock_projectile.tscn")
const HP_BAR_SCRIPT = preload("res://scene/game_objects/enemy/goblin_axe/texture_progress_bar.gd")

enum Dir { DOWN, UP, LEFT, RIGHT }

var hp := 0
var max_hp := 0
var speed: float = GameConstants.ENEMY_GOBLIN_RAIDER_MAX_SPEED
var current_dir: int = Dir.DOWN
var player: Node2D = null
var parent_node: Node = null
var can_anim := true
var is_attacking := false
var player_in_bite_zone := false
var player_in_wave_zone := false
var player_in_throw_zone := false
var _bite_cd := 0.6
var _wave_cd := 1.2
var _throw_cd := 1.8
var _bite_instance: Area2D = null
var _bite_point_position := Vector2.ZERO

@onready var anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var animP: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
@onready var hp_bar: TextureProgressBar = get_node_or_null("TextureProgressBar") as TextureProgressBar
@onready var detector_bite: Area2D = get_node_or_null("detectorBite") as Area2D
@onready var detector_wave: Area2D = get_node_or_null("detectorWave") as Area2D
@onready var detector_throw: Area2D = get_node_or_null("detectorThrow") as Area2D


func _ready() -> void:
	_ensure_runtime_nodes()
	add_to_group("enemys")
	add_to_group("boss")
	max_hp = GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_GOBLIN_RAIDER_HP)
	hp = max_hp
	speed = GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_GOBLIN_RAIDER_MAX_SPEED)
	if hp_bar != null:
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
	_bite_cd = maxf(0.0, _bite_cd - delta)
	_wave_cd = maxf(0.0, _wave_cd - delta)
	_throw_cd = maxf(0.0, _throw_cd - delta)
	if NetworkManager.is_multiplayer_active():
		player_in_bite_zone = PlayerManager.detector_has_living_player(detector_bite)
		player_in_wave_zone = PlayerManager.detector_has_living_player(detector_wave)
		player_in_throw_zone = PlayerManager.detector_has_living_player(detector_throw)

	var aggressive := parent_node != null and GameConstants.variant_to_bool(parent_node.get("aggression"))
	if not aggressive or not is_instance_valid(player):
		_stop_and_idle()
		return
	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var to_player := PlayerManager.get_player_world_pos_for_hosting_ai(player) - global_position
	var dist := to_player.length()
	var dir := to_player.normalized()
	if not NetworkManager.is_multiplayer_active():
		player_in_bite_zone = dist <= GameConstants.ENEMY_GOBLIN_RAIDER_BITE_RANGE
		player_in_wave_zone = dist <= GameConstants.ENEMY_GOBLIN_RAIDER_WAVE_RANGE
		player_in_throw_zone = dist <= GameConstants.ENEMY_GOBLIN_RAIDER_THROW_RANGE

	if player_in_bite_zone and _bite_cd <= 0.0:
		_bite_cd = GameConstants.ENEMY_GOBLIN_RAIDER_BITE_COOLDOWN
		attack_bite()
		return
	if player_in_wave_zone and _wave_cd <= 0.0:
		_wave_cd = GameConstants.ENEMY_GOBLIN_RAIDER_WAVE_COOLDOWN
		attack_wave()
		return
	if player_in_throw_zone and _throw_cd <= 0.0:
		_throw_cd = GameConstants.ENEMY_GOBLIN_RAIDER_THROW_COOLDOWN
		attack_throw()
		return

	if _all_attacks_on_cooldown():
		velocity = -dir * speed + knockback_velocity
		move_and_slide()
		if can_anim:
			update_run_animation(-dir)
		return

	var target_distance := GameConstants.ENEMY_GOBLIN_RAIDER_TARGET_DISTANCE
	if dist > target_distance + 16.0:
		velocity = dir * speed + knockback_velocity
		move_and_slide()
		if can_anim:
			update_run_animation(dir)
	else:
		_stop_and_idle()


func attack_bite() -> void:
	await _run_attack("attack_byte_" + _dir_string(), "attack_byte_down", Callable(self, "activate_bite"), 28.0, true)


func attack_wave() -> void:
	await _run_attack("attack_wave_" + _dir_string(), "attack_wave_down", Callable(self, "shoot_wave"))


func attack_throw() -> void:
	await _run_attack("attack_throw_" + _dir_string(), "attack_throw_down", Callable(self, "throw_rock"))


func _run_attack(
	anim_name: String,
	fallback: String,
	fallback_call: Callable,
	warning_radius: float = 95.0,
	warning_at_bite_point: bool = false
) -> void:
	if is_dead or is_attacking or not is_instance_valid(player):
		return
	is_attacking = true
	can_anim = false
	_face_player()
	var warning_pos := global_position
	if warning_at_bite_point:
		warning_pos = _get_bite_point()
	_show_attack_warning_at(warning_pos, Color(1.0, 0.55, 0.2, 0.55), warning_radius, 0.28)
	var has_anim_player_attack := animP != null and animP.has_animation(anim_name)
	if has_anim_player_attack:
		animP.play(anim_name)
		await _wait_anim_player_or_timeout(1.4)
	else:
		_play_anim(anim_name, fallback)
		await get_tree().create_timer(0.35).timeout
		fallback_call.call()
		await _wait_anim_or_timeout(0.75)
	_reset_after_attack()


func spawn_bite_swing() -> void:
	if is_dead or not is_instance_valid(player):
		return
	_bite_point_position = _get_bite_point()


func spawn_bite_smite() -> void:
	spawn_bite_swing()


func activate_bite() -> void:
	if is_dead:
		return
	if _bite_point_position == Vector2.ZERO:
		_bite_point_position = _get_bite_point()
	_show_bite_point_visual(_bite_point_position)
	_apply_bite_damage_at(_bite_point_position)
	_bite_point_position = Vector2.ZERO
	AudioManager.play_sfx("босс_атака_укус")


func send_wave() -> void:
	shoot_wave()


func shoot_wave() -> void:
	if NetworkManager.enemy_mp_is_network_client():
		return
	if is_dead or not is_instance_valid(player):
		return
	var dir := _direction_to_player()
	var wave := WAVE_SCENE.instantiate()
	wave.direction = dir
	wave.damage = GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_GOBLIN_RAIDER_WAVE_DAMAGE)
	wave.global_position = global_position + dir * 42.0
	get_tree().current_scene.add_child(wave)
	AudioManager.play_sfx("враг_выстрел_стрела")
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() and mp.is_server():
		NetworkManager.host_mirror_projectile_if_coop(WAVE_SCENE.resource_path, wave.global_position, dir)


func throw_rock() -> void:
	if NetworkManager.enemy_mp_is_network_client():
		return
	if is_dead or not is_instance_valid(player):
		return
	var dir := _direction_to_player()
	var rock := ROCK_PROJECTILE_SCENE.instantiate()
	rock.direction = dir
	rock.damage = GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_GOBLIN_RAIDER_ROCK_DAMAGE)
	rock.rotation = dir.angle()
	get_tree().current_scene.add_child(rock)
	rock.global_position = global_position + dir * 48.0
	AudioManager.play_sfx("враг_полет_стрелы")
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() and mp.is_server():
		NetworkManager.host_mirror_projectile_if_coop(ROCK_PROJECTILE_SCENE.resource_path, rock.global_position, dir)


func throw_stone() -> void:
	throw_rock()


func shoot_rock() -> void:
	throw_rock()


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
	if hp_bar != null:
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
	_spawn_artefact_near_hatch()
	await _await_enemy_death_sprite(anim, anim.animation)
	_give_exp_to_player()
	if randf() <= 0.35:
		_spawn_loot()
	_open_hatch_via_map_manager()
	queue_free()


func _reset_after_attack() -> void:
	if is_instance_valid(_bite_instance):
		_bite_instance.queue_free()
		_bite_instance = null
	if is_dead:
		return
	is_attacking = false
	can_anim = true
	_play_idle_animation()


func _stop_and_idle() -> void:
	velocity = velocity.move_toward(Vector2.ZERO, speed)
	move_and_slide()
	if can_anim and not is_attacking:
		_play_idle_animation()


func _direction_to_player() -> Vector2:
	if not is_instance_valid(player):
		return Vector2.RIGHT
	var dir := PlayerManager.get_player_world_pos_for_hosting_ai(player) - global_position
	if dir.length_squared() <= 0.0:
		return Vector2.RIGHT
	return dir.normalized()


func _get_bite_point() -> Vector2:
	return global_position + _direction_to_player() * 35.0


func _apply_bite_damage_at(pos: Vector2) -> void:
	var space := get_world_2d().direct_space_state
	if space == null:
		return
	var shape := CircleShape2D.new()
	shape.radius = 28.0
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, pos)
	params.collide_with_bodies = true
	params.collide_with_areas = true
	params.collision_mask = 2
	var damaged_players: Array[Node] = []
	for hit in space.intersect_shape(params, 8):
		var collider: Variant = hit.get("collider")
		if collider == null:
			continue
		var hit_node := collider as Node
		var target := hit_node
		if hit_node is Area2D and hit_node.get_parent() != null:
			target = hit_node.get_parent()
		if target == null or not target.is_in_group("player") or damaged_players.has(target):
			continue
		if not PlayerManager.is_player_nearest_hosting_target(global_position, target):
			continue
		var dmg := GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_GOBLIN_RAIDER_BITE_DAMAGE)
		NetworkManager.server_apply_damage_to_player_from_enemy(target, dmg)
		NetworkManager.server_apply_knockback_to_player_from_enemy(target, global_position, 650.0)
		damaged_players.append(target)


func _all_attacks_on_cooldown() -> bool:
	return _bite_cd > 0.0 and _wave_cd > 0.0 and _throw_cd > 0.0


func _face_player() -> void:
	var dir := _direction_to_player()
	if abs(dir.x) > abs(dir.y):
		current_dir = Dir.RIGHT if dir.x > 0.0 else Dir.LEFT
	else:
		current_dir = Dir.DOWN if dir.y > 0.0 else Dir.UP


func _play_idle_animation() -> void:
	_play_anim("idle_" + _dir_string(), "idle_down")


func _show_attack_warning(color: Color, radius: float, duration: float) -> void:
	_show_attack_warning_at(global_position, color, radius, duration)


func _show_attack_warning_at(pos: Vector2, color: Color, radius: float, duration: float) -> void:
	var warning := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(32):
		var angle := TAU * float(i) / 32.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	warning.polygon = points
	warning.color = color
	warning.z_index = z_index + 4
	warning.global_position = pos
	get_tree().current_scene.add_child(warning)
	var tween := warning.create_tween()
	tween.tween_property(warning, "color:a", 0.0, duration)
	tween.tween_callback(warning.queue_free)


func _show_bite_point_visual(pos: Vector2) -> void:
	var bite := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(18):
		var angle := TAU * float(i) / 18.0
		points.append(Vector2(cos(angle), sin(angle)) * 28.0)
	bite.polygon = points
	bite.color = Color(1.0, 0.35, 0.1, 0.65)
	bite.z_index = z_index + 5
	bite.global_position = pos
	get_tree().current_scene.add_child(bite)
	var tween := bite.create_tween()
	tween.tween_property(bite, "color:a", 0.0, 0.16)
	tween.tween_callback(bite.queue_free)


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
		p.add_experience(GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_GOBLIN_RAIDER_EXP_REWARD))


func _spawn_loot() -> void:
	var potion := GameConstants.HEALTH_POTION.instantiate()
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
	var scenes := GameConstants.get_random_boss_artefact_scenes(1)
	if scenes.is_empty():
		return
	var spawn_pos: Vector2 = (hatch as Node2D).global_position + Vector2(0, 48)
	NetworkManager.server_spawn_boss_loot_for_coop(scenes[0].resource_path, parent_n, spawn_pos)


func _spawn_artefact_fallback() -> void:
	var root := get_tree().current_scene
	var parent_n := root as Node2D
	var scenes := GameConstants.get_random_boss_artefact_scenes(1)
	if scenes.is_empty():
		return
	if parent_n != null:
		NetworkManager.server_spawn_boss_loot_for_coop(scenes[0].resource_path, parent_n, global_position)


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


func _on_detector_bite_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_bite_zone = true


func _on_detector_bite_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_bite_zone = false


func _on_detector_wave_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_wave_zone = true


func _on_detector_wave_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_wave_zone = false


func _on_detector_throw_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_throw_zone = true


func _on_detector_throw_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_throw_zone = false


func _ensure_runtime_nodes() -> void:
	if animP == null:
		animP = AnimationPlayer.new()
		animP.name = "AnimationPlayer"
		add_child(animP)
	if hp_bar == null:
		hp_bar = TextureProgressBar.new()
		hp_bar.name = "TextureProgressBar"
		hp_bar.offset_left = -24.0
		hp_bar.offset_top = -54.0
		hp_bar.offset_right = 24.0
		hp_bar.offset_bottom = -48.0
		hp_bar.texture_under = load("res://assets/hpUnderEnemy.png")
		hp_bar.texture_progress = load("res://assets/hpProgressEnemy.png")
		hp_bar.set_script(HP_BAR_SCRIPT)
		add_child(hp_bar)
	if get_node_or_null("CollisionShape2D") == null:
		var shape_node := CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		var capsule := CapsuleShape2D.new()
		capsule.radius = 13.0
		capsule.height = 40.0
		shape_node.shape = capsule
		add_child(shape_node)
	if detector_bite == null:
		detector_bite = _create_detector("detectorBite", 58.0)
	if detector_wave == null:
		detector_wave = _create_detector("detectorWave", 190.0)
	if detector_throw == null:
		detector_throw = _create_detector("detectorThrow", 280.0)


func _create_detector(node_name: String, radius: float) -> Area2D:
	var detector := Area2D.new()
	detector.name = node_name
	detector.collision_layer = 0
	detector.collision_mask = 2
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = radius
	collision.shape = circle
	detector.add_child(collision)
	add_child(detector)
	return detector
