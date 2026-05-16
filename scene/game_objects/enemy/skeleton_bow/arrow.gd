extends Area2D

var direction = Vector2.ZERO
var speed = GameConstants.ARROW_SPEED
var lifetime = 5.0
var stuck = false

var _stick_scheduled := false


func _ready() -> void:
	AudioManager.play_sfx("враг_полет_стрелы")
	get_tree().create_timer(lifetime).timeout.connect(_on_lifetime_expired)


func _on_lifetime_expired() -> void:
	if is_instance_valid(self) and not stuck:
		queue_free()


func _process(delta: float) -> void:
	if not stuck and direction != Vector2.ZERO:
		position += direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	_schedule_stick(body)


func _schedule_stick(body: Node2D) -> void:
	if stuck or _stick_scheduled:
		return
	if body.is_in_group("enemys"):
		return

	_stick_scheduled = true
	var stick_parent: Node2D = null
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			NetworkManager.server_apply_damage_to_player_from_enemy(
				body, GameConstants.get_scaled_enemy_stat(GameConstants.ARROW_DAMAGE)
			)
		stick_parent = body
	call_deferred("_begin_stick", stick_parent)


func _begin_stick(stick_parent: Node2D) -> void:
	if not is_instance_valid(self) or stuck:
		return

	stuck = true
	direction = Vector2.ZERO
	speed = 0.0
	monitoring = false
	monitorable = false
	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = true

	if stick_parent != null and is_instance_valid(stick_parent):
		var saved_global_position := global_position
		var saved_global_rotation := global_rotation
		reparent(stick_parent, true)
		global_position = saved_global_position
		global_rotation = saved_global_rotation

	get_tree().create_timer(randf_range(5.0, 7.0)).timeout.connect(_on_stick_ttl_expired)


func _on_stick_ttl_expired() -> void:
	if is_instance_valid(self):
		queue_free()
