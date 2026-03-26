extends Area2D
@export var speed = 200
var damage = 20
var direction = Vector2.ZERO
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _physics_process(_delta: float) -> void:
	position += direction * speed 
	
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") :
		body.take_damage(damage) 
	queue_free()
	
