extends Area2D

var is_open = false

func _ready():
	modulate.a = 0.0
	monitoring = false
	body_entered.connect(_on_body_entered)

func open_hatch():
	is_open = true
	monitoring = true
	AudioManager.play_sfx("люк_открытие")
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.6)

func _on_body_entered(body: Node2D):
	if not is_open or not body.is_in_group("player"):
		return
	AudioManager.play_sfx("люк_переход")
	_go_to_next_floor()

func _go_to_next_floor():
	GameConstants.CURRENT_FLOOR += 1
	GameConstants.ROOMS_CLEARED = 0
	GameConstants.save_to_disk()
	SaveSystem.save_game()
	SaveSystem.delete_dungeon_state()
	var floor = GameConstants.CURRENT_FLOOR
	var scene: String
	if floor <= 2:
		scene = "res://World/layer.tscn"
	elif floor <= 4:
		scene = "res://World/layer_act2.tscn"
	else:
		scene = "res://World/layer.tscn"  # этажи 5-6 — снова первый акт (или замени на layer_act3)
	AudioManager.stop_music()
	get_tree().change_scene_to_file(scene)
