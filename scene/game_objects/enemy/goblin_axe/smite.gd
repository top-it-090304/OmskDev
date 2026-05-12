extends Area2D
var direction = Vector2.ZERO

func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	if visible:
		_spawn_effect()

func _spawn_effect() -> void:
	# Вспышка — белый круг который быстро исчезает
	var flash = Polygon2D.new()
	var points = PackedVector2Array()
	for i in 16:
		var a = (TAU / 16.0) * i
		points.append(Vector2(cos(a), sin(a)) * 14.0)
	flash.polygon = points
	flash.color = Color(1.0, 0.85, 0.2, 0.9)
	flash.z_index = 10
	add_child(flash)

	# Частицы разлёта (только если включены)
	if GameConstants.show_particles:
		var particles = CPUParticles2D.new()
		particles.emitting = true
		particles.one_shot = true
		particles.explosiveness = 1.0
		particles.amount = 12
		particles.lifetime = 0.35
		particles.initial_velocity_min = 60.0
		particles.initial_velocity_max = 120.0
		particles.scale_amount_min = 3.0
		particles.scale_amount_max = 6.0
		particles.color = Color(1.0, 0.7, 0.1, 1.0)
		particles.gravity = Vector2.ZERO
		particles.z_index = 10
		add_child(particles)

	var tween = create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.2)
	tween.tween_callback(flash.queue_free)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.take_damage(GameConstants.SMITE_DAMAGE)

	
