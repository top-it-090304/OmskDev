extends Area2D

var direction = Vector2.ZERO
var speed = GameConstants.ARROW_SPEED
var lifetime = 5.0

func _ready() -> void:
	AudioManager.play_sfx("враг_полет_стрелы")
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
		if body.has_method("take_damage"):
			body.take_damage(GameConstants.ARROW_DAMAGE)
	queue_free()
