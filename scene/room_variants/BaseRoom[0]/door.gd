extends StaticBody2D

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _enemys_node: Node = get_parent().get_node_or_null("Enemys")

var _is_closed := false

func _ready() -> void:
	_update_door_state()

func _process(_delta: float) -> void:
	_update_door_state()

func _update_door_state() -> void:
	var should_close := false
	if _enemys_node:
		should_close = bool(_enemys_node.get("aggression"))

	if should_close == _is_closed:
		return

	_is_closed = should_close
	
	if _is_closed:
		_collision_shape.disabled =false
		_animated_sprite.play("Closed")
	else:
		_collision_shape.disabled =true
		_animated_sprite.play("Opened")
