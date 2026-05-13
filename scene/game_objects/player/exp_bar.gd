extends Control

@onready var progress_bar = $ProgressBar
@onready var level_label = $LevelLabel
@onready var exp_label = $ExpLabel

var player: Node = null

func _ready():
	# Ждем один кадр, чтобы игрок успел инициализироваться
	await get_tree().process_frame

	# Только локальный игрок (в коопе в группе "player" несколько нод)
	player = get_tree().get_first_node_in_group("local_player")
	if not player:
		await get_tree().process_frame
		player = get_tree().get_first_node_in_group("local_player")

	if player:
		if get_tree().get_multiplayer().has_multiplayer_peer() and not player.is_in_group("local_player"):
			push_warning("ExpBar: узел не в группе local_player — HUD опыта не подключён")
			return
		# Подключаемся к сигналам
		if not player.exp_changed.is_connected(_on_exp_changed):
			player.exp_changed.connect(_on_exp_changed)
		if not player.level_up.is_connected(_on_level_up):
			player.level_up.connect(_on_level_up)

		# Инициализируем начальные значения
		_update_display(player.current_exp, player.exp_to_next_level, player.current_level)
		print("ExpBar: Подключен к игроку. Уровень: ", player.current_level, " Опыт: ", player.current_exp, "/", player.exp_to_next_level)
	else:
		push_warning("ExpBar: Игрок не найден в группе 'player'")

func _on_exp_changed(current_exp: int, exp_needed: int):
	_update_display(current_exp, exp_needed, player.current_level)

func _on_level_up(new_level: int):
	_update_display(player.current_exp, player.exp_to_next_level, new_level)
	_play_level_up_animation()

func _update_display(current: int, needed: int, level: int):
	var percentage = 0.0
	if needed > 0:
		percentage = clampf((float(current) / float(needed)) * 100.0, 0.0, 100.0)
	progress_bar.value = percentage

	level_label.text = "Level: " + str(level)
	exp_label.text = str(current) + " / " + str(needed)

func _play_level_up_animation():
	# Простая анимация: увеличение и уменьшение
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(level_label, "scale", Vector2(1.5, 1.5), 0.3)
	tween.tween_property(level_label, "scale", Vector2(1.0, 1.0), 0.3)
