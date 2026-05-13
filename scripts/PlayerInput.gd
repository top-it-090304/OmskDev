extends MultiplayerSynchronizer

@export var jumping: bool = false
@export var direction: Vector2 = Vector2.ZERO
	setget _set_direction, _get_direction

func _get_direction() -> Vector2:
	return direction

func _set_direction(value: Vector2) -> void:
	if direction == value:
		return
	direction = value

func _ready() -> void:
	set_process(get_multiplayer_authority() == multiplayer.get_unique_id())

func _process(delta: float) -> void:
	if not get_multiplayer_authority() == multiplayer.get_unique_id():
		return
		
	jumping = false
	direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	rpc_set_direction.rpc(direction)
	
	if Input.is_action_just_pressed("ui_accept"):
		jump_rpc.rpc()

@rpc("any_peer", "call_local", "reliable")
func jump_rpc() -> void:
	jumping = true

@rpc("any_peer", "reliable")
func rpc_set_direction(new_direction: Vector2) -> void:
	direction = new_direction