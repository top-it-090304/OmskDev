extends CharacterBody2D

@export var player_id: int = 1:
	set(value):
		player_id = value
		if has_node("PlayerInput"):
			$PlayerInput.set_multiplayer_authority(value)

@onready var input = $PlayerInput
@export var speed := 200.0
@export var gravity := 980.0 # Для 2D обычно выше

var is_local_player := false

func _ready() -> void:
	add_to_group("player")
	if player_id == multiplayer.get_unique_id():
		$Camera2D.make_current()
		is_local_player = true

func _physics_process(_delta: float) -> void:
	# Движение в 2D Top-down или Roguelike
	var direction = input.direction
	if direction != Vector2.ZERO:
		velocity = direction * speed
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed)
	
	move_and_slide()