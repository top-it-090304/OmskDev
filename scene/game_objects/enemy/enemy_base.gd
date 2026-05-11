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
