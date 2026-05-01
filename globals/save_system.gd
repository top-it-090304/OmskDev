extends Node

const SAVE_PATH = "user://save_game.dat"
const DUNGEON_PATH = "user://dungeon_state.dat"

# Флаг для определения, нужно ли восстанавливать состояние игрока
var should_restore_player = false
var saved_player_health = 0
var saved_player_position = Vector2.ZERO

# Собранные артефакты
var collected_artefacts: Array = []

# Комнаты, в которых артефакты уже собраны
var collected_treasure_rooms: Array = []

# Базовые значения для сброса
const BASE_VALUES = {
	"PLAYER_MAX_SPEED": 200,
	"PLAYER_MAX_HEALTH": 400,
	"PLAYER_ENEMY_CONTACT_DAMAGE": 10,
	"PLAYER_ATTACK_DAMAGE": 10,
	"PLAYER_ARMOR": 0,
	"PLAYER_DODGE_CHANCE": 0.0,
	"PLAYER_CRIT_CHANCE": 0.0,
	"PLAYER_CRIT_MULTIPLIER": 2.0,
	"PLAYER_LIFESTEAL": 0.0,
	"PLAYER_ATTACK_SPEED": 1.3,
	"PLAYER_LEVEL": 1,
	"PLAYER_EXPERIENCE": 0,
	"PLAYER_BASE_EXP_TO_LEVEL": 50,
	"PLAYER_EXP_MULTIPLIER": 1.4,
	"PLAYER_EXP_MULTIPLIER_BONUS": 1.0,
	"PLAYER_HEALTH_PER_LEVEL": 20,
	"PLAYER_SPEED_PER_LEVEL": 5,
	"PLAYER_DAMAGE_PER_LEVEL": 2,
	"ENEMIES_KILLED": 0,
	"ROOMS_CLEARED": 0,
	"ENEMY_LEVEL": 1,
	"CURRENT_FLOOR": 1,
}

