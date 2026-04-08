extends Area2D
var direction = Vector2.ZERO


func _process(_delta: float) -> void:
	position += direction * GameConstants.ARROW_SPEED 
	
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") :
		body.take_damage(GameConstants.ARROW_DAMAGE) 
	queue_free()
