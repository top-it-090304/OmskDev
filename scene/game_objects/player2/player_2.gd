extends CharacterBody2D

@export var atack_spawn: Node
@export var gameover: PackedScene
@export var hit_particles: PackedScene
@export var fireball_scene: PackedScene = preload("res://scene/abilities/fireball.tscn")
@export_range(0.1, 5.0, 0.05) var attack_speed_multiplier: float = 1
@export_range(0.1, 3.0, 0.05) var attack_cooldown: float = 0.5

@onready var attack_joystick = $MobileController/VirtualJoystick2
@onready var anim = $AnimatedSprite2D
@onready var damage_timer = $can_take_damage
@onready var attack_timer = $can_attack
@onready var animP = $AnimationPlayer

const LEVEL_UP_POPUP = preload("res://scene/ui/level_up_popup.tscn")
const DAMAGE_POPUP = preload("res://scene/ui/damage_popup.tscn")
const DEFAULT_GAME_OVER = preload("res://World/UI/game_over.tscn")

# =========================================================
# ОСНОВНЫЕ ПЕРЕМЕННЫЕ
# =========================================================

var health_int = 0
var can_take_damage = true

# Отравление
var is_poisoned = false
var poison_timer = 0.0
var poison_tick_timer = 0.0
var poison_damage_per_tick = 0
var poison_tick_rate = 0.5

# Уровни
var current_level = 1
var current_exp = 0
var exp_to_next_level = 100

enum Dir {
	DOWN,
	UP,
	LEFT,
	RIGHT
}

var current_dir: int = Dir.DOWN

var can_move = true
var can_anim = true
var can_attack = true
var is_dead = false

var last_known_max_health = 0
var _shot_direction := Vector2.DOWN
var _last_shot_msec: int = 0
var _hurt_anim_token: int = 0

# =========================================================
# СЕТЬ
# =========================================================

var is_local_player: bool = false

var target_position: Vector2 = Vector2.ZERO
var target_direction: int = Dir.DOWN

var interpolation_timer: float = 0.0

const INTERPOLATION_DELAY: float = 0.1

const POS_SYNC_MIN_INTERVAL_SEC := 1.0 / 22.0
const POS_SYNC_MIN_DIST_SQ := 2.25

var _pos_sync_accum: float = 0.0
var _last_sent_pos_net: Vector2 = Vector2(NAN, NAN)
var _last_sent_dir_net: int = -9999

# =========================================================
# SIGNALS
# =========================================================

signal health_changed(new_health, max_health)
signal exp_changed(current_exp, exp_needed)
signal level_up(new_level)

# =========================================================
# RPC
# =========================================================

@rpc("authority", "call_remote", "unreliable_ordered")
func rpc_set_position(pos: Vector2, dir: int) -> void:
	target_position = pos
	target_direction = dir
	interpolation_timer = 0.0
	if not is_multiplayer_authority():
		set_meta(&"net_target_valid", true)
	if is_local_player:
		return
	var dist2 := global_position.distance_squared_to(pos)
	if dist2 > 1225.0:
		global_position = pos
	current_dir = dir
	if can_anim and not is_dead and dist2 > 1225.0:
		play_idle_animation()

@rpc("authority", "call_local")
func rpc_take_damage(amount: int) -> void:
	if not is_local_player and not is_dead:
		take_damage(amount)


@rpc("any_peer", "call_remote", "reliable")
func rpc_take_damage_from_server(amount: int) -> void:
	if is_multiplayer_authority():
		take_damage(amount)


@rpc("any_peer", "call_remote", "reliable")
func rpc_apply_poison_from_server(duration: float, damage_per_tick: int, tick_rate: float) -> void:
	if is_multiplayer_authority():
		apply_poison(duration, damage_per_tick, tick_rate)


@rpc("any_peer", "call_remote", "reliable")
func rpc_apply_knockback_from_server(source_x: float, source_y: float, force: float) -> void:
	if is_multiplayer_authority():
		apply_knockback(Vector2(source_x, source_y), force)


@rpc("authority", "call_local")
func rpc_die() -> void:
	if not is_local_player:
		die()

@rpc("authority", "call_local")
func rpc_heal(amount: int) -> void:
	if not is_local_player:
		heal(amount)