func save_game() -> bool:
	print("=== СОХРАНЕНИЕ ИГРЫ ===")

	var save_data = {
		"version": "1.0",
		"timestamp": Time.get_unix_time_from_system(),

		# Характеристики игрока
		"player_stats": {
			"max_speed": GameConstants.PLAYER_MAX_SPEED,
			"max_health": GameConstants.PLAYER_MAX_HEALTH,
			"enemy_contact_damage": GameConstants.PLAYER_ENEMY_CONTACT_DAMAGE,
			"attack_damage": GameConstants.PLAYER_ATTACK_DAMAGE,
			"armor": GameConstants.PLAYER_ARMOR,
			"dodge_chance": GameConstants.PLAYER_DODGE_CHANCE,
			"crit_chance": GameConstants.PLAYER_CRIT_CHANCE,
			"crit_multiplier": GameConstants.PLAYER_CRIT_MULTIPLIER,
			"lifesteal": GameConstants.PLAYER_LIFESTEAL,
			"attack_speed": GameConstants.PLAYER_ATTACK_SPEED,
		},

		# Прогрессия игрока
		"player_progression": {
			"level": GameConstants.PLAYER_LEVEL,
			"experience": GameConstants.PLAYER_EXPERIENCE,
			"base_exp_to_level": GameConstants.PLAYER_BASE_EXP_TO_LEVEL,
			"exp_multiplier": GameConstants.PLAYER_EXP_MULTIPLIER,
			"exp_multiplier_bonus": GameConstants.PLAYER_EXP_MULTIPLIER_BONUS,
			"health_per_level": GameConstants.PLAYER_HEALTH_PER_LEVEL,
			"speed_per_level": GameConstants.PLAYER_SPEED_PER_LEVEL,
			"damage_per_level": GameConstants.PLAYER_DAMAGE_PER_LEVEL,
		},

		# Прогресс в игре
		"game_progress": {
			"enemies_killed": GameConstants.ENEMIES_KILLED,
			"rooms_cleared": GameConstants.ROOMS_CLEARED,
			"enemy_level": GameConstants.ENEMY_LEVEL,
			"current_floor": GameConstants.CURRENT_FLOOR,
		},

		# Позиция игрока (будет добавлена позже)
		"player_position": {
			"x": 0,
			"y": 0,
			"room_x": 0,
			"room_y": 0,
		}
	}

	# Сохраняем текущее здоровье игрока
	var player = get_tree().get_first_node_in_group("player")
	if player and "health_int" in player:
		save_data["player_current_health"] = player.health_int
		save_data["player_position"]["x"] = player.global_position.x
		save_data["player_position"]["y"] = player.global_position.y
		print("Сохранено здоровье игрока: ", player.health_int)
		print("Сохранена позиция игрока: ", player.global_position)
	else:
		# Если игрока нет на сцене, используем сохраненную позицию
		save_data["player_current_health"] = saved_player_health if saved_player_health > 0 else GameConstants.PLAYER_MAX_HEALTH
		save_data["player_position"]["x"] = saved_player_position.x
		save_data["player_position"]["y"] = saved_player_position.y
		print("Используем сохраненные данные: health=", save_data["player_current_health"], " pos=", saved_player_position)

	# Сохраняем собранные артефакты
	var backpack = get_tree().get_first_node_in_group("backpack")
	if backpack and backpack.has_method("get_collected_artefact_names"):
		save_data["collected_artefacts"] = backpack.get_collected_artefact_names()
		print("Сохранено артефактов: ", save_data["collected_artefacts"].size())

	# Сохраняем комнаты с собранными сокровищами
	save_data["collected_treasure_rooms"] = collected_treasure_rooms
	print("Сохранено комнат с собранными сокровищами: ", collected_treasure_rooms.size())

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(save_data, "\t")
		file.store_string(json_string)
		file.close()
		print("Игра успешно сохранена в: ", SAVE_PATH)
		print("======================")
		return true
	else:
		push_error("Не удалось создать файл сохранения: " + str(FileAccess.get_open_error()))
		return false

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		print("Файл сохранения не найден")
		return false

	print("=== ЗАГРУЗКА ИГРЫ ===")

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("Не удалось открыть файл сохранения: " + str(FileAccess.get_open_error()))
		return false

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		push_error("Ошибка парсинга JSON: " + json.get_error_message())
		return false

	var save_data = json.data

	# Загружаем характеристики игрока
	if "player_stats" in save_data:
		var stats = save_data["player_stats"]
		GameConstants.PLAYER_MAX_SPEED = stats.get("max_speed", BASE_VALUES["PLAYER_MAX_SPEED"])
		GameConstants.PLAYER_MAX_HEALTH = stats.get("max_health", BASE_VALUES["PLAYER_MAX_HEALTH"])
		GameConstants.PLAYER_ENEMY_CONTACT_DAMAGE = stats.get("enemy_contact_damage", BASE_VALUES["PLAYER_ENEMY_CONTACT_DAMAGE"])
		GameConstants.PLAYER_ATTACK_DAMAGE = stats.get("attack_damage", BASE_VALUES["PLAYER_ATTACK_DAMAGE"])
		GameConstants.PLAYER_ARMOR = stats.get("armor", BASE_VALUES["PLAYER_ARMOR"])
		GameConstants.PLAYER_DODGE_CHANCE = stats.get("dodge_chance", BASE_VALUES["PLAYER_DODGE_CHANCE"])
		GameConstants.PLAYER_CRIT_CHANCE = stats.get("crit_chance", BASE_VALUES["PLAYER_CRIT_CHANCE"])
		GameConstants.PLAYER_CRIT_MULTIPLIER = stats.get("crit_multiplier", BASE_VALUES["PLAYER_CRIT_MULTIPLIER"])
		GameConstants.PLAYER_LIFESTEAL = stats.get("lifesteal", BASE_VALUES["PLAYER_LIFESTEAL"])
		GameConstants.PLAYER_ATTACK_SPEED = stats.get("attack_speed", BASE_VALUES["PLAYER_ATTACK_SPEED"])

	# Загружаем прогрессию
	if "player_progression" in save_data:
		var prog = save_data["player_progression"]
		GameConstants.PLAYER_LEVEL = prog.get("level", BASE_VALUES["PLAYER_LEVEL"])
		GameConstants.PLAYER_EXPERIENCE = prog.get("experience", BASE_VALUES["PLAYER_EXPERIENCE"])
		GameConstants.PLAYER_BASE_EXP_TO_LEVEL = prog.get("base_exp_to_level", BASE_VALUES["PLAYER_BASE_EXP_TO_LEVEL"])
		GameConstants.PLAYER_EXP_MULTIPLIER = prog.get("exp_multiplier", BASE_VALUES["PLAYER_EXP_MULTIPLIER"])
		GameConstants.PLAYER_EXP_MULTIPLIER_BONUS = prog.get("exp_multiplier_bonus", BASE_VALUES["PLAYER_EXP_MULTIPLIER_BONUS"])
		GameConstants.PLAYER_HEALTH_PER_LEVEL = prog.get("health_per_level", BASE_VALUES["PLAYER_HEALTH_PER_LEVEL"])
		GameConstants.PLAYER_SPEED_PER_LEVEL = prog.get("speed_per_level", BASE_VALUES["PLAYER_SPEED_PER_LEVEL"])
		GameConstants.PLAYER_DAMAGE_PER_LEVEL = prog.get("damage_per_level", BASE_VALUES["PLAYER_DAMAGE_PER_LEVEL"])

	# Загружаем прогресс
	if "game_progress" in save_data:
		var progress = save_data["game_progress"]
		GameConstants.ENEMIES_KILLED = progress.get("enemies_killed", BASE_VALUES["ENEMIES_KILLED"])
		GameConstants.ROOMS_CLEARED = progress.get("rooms_cleared", BASE_VALUES["ROOMS_CLEARED"])
		GameConstants.ENEMY_LEVEL = progress.get("enemy_level", BASE_VALUES["ENEMY_LEVEL"])
		GameConstants.CURRENT_FLOOR = progress.get("current_floor", BASE_VALUES["CURRENT_FLOOR"])

	# Сохраняем данные для восстановления здоровья и позиции
	if "player_current_health" in save_data:
		saved_player_health = save_data["player_current_health"]
		should_restore_player = true

	if "player_position" in save_data:
		var pos = save_data["player_position"]
		saved_player_position = Vector2(pos.get("x", 0), pos.get("y", 0))

	# Загружаем собранные артефакты
	if "collected_artefacts" in save_data:
		collected_artefacts = save_data["collected_artefacts"]
		print("Загружено артефактов: ", collected_artefacts.size())

	# Загружаем комнаты с собранными сокровищами
	if "collected_treasure_rooms" in save_data:
		collected_treasure_rooms = save_data["collected_treasure_rooms"]
		print("Загружено комнат с собранными сокровищами: ", collected_treasure_rooms.size())

	GameConstants.save_to_disk()

	print("Игра успешно загружена")
	print("Уровень игрока: ", GameConstants.PLAYER_LEVEL)
	print("Опыт: ", GameConstants.PLAYER_EXPERIENCE)
	print("Здоровье: ", GameConstants.PLAYER_MAX_HEALTH)
	print("Уровень врагов: ", GameConstants.ENEMY_LEVEL)
	print("===================")

	return true

