extends Area2D
var damage = 20
var direction = Vector2.ZERO
var speed = 1


func _process(_delta: float) -> void:
	position += direction * speed 
	
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") :
		body.take_damage(damage) 
	queue_free()
	
