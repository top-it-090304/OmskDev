extends CharacterBody2D

@export var atack_spawn: Node
@export var gameover: PackedScene
@export var hit_particles: PackedScene

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
var _debug_boost_active := false
var _debug_prev_max_speed := 0.0
var _debug_prev_attack_speed := 0.0

# =========================================================
# СЕТЬ
# =========================================================

var is_local_player: bool = false

var target_position: Vector2 = Vector2.ZERO
var target_direction: int = Dir.DOWN

var interpolation_timer: float = 0.0

const INTERPOLATION_DELAY: float = 0.1

## Синхрон позиции в мультиплеере (раньше — каждый physics-кадр → лаг клиента)
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
func rpc_attack(_from_rpc: bool) -> void:
	if not is_local_player and not is_dead:
		attack(true)

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
			if can_anim and not is_dead:
				play_idle_animation()
		elif global_position.distance_squared_to(target_position) > 64.0 and can_anim and not is_dead:
			var to_t := target_position - global_position
			if to_t.length_squared() > 4.0:
				update_direction(to_t)
				play_walk_animation()
			else:
				play_idle_animation()

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

	# DEBUG BOOST
	if Input.is_action_just_pressed("ui_focus_next"):
		_debug_prev_max_speed = GameConstants.PLAYER_MAX_SPEED
		_debug_prev_attack_speed = GameConstants.PLAYER_ATTACK_SPEED
		_debug_boost_active = true
		GameConstants.PLAYER_MAX_SPEED = 500
		GameConstants.PLAYER_ATTACK_SPEED = 5.0

	if Input.is_action_just_released("ui_focus_next") and _debug_boost_active:
		GameConstants.PLAYER_MAX_SPEED = _debug_prev_max_speed
		GameConstants.PLAYER_ATTACK_SPEED = _debug_prev_attack_speed
		_debug_boost_active = false

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
	# АТАКА ДЖОЙСТИКОМ
	# =====================================================

	if attack_joystick and attack_joystick.is_active:
		var atk_vector = attack_joystick.vector

		if atk_vector != Vector2.ZERO:
			update_direction(atk_vector)

			if can_attack:
				attack()

	# =====================================================
	# ДВИЖЕНИЕ
	# =====================================================

	var direction = movement_vector()

	if direction != Vector2.ZERO:
		velocity = direction * GameConstants.PLAYER_MAX_SPEED

		if not (attack_joystick and attack_joystick.is_active):
			update_direction(direction)

		if can_anim:
			play_walk_animation()

	else:
		velocity = velocity.move_toward(
			Vector2.ZERO,
			GameConstants.PLAYER_MAX_SPEED
		)

		if can_anim:
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

func attack(from_rpc: bool = false) -> void:
	if not can_attack or is_dead:
		return
	if NetworkManager.is_game_online() and NetworkManager.coop_run_finished and is_local_player:
		return

	can_anim = false
	can_attack = false

	animP.speed_scale = GameConstants.PLAYER_ATTACK_SPEED

	match current_dir:
		Dir.UP:
			animP.play("attack_up")

		Dir.DOWN:
			animP.play("attack_down")

		Dir.LEFT:
			animP.play("attack_left")

		Dir.RIGHT:
			animP.play("attack_right")

	AudioManager.play_sfx("игрок_атака")

	await animP.animation_finished

	animP.stop()
	animP.speed_scale = 1.0

	can_anim = true
	if from_rpc:
		if velocity.length_squared() > 100.0:
			play_walk_animation()
		else:
			play_idle_animation()
	else:
		if movement_vector() != Vector2.ZERO:
			play_walk_animation()
		else:
			play_idle_animation()

	attack_timer.start(
		attack_timer.wait_time / GameConstants.PLAYER_ATTACK_SPEED
	)

	# Только онлайн: без peer вызовы is_server()/RPC дают тысячи ошибок в отладчике.
	if NetworkManager.is_game_online() and not from_rpc and is_local_player:
		var mp := get_tree().get_multiplayer()
		if mp.is_server():
			rpc_attack.rpc(true)
		else:
			rpc_attack.rpc_id(NetworkManager.SERVER_ID, true)

@rpc("any_peer", "call_remote", "reliable")
func rpc_server_teleport_to(pos: Vector2) -> void:
	if multiplayer.get_remote_sender_id() != NetworkManager.SERVER_ID:
		return
	global_position = pos
	velocity = Vector2.ZERO
	if is_local_player:
		_last_sent_pos_net = Vector2(NAN, NAN)
		flush_network_transform()


## После телепорта коопа — сразу обновить марионетку на другой машине
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


func take_damage(amount: int):
	if is_dead:
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

	# Неуязвимость не должна блокировать добивающий удар — иначе 0 HP без die() (замирание).
	if not can_take_damage and health_int > final_amount:
		return

	can_take_damage = false

	health_int -= final_amount

	health_changed.emit(
		health_int,
		GameConstants.PLAYER_MAX_HEALTH
	)

	if health_int <= 0:
		die()
		return

	var restore_color = (
		Color(0.3, 1, 0.3, 1)
		if is_poisoned
		else Color(1, 1, 1, 1)
	)

	var tween = create_tween()
	tween.tween_property(anim, "modulate", Color(1, 1, 1, 1), 0.0)
	tween.tween_property(anim, "modulate", restore_color, 0.12)

	AudioManager.play_sfx("игрок_урон")

	if hit_particles:
		var particles = hit_particles.instantiate()
		particles.global_position = global_position
		get_tree().current_scene.add_child(particles)

	damage_timer.start()

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

# =========================================================
# READY
# =========================================================

func _ready() -> void:
	add_to_group("player")
	damage_timer.wait_time = GameConstants.PLAYER_DAMAGE_INVINCIBILITY_SEC

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
		clampi(SaveSystem.saved_player_health, 1, GameConstants.PLAYER_MAX_HEALTH)
		if SaveSystem.should_restore_player
		else GameConstants.PLAYER_MAX_HEALTH
	)

	last_known_max_health = GameConstants.PLAYER_MAX_HEALTH

	if not GameConstants.constants_changed.is_connected(_on_constants_changed):
		GameConstants.constants_changed.connect(_on_constants_changed)

	health_changed.emit(
		health_int,
		GameConstants.PLAYER_MAX_HEALTH
	)

	exp_changed.emit(
		current_exp,
		exp_to_next_level
	)

	if SaveSystem.should_restore_player:
		SaveSystem.restore_player_state()

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

# =========================================================
# MULTIPLAYER UI
# =========================================================

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
	var new_max = GameConstants.PLAYER_MAX_HEALTH

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
		var dmg = GameConstants.PLAYER_ATTACK_DAMAGE
		var is_crit = false
		
		# Крит
		if randf() < GameConstants.PLAYER_CRIT_CHANCE:
			dmg = int(dmg * GameConstants.PLAYER_CRIT_MULTIPLIER)
			is_crit = true

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
	var max_health: int = GameConstants.PLAYER_MAX_HEALTH
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
	return not is_dead and health_int < GameConstants.PLAYER_MAX_HEALTH

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

	last_known_max_health = GameConstants.PLAYER_MAX_HEALTH

	_show_level_up_popup()

	AudioManager.play_sfx("игрок_левелап")

	level_up.emit(current_level)

	health_changed.emit(
		health_int,
		GameConstants.PLAYER_MAX_HEALTH
	)

	exp_changed.emit(
		current_exp,
		exp_to_next_level
	)

	if NetworkManager.is_game_online():
		var snap := GameConstants.capture_coop_start_state()
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
