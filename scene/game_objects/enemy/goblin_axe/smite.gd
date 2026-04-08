extends Area2D
var direction = Vector2.ZERO

	
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") :
		body.take_damage(GameConstants.SMITE_DAMAGE) 

	