@rpc("authority", "call_local")
func rpc_attack(_from_rpc: bool, shot_direction: Vector2 = Vector2.ZERO) -> void:
	if not is_local_player and not is_dead:
		attack(true, shot_direction)

# =========================================================
# PHYSICS
# =========================================================

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if NetworkManager.is_game_online() and NetworkManager.coop_run_finished and is_local_player:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if is_local_player:
		move_and_slide()

		if NetworkManager.is_game_online():
			_pos_sync_accum += delta
			if _pos_sync_accum >= POS_SYNC_MIN_INTERVAL_SEC:
				_pos_sync_accum = 0.0
				var pos_d2 := global_position.distance_squared_to(_last_sent_pos_net)
				var dir_changed := current_dir != _last_sent_dir_net
				if dir_changed or pos_d2 >= POS_SYNC_MIN_DIST_SQ or is_nan(_last_sent_pos_net.x):
					_last_sent_pos_net = global_position
					_last_sent_dir_net = current_dir
					rpc_set_position.rpc(global_position, current_dir)

	else:
		# Интерполяция удаленных игроков
		interpolation_timer += delta

		var t = clamp(
			interpolation_timer / INTERPOLATION_DELAY,
			0.0,
			1.0
		)

		global_position = global_position.lerp(
			target_position,
			t
		)

		if target_direction != current_dir:
			current_dir = target_direction
			velocity = Vector2.ZERO
			move_and_slide()

# =========================================================
# PROCESS
# =========================================================

func _process(delta: float) -> void:
	if is_dead:
		return

	if NetworkManager.is_game_online() and NetworkManager.coop_run_finished:
		return

	if not is_local_player:
		return

	# =====================================================
	# ЯД
	# =====================================================

	if is_poisoned:
		poison_timer -= delta
		poison_tick_timer -= delta

		if poison_tick_timer <= 0:
			take_damage(poison_damage_per_tick)
			poison_tick_timer = poison_tick_rate

		if poison_timer <= 0:
			remove_poison()

	# =====================================================
	# АТАКА (клавиатура / мышь)
	# =====================================================

	if Input.is_action_just_pressed("attack_down"):
		current_dir = Dir.DOWN
		if can_attack:
			attack()
	elif Input.is_action_just_pressed("attack_up"):
		current_dir = Dir.UP
		if can_attack:
			attack()
	elif Input.is_action_just_pressed("attack_left"):
		current_dir = Dir.LEFT
		if can_attack:
			attack()
	elif Input.is_action_just_pressed("attack_right"):
		current_dir = Dir.RIGHT
		if can_attack:
			attack()
	elif Input.is_action_just_pressed("attack") and can_attack:
		attack()

	# =====================================================
	# АТАКА ДЖОЙСТИКОМ
	# =====================================================

	if attack_joystick and attack_joystick.is_active:
		var atk_vector = attack_joystick.vector

		if atk_vector != Vector2.ZERO:
			update_direction(atk_vector)

			if can_attack:
				attack()

	# =====================================================
	# ДВИЖЕНИЕ (во время каста тоже можно ходить)
	# =====================================================

	var direction = movement_vector()

	if direction != Vector2.ZERO:
		velocity = direction * GameConstants.PLAYER_MAX_SPEED

		if not (attack_joystick and attack_joystick.is_active):
			update_direction(direction)

		if can_anim and not _is_attack_anim_playing():
			play_walk_animation()

	else:
		velocity = velocity.move_toward(
			Vector2.ZERO,
			GameConstants.PLAYER_MAX_SPEED
		)

		if can_anim and not _is_attack_anim_playing():
			play_idle_animation()

# =========================================================
# MOVEMENT
# =========================================================

func movement_vector() -> Vector2:
	return Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	).normalized()


func update_direction(dir_vec: Vector2):
	if not can_anim:
		return

	if abs(dir_vec.x) > abs(dir_vec.y):
		current_dir = Dir.LEFT if dir_vec.x < 0 else Dir.RIGHT
	else:
		current_dir = Dir.UP if dir_vec.y < 0 else Dir.DOWN


