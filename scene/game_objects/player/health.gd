extends TextureProgressBar

var player: CharacterBody2D

func _ready():
	# Ждем один кадр, чтобы игрок успел появиться в дереве сцены
	await get_tree().process_frame
	setup_player_connection()

func setup_player_connection():
	player = get_parent() as CharacterBody2D

	if player:
		# Если сигнал уже был подключен ранее, отключаем (на всякий случай)
		if player.is_connected("health_changed", _on_health_changed):
			player.disconnect("health_changed", _on_health_changed)
			
		player.health_changed.connect(_on_health_changed)
		
		# Синхронизируем значения сразу
		max_value = GameConstants.PLAYER_MAX_HEALTH
		value = clampi(player.health_int, 0, GameConstants.PLAYER_MAX_HEALTH)
	else:
		print("Полоска здоровья: Игрок не найден в группе 'player'")

func _on_health_changed(new_health: int, new_max_health: int):
	max_value = new_max_health
	value = clampi(new_health, 0, new_max_health)
