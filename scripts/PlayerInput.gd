extends MultiplayerSynchronizer
@export var jumping := false
@export var direction := Vector2()
func _ready():
    set_process(get_multiplayer_authority() == multiplayer.get_unique_id())
func _process(delta):
    jumping = false
    direction = Vector2(
        Input.get_axis("ui_left", "ui_right"),
        Input.get_axis("ui_down", "ui_up")
    )
    if Input.is_action_just_pressed("ui_accept"):
        jump_rpc()
@rpc("any_peer", "reliable")
func jump_rpc():
    jumping = true