func play_walk_animation():
	match current_dir:
		Dir.UP:
			anim.play("walk_up")

		Dir.DOWN:
			anim.play("walk_down")

		Dir.LEFT:
			anim.play("walk_left")

		Dir.RIGHT:
			anim.play("walk_right")


func play_idle_animation():
	match current_dir:
		Dir.UP:
			anim.play("idle_up")

		Dir.DOWN:
			anim.play("idle_down")

		Dir.LEFT:
			anim.play("idle_left")

		Dir.RIGHT:
			anim.play("idle_right")

# =========================================================
# ATTACK
# =========================================================

func attack(from_rpc: bool = false, shot_direction: Vector2 = Vector2.ZERO) -> void:
	if not can_attack or is_dead:
		return
	if NetworkManager.is_game_online() and NetworkManager.coop_run_finished and is_local_player:
		return

	_shot_direction = shot_direction.normalized() if shot_direction.length_squared() > 0.01 else _get_attack_direction()
	_force_direction(_shot_direction)

	can_attack = false
	var effective_attack_speed := _get_effective_attack_speed()
	attack_timer.start(attack_cooldown)

	animP.speed_scale = effective_attack_speed
	var attack_anim_name := "attack_down"
	match current_dir:
		Dir.UP:
			attack_anim_name = "attack_up"
		Dir.DOWN:
			attack_anim_name = "attack_down"
		Dir.LEFT:
			attack_anim_name = "attack_left"
		Dir.RIGHT:
			attack_anim_name = "attack_right"

	animP.play(attack_anim_name)
	if not _animation_calls_method(attack_anim_name, "shoot"):
		shoot()

	if NetworkManager.is_game_online() and not from_rpc and is_local_player:
		var mp := get_tree().get_multiplayer()
		if mp.is_server():
			rpc_attack.rpc(true, _shot_direction)
		else:
			rpc_attack.rpc_id(NetworkManager.SERVER_ID, true, _shot_direction)


func _get_effective_attack_speed() -> float:
	return maxf(0.1, attack_speed_multiplier)


func _force_direction(dir_vec: Vector2) -> void:
	if dir_vec.length_squared() <= 0.01:
		return
	if abs(dir_vec.x) > abs(dir_vec.y):
		current_dir = Dir.LEFT if dir_vec.x < 0.0 else Dir.RIGHT
	else:
		current_dir = Dir.UP if dir_vec.y < 0.0 else Dir.DOWN


func _is_attack_anim_playing() -> bool:
	if not animP.is_playing():
		return false
	var anim_name: StringName = animP.current_animation
	return str(anim_name).begins_with("attack_")


func _animation_calls_method(anim_name: String, method_name: String) -> bool:
	if animP == null or not animP.has_animation(anim_name):
		return false
	var animation: Animation = animP.get_animation(anim_name)
	for track_idx in range(animation.get_track_count()):
		if animation.track_get_type(track_idx) != Animation.TYPE_METHOD:
			continue
		for key_idx in range(animation.track_get_key_count(track_idx)):
			var key_value: Variant = animation.track_get_key_value(track_idx, key_idx)
			if key_value is Dictionary and str(key_value.get("method", "")) == method_name:
				return true
	return false


## Как у Knight: урон + крит для файрбола.
func roll_attack_damage() -> Dictionary:
	var dmg = GameConstants.get_player2_attack_damage()
	var is_crit = randf() < GameConstants.PLAYER_CRIT_CHANCE
	if is_crit:
		dmg = int(dmg * GameConstants.PLAYER_CRIT_MULTIPLIER)
	return {"damage": dmg, "is_crit": is_crit}


## Вызывается из attack() и из AnimationPlayer (не чаще одного раза за выстрел).
func shoot() -> void:
	if is_dead:
		return
	if NetworkManager.is_game_online() and is_local_player:
		var mp := get_tree().get_multiplayer()
		if mp.has_multiplayer_peer() and not mp.is_server():
			return
	var now := Time.get_ticks_msec()
	if now - _last_shot_msec < 100:
		return
	_last_shot_msec = now
	_spawn_fireball(_shot_direction)


