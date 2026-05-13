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


func _await_enemy_death_sprite(sprite: AnimatedSprite2D, anim_name: String, fallback_sec: float = 0.75) -> void:
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
		await sprite.animation_finished
	else:
		await get_tree().create_timer(fallback_sec).timeout
