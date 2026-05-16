extends Area2D

var direction = Vector2.ZERO
var speed = GameConstants.ARROW_SPEED
var lifetime = 5.0
var stuck = false

func _ready() -> void:
	AudioManager.play_sfx("враг_полет_стрелы")
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self) and not stuck:
		queue_free()

func _process(delta: float) -> void:
	if not stuck and direction != Vector2.ZERO:
		position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if stuck:
		return
	if body.is_in_group("enemys"):
		return
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			NetworkManager.server_apply_damage_to_player_from_enemy(body, GameConstants.ARROW_DAMAGE)
		_stick_and_expire(body)
	else:
		_stick_and_expire()


func _on_area_entered(area: Area2D) -> void:
	if stuck:
		return
	var body: Node = area.get_parent() if area.get_parent() else area
	if body is Node2D:
		_on_body_entered(body)


func _on_body_shape_entered(_body_rid: RID, body: Node2D, _body_shape_index: int, _local_shape_index: int) -> void:
	_on_body_entered(body)


func _stick_and_expire(stick_parent: Node2D = null) -> void:
	stuck = true
	direction = Vector2.ZERO
	speed = 0.0
	monitoring = false
	monitorable = false
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)

	if stick_parent != null and is_instance_valid(stick_parent):
		var saved_global_position := global_position
		var saved_global_rotation := global_rotation
		reparent(stick_parent, true)
		global_position = saved_global_position
		global_rotation = saved_global_rotation

	await get_tree().create_timer(randf_range(5.0, 7.0)).timeout
	if is_instance_valid(self):
		queue_free()