func _get_attack_direction() -> Vector2:
	if attack_joystick and attack_joystick.is_active:
		var v: Vector2 = attack_joystick.vector
		if v.length_squared() > 0.01:
			return v.normalized()
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length_squared() > 64.0:
		return to_mouse.normalized()
	match current_dir:
		Dir.UP:
			return Vector2.UP
		Dir.DOWN:
			return Vector2.DOWN
		Dir.LEFT:
			return Vector2.LEFT
		Dir.RIGHT:
			return Vector2.RIGHT
	return Vector2.DOWN


func _get_projectile_parent() -> Node:
	var layer := get_tree().root.get_node_or_null("Layer")
	if layer != null:
		return layer
	var mm := get_tree().get_first_node_in_group("map_manager")
	if mm != null and mm.get_parent() != null:
		return mm.get_parent()
	return get_tree().current_scene


func _spawn_fireball(dir_vec: Vector2) -> void:
	if dir_vec.length_squared() < 0.01 or fireball_scene == null:
		return
	if not is_inside_tree():
		return
	var norm_dir := dir_vec.normalized()
	var spawn_pos := global_position + norm_dir * 22.0
	var fireball := fireball_scene.instantiate()
	fireball.shooter = self
	fireball.direction = norm_dir
	fireball.rotation = norm_dir.angle()
	var world := _get_projectile_parent()
	if world == null:
		world = get_parent()
	if world == null:
		return
	world.add_child(fireball)
	fireball.global_position = spawn_pos
	AudioManager.play_sfx("огненный_выстрел")
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() and mp.is_server():
		NetworkManager.host_mirror_projectile_if_coop(
			fireball_scene.resource_path,
			spawn_pos,
			norm_dir
		)


@rpc("any_peer", "call_remote", "reliable")
func rpc_server_teleport_to(pos: Vector2) -> void:
	if multiplayer.get_remote_sender_id() != NetworkManager.SERVER_ID:
		return
	global_position = pos
	velocity = Vector2.ZERO
	if is_local_player:
		_last_sent_pos_net = Vector2(NAN, NAN)
		flush_network_transform()


func flush_network_transform() -> void:
	if not is_local_player:
		return
	if NetworkManager.is_game_offline():
		return
	_last_sent_pos_net = global_position
	_last_sent_dir_net = current_dir
	rpc_set_position.rpc(global_position, current_dir)

# =========================================================
# DAMAGE
# =========================================================

func apply_knockback(source_position: Vector2, force: float):
	if is_dead:
		return

	var knockback_dir = (
		global_position - source_position
	).normalized()

	velocity = knockback_dir * force


func _is_cheat_god_mode() -> bool:
	return CheatPanel.is_god_mode_active()


func take_damage(amount: int):
	if is_dead:
		return

	if _is_cheat_god_mode():
		return

	if NetworkManager.is_game_online() and NetworkManager.coop_run_finished:
		return

	# Уклонение
	if randf() < GameConstants.PLAYER_DODGE_CHANCE:
		_show_popup("dodge")
		return

	var final_amount = max(
		1,
		amount - GameConstants.PLAYER_ARMOR
	)

	if not can_take_damage and health_int > final_amount:
		return

	can_take_damage = false

	health_int -= final_amount

	health_changed.emit(
		health_int,
		_get_max_health()
	)

	if health_int <= 0:
		die()
		return

	play_hurt_animation()

	var restore_color = (
		Color(0.3, 1, 0.3, 1)
		if is_poisoned
		else Color(1, 1, 1, 1)
	)

	var tween = create_tween()
	tween.tween_property(anim, "modulate", Color(1, 1, 1, 1), 0.0)
	tween.tween_property(anim, "modulate", restore_color, 0.1)

	AudioManager.play_sfx("игрок_урон")

	if hit_particles:
		var particles = hit_particles.instantiate()
		particles.global_position = global_position
		get_tree().current_scene.add_child(particles)

	damage_timer.start()


