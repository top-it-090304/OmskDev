extends Area2D

@export var speed: float = 360.0
@export var max_distance: float = 520.0
@export var damage: int = 35

var direction := Vector2.RIGHT
var _distance_traveled := 0.0


func _ready() -> void:
	if direction.length_squared() > 0.0:
		direction = direction.normalized()
		rotation = direction.angle()


func _process(delta: float) -> void:
	if direction == Vector2.ZERO:
		return
	var step := speed * delta
	global_position += direction * step
	_distance_traveled += step
	if _distance_traveled >= max_distance:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("take_damage"):
		NetworkManager.server_apply_damage_to_player_from_enemy(body, damage)
	call_deferred("queue_free")
