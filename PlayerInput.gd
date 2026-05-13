extends MultiplayerSynchronizer

@export var jumping := false
@export var direction := Vector2()

func _ready():
	# Only process for the local player.
	set_process(is_multiplayer_authority())

func _process(delta):
	# Reset jump state each frame (we'll set it via RPC when jump button is pressed)
	jumping = false
	
	# Gather input
	direction = Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_down", "ui_up")
	)
	
	# Handle jump with a reliable RPC (we don't want to miss the jump action!)
	if Input.is_action_just_pressed("ui_accept"):
		jump_rpc()

# This RPC will be called on all peers to set the jumping state
@rpc("any_peer", "reliable")
func jump_rpc():
	jumping = true