func play_hurt_animation() -> void:
	if is_dead or animP == null:
		return
	_hurt_anim_token += 1
	var token := _hurt_anim_token
	can_anim = false
	animP.stop()
	animP.speed_scale = _get_hurt_anim_speed_scale()
	var hurt_anim_name := "hurt_down"
	match current_dir:
		Dir.UP:
			hurt_anim_name = "hurt_up"
		Dir.DOWN:
			hurt_anim_name = "hurt_down"
		Dir.LEFT:
			hurt_anim_name = "hurt_left"
		Dir.RIGHT:
			hurt_anim_name = "hurt_right"
	animP.play(hurt_anim_name)
	await get_tree().create_timer(0.15).timeout
	if token != _hurt_anim_token or is_dead:
		return
	var interrupted_by_attack := _is_attack_anim_playing()
	if not interrupted_by_attack:
		animP.stop()
		animP.speed_scale = 1.0
	can_anim = true
	if interrupted_by_attack:
		return
	if movement_vector() != Vector2.ZERO:
		play_walk_animation()
	else:
		play_idle_animation()


func _get_hurt_anim_speed_scale() -> float:
	var hurt_anim_name := "hurt_down"
	match current_dir:
		Dir.UP:
			hurt_anim_name = "hurt_up"
		Dir.DOWN:
			hurt_anim_name = "hurt_down"
		Dir.LEFT:
			hurt_anim_name = "hurt_left"
		Dir.RIGHT:
			hurt_anim_name = "hurt_right"
	if animP.has_animation(hurt_anim_name):
		var length: float = animP.get_animation(hurt_anim_name).length
		if length > 0.0:
			return maxf(1.0, length / 0.15)
	return 1.0


func _is_hurt_anim_playing() -> bool:
	if not animP.is_playing():
		return false
	return str(animP.current_animation).begins_with("hurt_")

# =========================================================
# DEATH
# =========================================================

func die_from_coop_partner_death() -> void:
	if is_dead:
		return
	if NetworkManager.is_game_offline():
		return
	if not is_local_player:
		return
	is_dead = true
	can_anim = false
	velocity = Vector2.ZERO
	NetworkManager.mark_coop_run_finished()
	await _death_presentation_async()


func die():
	if is_dead:
		return

	is_dead = true
	can_anim = false
	velocity = Vector2.ZERO

	var mp := get_tree().get_multiplayer()
	if NetworkManager.is_game_online() and is_local_player:
		if not NetworkManager.coop_run_finished:
			if mp.is_server():
				NetworkManager.server_broadcast_coop_game_over(get_multiplayer_authority())
			else:
				NetworkManager.rpc_report_player_death.rpc_id(NetworkManager.SERVER_ID)
		NetworkManager.mark_coop_run_finished()

	await _death_presentation_async()


func _death_presentation_async() -> void:
	AudioManager.play_sfx("игрок_смерть")

	if animP:
		animP.active = false
		animP.stop(true)

	var death_anim := "death_down"
	match current_dir:
		Dir.UP:
			death_anim = "death_up"
		Dir.DOWN:
			death_anim = "death_down"
		Dir.LEFT:
			death_anim = "death_left"
		Dir.RIGHT:
			death_anim = "death_right"
	await _await_player_death_sprite(death_anim)

	SaveSystem.invalidate_run_after_death()

	var gameover_scene := gameover if gameover != null else DEFAULT_GAME_OVER
	var over = gameover_scene.instantiate()
	add_child(over)


func _await_player_death_sprite(anim_name: String, fallback_sec: float = 1.0, max_wait_sec: float = 3.5) -> void:
	if anim.sprite_frames != null and anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)
		var deadline_ms := Time.get_ticks_msec() + int(max_wait_sec * 1000.0)
		while anim.is_playing() and Time.get_ticks_msec() < deadline_ms:
			await get_tree().process_frame
		if anim.is_playing():
			anim.stop()
	else:
		await get_tree().create_timer(fallback_sec).timeout

# =========================================================
# HITBOX
# =========================================================

func _on_hitbox_body_entered(body: Node2D) -> void:
	if is_dead:
		return

	if body.is_in_group("enemys"):
		take_damage(GameConstants.PLAYER_ENEMY_CONTACT_DAMAGE)


func _on_can_take_damage_timeout() -> void:
	can_take_damage = true


func _on_can_attack_timeout() -> void:
	can_attack = true


func _get_max_health() -> int:
	return GameConstants.get_player2_max_health()

# =========================================================
# READY
# =========================================================

