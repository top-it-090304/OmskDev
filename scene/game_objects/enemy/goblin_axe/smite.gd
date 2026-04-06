extends Area2D
var damage = 10
var direction = Vector2.ZERO
var radius=20
var smite_speed = 2

	
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") :
		body.take_damage(damage) 

	
