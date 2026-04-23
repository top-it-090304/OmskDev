extends Area2D

var is_open = false

func _ready():
	modulate.a = 0.0
	monitoring = false
	body_entered.connect(_on_body_entered)

func open_hatch():
	is_open = true
	monitoring = true
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.6)

func _on_body_entered(body: Node2D):
	if not is_open or not body.is_in_group("player"):
		return
	_go_to_next_floor()

func _go_to_next_floor():
	GameConstants.CURRENT_FLOOR += 1
	GameConstants.ROOMS_CLEARED = 0
	GameConstants.save_to_disk()
	SaveSystem.save_game()
	SaveSystem.delete_dungeon_state()
	get_tree().change_scene_to_file("res://World/layer.tscn")