func _ready() -> void:
	add_to_group("player")
	damage_timer.wait_time = GameConstants.PLAYER_DAMAGE_INVINCIBILITY_SEC
	attack_timer.one_shot = true
	attack_timer.wait_time = attack_cooldown

	if NetworkManager.is_game_offline():
		is_local_player = true
	else:
		is_local_player = is_multiplayer_authority()

	current_level = GameConstants.PLAYER_LEVEL
	current_exp = GameConstants.PLAYER_EXPERIENCE

	exp_to_next_level = _calculate_exp_for_level(
		current_level + 1
	)

	health_int = (
		clampi(SaveSystem.saved_player_health, 1, _get_max_health())
		if SaveSystem.should_restore_player
		else _get_max_health()
	)

	last_known_max_health = _get_max_health()

	if not GameConstants.constants_changed.is_connected(_on_constants_changed):
		GameConstants.constants_changed.connect(_on_constants_changed)

	health_changed.emit(
		health_int,
		_get_max_health()
	)

	exp_changed.emit(
		current_exp,
		exp_to_next_level
	)

	if SaveSystem.should_restore_player:
		SaveSystem.restore_player_state()

	if has_node("hitbox_attack/CollisionShape2D"):
		$hitbox_attack/CollisionShape2D.set_deferred("disabled", true)

	if not is_local_player:
		if attack_joystick:
			attack_joystick.set_process(false)
		_hide_ui_for_remote_peer()
	else:
		add_to_group("local_player")
		if has_node("Camera2D"):
			var cam := $Camera2D as Camera2D
			cam.enabled = true
			cam.make_current()
		anim.play("idle_down")


