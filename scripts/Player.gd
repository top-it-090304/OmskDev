extends CharacterBody3D
@export var player := 1:
    set(id):
        player = id
        $PlayerInput.set_multiplayer_authority(id)
@onready var input = $PlayerInput
@export var speed := 5.0
@export var jump_velocity := 4.5
@export var gravity := ProjectSettings.get_setting("physics/3d/default_gravity")
func _ready():
    if player == multiplayer.get_unique_id():
        $Camera3D.current = true
    # Uncomment the next line if you want client‑side prediction:
    # set_physics_process(multiplayer.is_server())
func _physics_process(delta):
    if not is_on_floor():
        velocity.y -= gravity * delta
    if input.jumping and is_on_floor():
        velocity.y = jump_velocity
    input.jumping = false
    var direction = (transform.basis * Vector3(input.direction.x, 0, input.direction.y)).normalized()
    if direction:
        velocity.x = direction.x * speed
        velocity.z = direction.z * speed
    else:
        velocity.x = move_toward(velocity.x, 0, speed)
        velocity.z = move_toward(velocity.z, 0, speed)
    move_and_slide()