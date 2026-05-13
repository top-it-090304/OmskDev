extends CharacterBody3D

# Exported player ID, will be set when spawning.
@export var player := 1:
	set(id):
		player = id
		# Give authority over the player input to the appropriate peer.
		$PlayerInput.set_multiplayer_authority(id)

# Player synchronized input.
@onready var input = $PlayerInput

# Movement constants
@export var speed := 5.0
@export var jump_velocity := 4.5
@export var gravity := ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	# Set the camera as current if we are this player.
	if player == multiplayer.get_unique_id():
		$Camera3D.current = true
	# Only process on server. (Uncomment the line below if you want the client to simulate too for latency compensation)
	# set_physics_process(multiplayer.is_server())

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump.
	if input.jumping and is_on_floor():
		velocity.y = jump_velocity

	# Reset jump state (it will be set again by the input synchronizer if needed)
	input.jumping = false

	# Handle movement.
	var direction = (transform.basis * Vector3(input.direction.x, 0, input.direction.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()