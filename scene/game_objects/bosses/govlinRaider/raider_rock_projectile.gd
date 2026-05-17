extends Area2D

@export var speed: float = 520.0
@export var lifetime: float = 3.0
@export var damage: int = GameConstants.ENEMY_GOBLIN_RAIDER_ROCK_DAMAGE
@export var knockback: float = 520.0

var direction := Vector2.RIGHT
var _hit := false


func _ready() -> void:
	if direction.length_squared() > 0.0:
		direction = direction.normalized()
		rotation = direction.angle()
	get_tree().create_timer(lifetime).timeout.connect(_on_lifetime_expired)


func _process(delta: float) -> void:
	if direction == Vector2.ZERO:
		return
	global_position += direction * speed * delta
	rotation += 8.0 * delta


func _on_body_entered(body: Node2D) -> void:
	if _hit or body.is_in_group("enemys"):
		return
	_hit = true
	if body.is_in_group("player"):
		NetworkManager.server_apply_damage_to_player_from_enemy(body, damage)
		NetworkManager.server_apply_knockback_to_player_from_enemy(body, global_position, knockback)
	call_deferred("queue_free")


func _on_lifetime_expired() -> void:
	if is_instance_valid(self):
		queue_free()