func reset_to_base_values():
	print("=== СБРОС К БАЗОВЫМ ЗНАЧЕНИЯМ ===")

	for key in BASE_VALUES:
		GameConstants.set(key, BASE_VALUES[key])

	GameConstants.save_to_disk()

	# Очищаем флаги восстановления
	should_restore_player = false
	saved_player_health = 0
	saved_player_position = Vector2.ZERO

	# Очищаем собранные артефакты
	clear_collected_artefacts()
	clear_collected_treasure_rooms()

	print("Все значения сброшены к базовым")
	print("================================")

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save():
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		print("Файл сохранения удален")

	# Также удаляем состояние данжена
	delete_dungeon_state()

# Восстановление здоровья игрока после загрузки
func restore_player_state():
	if not should_restore_player:
		return

	await get_tree().create_timer(0.1).timeout

	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	# Восстанавливаем здоровье
	if saved_player_health > 0:
		if "health_int" in player:
			player.health_int = saved_player_health
			player.health_changed.emit(saved_player_health, GameConstants.PLAYER_MAX_HEALTH)
			print("Восстановлено здоровье игрока: ", saved_player_health)

	# Восстанавливаем позицию (опционально)
	if saved_player_position != Vector2.ZERO:
		player.global_position = saved_player_position
		print("Восстановлена позиция игрока: ", player.global_position)

	# Сбрасываем флаг
	should_restore_player = false

# =====================================================================
# СОХРАНЕНИЕ/ЗАГРУЗКА СОСТОЯНИЯ ДАНЖЕНА
# =====================================================================

func save_dungeon_data(dungeon_data: Dictionary) -> bool:
	var file = FileAccess.open(DUNGEON_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(dungeon_data, "\t")
		file.store_string(json_string)
		file.close()
		print("Состояние данжена сохранено в: ", DUNGEON_PATH)
		return true
	else:
		push_error("Не удалось сохранить состояние данжена: " + str(FileAccess.get_open_error()))
		return false

func load_dungeon_data() -> Dictionary:
	if not FileAccess.file_exists(DUNGEON_PATH):
		print("Файл состояния данжена не найден")
		return {}

	var file = FileAccess.open(DUNGEON_PATH, FileAccess.READ)
	if not file:
		push_error("Не удалось открыть файл состояния данжена: " + str(FileAccess.get_open_error()))
		return {}

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		push_error("Ошибка парсинга JSON состояния данжена: " + json.get_error_message())
		return {}

	return json.data

func has_dungeon_state() -> bool:
	return FileAccess.file_exists(DUNGEON_PATH)

func delete_dungeon_state():
	if FileAccess.file_exists(DUNGEON_PATH):
		DirAccess.remove_absolute(DUNGEON_PATH)
		print("Файл состояния данжена удален")

# =====================================================================
# РАБОТА С СОБРАННЫМИ АРТЕФАКТАМИ
# =====================================================================

func has_collected_artefacts() -> bool:
	return collected_artefacts.size() > 0

func get_collected_artefacts() -> Array:
	return collected_artefacts

func clear_collected_artefacts():
	collected_artefacts.clear()

func is_treasure_collected(room_pos: Vector2i) -> bool:
	for pos in collected_treasure_rooms:
		if pos["x"] == room_pos.x and pos["y"] == room_pos.y:
			return true
	return false

func mark_treasure_collected(room_pos: Vector2i):
	if not is_treasure_collected(room_pos):
		collected_treasure_rooms.append({"x": room_pos.x, "y": room_pos.y})
		print("Комната с сокровищем отмечена как собранная: ", room_pos)

func clear_collected_treasure_rooms():
	collected_treasure_rooms.clear()
