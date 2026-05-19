extends CharacterBody2D

# =========================================================
# KNOCKBACK SYSTEM
# =========================================================

var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_decay: float = 15.0
var is_dead: bool = false

# =========================================================
# KNOCKBACK LOGIC
# =========================================================

func apply_knockback(source_position: Vector2, strength: float) -> void:
	if is_dead:
		return

	var knockback_dir = (global_position - source_position).normalized()
	knockback_velocity += knockback_dir * strength


func _apply_knockback_logic(delta: float) -> void:
	if knockback_velocity.length() > 0.1:
		knockback_velocity = knockback_velocity.lerp(
			Vector2.ZERO,
			knockback_decay * delta
		)


func _scene_tree_safe() -> SceneTree:
	if is_inside_tree():
		return get_tree()
	var ml := Engine.get_main_loop()
	return ml as SceneTree if ml is SceneTree else null


## Ожидание кадра без process_frame: узел мог выйти из дерева (queue_free, смена комнаты).
func _await_scene_yield() -> void:
	if not is_instance_valid(self):
		return
	var tree := _scene_tree_safe()
	if tree == null:
		return
	await tree.create_timer(0.0, true, true).timeout


func _await_seconds_safe(sec: float) -> void:
	if not is_instance_valid(self):
		return
	var tree := _scene_tree_safe()
	if tree == null:
		return
	await tree.create_timer(sec, true, true).timeout


func _await_enemy_death_sprite(
	sprite: AnimatedSprite2D,
	anim_name: String,
	fallback_sec: float = 0.75,
	max_wait_sec: float = 3.5
) -> void:
	if not is_instance_valid(sprite):
		await _await_seconds_safe(fallback_sec)
		return
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
		var deadline_ms := Time.get_ticks_msec() + int(max_wait_sec * 1000.0)
		while is_instance_valid(sprite) and sprite.is_playing() and Time.get_ticks_msec() < deadline_ms:
			if not is_instance_valid(self):
				return
			await _await_scene_yield()
			if not is_instance_valid(self) or not is_instance_valid(sprite):
				return
		if is_instance_valid(sprite) and sprite.is_playing():
			sprite.stop()
	else:
		await _await_seconds_safe(fallback_sec)
