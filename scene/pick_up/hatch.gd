extends Area2D

@export var floor_to_spawn: int = 2  # Номер следующего этажа

var is_open = false
var anim_player: AnimationPlayer
var sprite: Sprite2D

func _ready():
	anim_player = $AnimationPlayer
	sprite = $Sprite2D

	# Начальная прозрачность (люк закрыт)
	if sprite:
		sprite.modulate.a = 0.5

	# Сигнал на вход в люк
	connect("body_entered", _on_body_entered)

func open_hatch():
	"""Открыть люк (вызывается после смерти босса)"""
	is_open = true
	if sprite:
		# Анимация открытия
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 1.0, 0.5)
		tween.tween_property(sprite, "scale", Vector2(1.1, 1.1), 0.2)
		tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.2)

	# Включаем коллизию
	collision_layer = 2  # player layer
	collision_mask = 0

	print("Люк открыт! Этаж: ", floor_to_spawn)

func _on_body_entered(body: Node2D):
	"""Игрок вошёл в люк"""
	if not is_open:
		return

	if body.is_in_group("player"):
		print("Игрок вошёл в люк на этаж ", floor_to_spawn)
		transition_to_next_floor(body)

func transition_to_next_floor(player: Node2D):
	"""Переход на следующий этаж"""
	# Сохраняем текущее состояние игрока
	var player_data = {
		"position": player.global_position,
		"health": player.health_int if "health_int" in player else 0,
		"level": player.current_level if "current_level" in player else 1,
		"exp": player.current_exp if "current_exp" in player else 0,
	}

	# Сохраняем игру
	SaveSystem.save_game()

	# Сохраняем номер следующего этажа
	SaveSystem.set_current_floor(floor_to_spawn)

	# Загружаем сцену следующего этажа
	# Предполагаем, что есть сцена World/layer.tscn для генерации
	var next_floor_scene = "res://World/layer.tscn"

	# Передаем данные игрока в следующий этаж
	player_data["floor_transition"] = true

	# Сохраняем данные для восстановления
	SaveSystem.set_player_transition_data(player_data)

	# Меняем сцену
	var tree = get_tree()
	tree.change_scene_to_file(next_floor_scene)
