extends Area2D

var direction = Vector2.ZERO
var speed = 0.0
var lifetime = 5.0

func _ready() -> void:
	speed = GameConstants.POISON_PROJECTILE_SPEED
	lifetime = GameConstants.POISON_DURATION
	
	# Управляем частицами через настройку
	var particles = get_node_or_null("PoisonParticles")
	if particles:
		particles.emitting = GameConstants.show_particles
	
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		queue_free()

func _process(delta: float) -> void:
	if direction != Vector2.ZERO:
		position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemys"):
		return
	if body.is_in_group("player"):
		if body.has_method("apply_poison"):
			AudioManager.play_sfx("враг_яд_попадание")
			NetworkManager.server_apply_poison_to_player_from_enemy(
				body,
				GameConstants.POISON_DURATION,
				GameConstants.POISON_PROJECTILE_DAMAGE,
				GameConstants.POISON_TICK_RATE
			)
	queue_free()