func _hide_ui_for_remote_peer() -> void:
	if has_node("Camera2D"):
		var cam := $Camera2D as Camera2D
		cam.enabled = false
		cam.visible = false

	for node_name in [
		"TextureProgressBar",
		"TextureButton",
		"InventoryButton",
		"LevelUpPopup",
	]:
		if has_node(node_name):
			var n := get_node(node_name)
			n.visible = false
			n.process_mode = Node.PROCESS_MODE_DISABLED

	var mc := get_node_or_null("MobileController") as CanvasLayer
	if mc:
		mc.visible = false
		for c in mc.get_children():
			if c is Control:
				(c as Control).visible = false
				(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
				(c as Control).process_mode = Node.PROCESS_MODE_DISABLED

# =========================================================
# CONSTANTS UPDATE
# =========================================================

func _on_constants_changed() -> void:
	var new_max = _get_max_health()

	if health_int > new_max:
		health_int = new_max

	last_known_max_health = new_max

	health_changed.emit(health_int, new_max)

# =========================================================
# ATTACK HITBOX
# =========================================================

func _on_hitbox_attack_body_entered(body: Node2D) -> void:
	if is_dead:
		return

	if body.is_in_group("enemys"):
		var roll := roll_attack_damage()
		var dmg: int = roll.get("damage", GameConstants.get_player2_attack_damage())
		var is_crit: bool = roll.get("is_crit", false)

		NetworkManager.apply_melee_damage_to_enemy_from_player(body, dmg)
		
		# Показываем урон над врагом
		if GameConstants.SHOW_DAMAGE_NUMBERS:
			_show_popup_at("damage" if not is_crit else "crit", dmg, body.global_position)
		
		if hit_particles:
			var particles = hit_particles.instantiate()
			particles.global_position = body.global_position
			get_tree().current_scene.add_child(particles)

		# Вампиризм
		if GameConstants.PLAYER_LIFESTEAL > 0.0:
			var steal = int(dmg * GameConstants.PLAYER_LIFESTEAL)
			if steal > 0:
				heal(steal)

# =========================================================
# HEAL
# =========================================================

func heal(amount: int) -> void:
	if amount <= 0:
		return
	var max_health: int = _get_max_health()
	var old_health: int = health_int
	health_int = mini(health_int + amount, max_health)
	var healed: int = health_int - old_health
	if healed <= 0:
		return

	health_changed.emit(
		health_int,
		max_health
	)
	
	# Показываем хил
	if GameConstants.SHOW_HEAL_NUMBERS:
		_show_popup("heal", healed)


func can_heal() -> bool:
	return not is_dead and health_int < _get_max_health()

# =========================================================
# EXPERIENCE
# =========================================================

func add_experience(amount: int) -> void:
	if NetworkManager.is_game_online() and not is_local_player:
		return

	var multiplier = 1.0

	if "PLAYER_EXP_MULTIPLIER_BONUS" in GameConstants:
		multiplier = GameConstants.PLAYER_EXP_MULTIPLIER_BONUS

	var final_amount = int(amount * multiplier)

	current_exp += final_amount

	GameConstants.PLAYER_EXPERIENCE = current_exp

	exp_changed.emit(current_exp, exp_to_next_level)

	while current_exp >= exp_to_next_level:
		level_up_player()


func _calculate_exp_for_level(level: int) -> int:
	return int(
		GameConstants.PLAYER_BASE_EXP_TO_LEVEL
		* pow(
			GameConstants.PLAYER_EXP_MULTIPLIER,
			level - 1
		)
	)

# =========================================================
# LEVEL UP
# =========================================================

func level_up_player() -> void:
	if NetworkManager.is_game_online() and not is_local_player:
		return

	current_level += 1

	GameConstants.PLAYER_LEVEL = current_level

	current_exp -= exp_to_next_level

	exp_to_next_level = _calculate_exp_for_level(
		current_level + 1
	)

	GameConstants.PLAYER_MAX_HEALTH = min(
		GameConstants.PLAYER_MAX_HEALTH
		+ GameConstants.PLAYER_HEALTH_PER_LEVEL,
		9999
	)

	GameConstants.PLAYER_MAX_SPEED = min(
		GameConstants.PLAYER_MAX_SPEED
		+ GameConstants.PLAYER_SPEED_PER_LEVEL,
		600
	)

	GameConstants.PLAYER_ATTACK_DAMAGE = min(
		GameConstants.PLAYER_ATTACK_DAMAGE
		+ GameConstants.PLAYER_DAMAGE_PER_LEVEL,
		999
	)

	last_known_max_health = _get_max_health()

	_show_level_up_popup()

	AudioManager.play_sfx("игрок_левелап")

	level_up.emit(current_level)

	health_changed.emit(
		health_int,
		_get_max_health()
	)

	exp_changed.emit(
		current_exp,
		exp_to_next_level
	)

	if NetworkManager.is_game_online():
		var snap := GameConstants.capture_coop_shared_state()
		var mp := get_tree().get_multiplayer()
		if mp.is_server():
			NetworkManager.rpc_replicate_player_stats.rpc(snap)
		else:
			NetworkManager.rpc_submit_progress_after_level_up.rpc_id(NetworkManager.SERVER_ID, snap)

# =========================================================
# POPUP
# =========================================================

func _show_level_up_popup():
	var popup = LEVEL_UP_POPUP.instantiate()
	popup.global_position = global_position + Vector2(0, -50)
	get_tree().current_scene.add_child(popup)

func _show_popup(type: String, value: int = 0) -> void:
	_show_popup_at(type, value, global_position)

func _show_popup_at(type: String, value: int, pos: Vector2) -> void:
	var popup = DAMAGE_POPUP.instantiate()
	popup.global_position = pos + Vector2(randf_range(-5, 5), randf_range(-5, 5))
	get_tree().current_scene.add_child(popup)
	
	match type:
		"damage":
			popup.setup(0, value)  # Type.DAMAGE = 0
		"heal":
			popup.setup(1, value)  # Type.HEAL = 1
		"dodge":
			popup.setup(2, 0)      # Type.DODGE = 2
		"crit":
			popup.setup(3, value)  # Type.CRIT = 3

# =========================================================
# POISON
# =========================================================

func apply_poison(
	duration: float,
	damage_per_tick: int,
	tick_rate: float
):
	if is_poisoned:
		poison_timer = max(poison_timer, duration)

	else:
		is_poisoned = true

		poison_timer = duration
		poison_tick_timer = tick_rate
		poison_damage_per_tick = damage_per_tick
		poison_tick_rate = tick_rate

		anim.modulate = Color(0.3, 1, 0.3, 1)


func remove_poison():
	is_poisoned = false

	poison_timer = 0.0
	poison_tick_timer = 0.0

	var tween = create_tween()

	tween.tween_property(
		anim,
		"modulate",
		Color(1, 1, 1, 1),
		0.3
	)
