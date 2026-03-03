extends TextureProgressBar


@export var player: Node2D       
@export var offset: Vector2 = Vector2(0, -50) 

func _ready():
   
	if player and player.has_signal("health_changed"):
		player.connect("health_changed", _on_health_changed)
	
   
	if player and player.has_method("get_health"):
		value = player.get_health()
		max_value = player.get_max_health()
	else:
	   
		value = player.health if player else 0
		max_value = player.max_health if player else 100

func _process(_delta):
	if not player:
		return

	
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return

	
	var screen_pos = camera.to_screen(player.global_position + offset)
	
  
	global_position = screen_pos


func _on_health_changed(new_health: int, new_max_health: int):
	value = new_health
	max_value = new_max_health
