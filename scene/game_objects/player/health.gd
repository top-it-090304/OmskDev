extends TextureProgressBar


@export var player: CharacterBody2D

func _ready():
   
	
	player.connect("health_changed", _on_health_changed)
	
   
	value = player.health 
	max_value = player.max_health 




func _on_health_changed(new_health: int, new_max_health: int):
	value = new_health
	max_value = new_max_health
