extends Node

signal constants_changed

const CONFIG_PATH = "res://globals/game_consts.cfg"
const RELOAD_CHECK_INTERVAL_SEC = 0.5

var MAP_MANAGER_ROOM_SIZE_X = 864
var MAP_MANAGER_ROOM_SIZE_Y = 608 + 32
var MAP_MANAGER_CORRIDOR_LENGTH = 64
var MAP_MANAGER_GRID_SIZE = 8

const SKELETON_BOW_ARROW = preload("res://scene/game_objects/enemy/skeleton_bow/arrow.tscn")
const ENEMY_GOBLIN_AXE_SMITE = preload("res://scene/game_objects/enemy/goblin_axe/smite.tscn")
const GOBLIN_SLINGER_PROJECTILE = preload("res://scene/game_objects/enemy/goblin_slinger/poison_projectile.tscn")
const HEALTH_POTION = preload("res://scene/pick_up/Heal potion/heal_potion.tscn")

# --- PLAYER STATS ---
var PLAYER_MAX_SPEED = 200


var PLAYER_MAX_HEALTH = 400
var PLAYER_ENEMY_CONTACT_DAMAGE = 100
var PLAYER_ATTACK_DAMAGE = 100
var PLAYER_ARMOR = 0  # Блокирует фиксированное количество урона
var PLAYER_DODGE_CHANCE = 0.0  # Шанс уклонения (0.0 - 1.0)
var PLAYER_CRIT_CHANCE = 0.0  # Шанс критического удара (0.0 - 1.0)
var PLAYER_CRIT_MULTIPLIER = 2.0  # Множитель критического урона
var PLAYER_LIFESTEAL = 0.0  # Вампиризм (0.0 - 1.0)
var PLAYER_ATTACK_SPEED = 1.0  # Множитель скорости атаки

# --- PLAYER LEVEL SYSTEM ---
var PLAYER_LEVEL = 1
var PLAYER_EXPERIENCE = 0
var PLAYER_BASE_EXP_TO_LEVEL = 50  # Опыт для 2 уровня (уменьшено для тестирования)
var PLAYER_EXP_MULTIPLIER = 1.3  # Каждый уровень требует в 1.3 раза больше опыта
var PLAYER_EXP_MULTIPLIER_BONUS = 1.0  # Бонус от артефактов

# Прирост характеристик за уровень
var PLAYER_HEALTH_PER_LEVEL = 20
var PLAYER_SPEED_PER_LEVEL = 5
var PLAYER_DAMAGE_PER_LEVEL = 2

# --- ENEMY: GOBLIN AXE ---
var ENEMY_GOBLIN_AXE_HP = 70
var ENEMY_GOBLIN_AXE_MAX_SPEED = 150
var ENEMY_GOBLIN_AXE_DAMAGE = 10
var ENEMY_GOBLIN_AXE_SMITE_OFFSET = 20
var ENEMY_GOBLIN_AXE_TAKE_DAMAGE = 10
var ENEMY_GOBLIN_AXE_EXP_REWARD = 100

# --- ENEMY: SKELETON BOW ---
var SKELETON_BOW_HP = 50
var SKELETON_BOW_DAMAGE = 20
var SKELETON_BOW_SPEED_MIN = 70
var SKELETON_BOW_SPEED_MAX = 160
var SKELETON_BOW_TAKE_DAMAGE = 10
var SKELETON_BOW_BODY_DAMAGE = 10
var SKELETON_BOW_EXP_REWARD = 18

# --- ENEMY: GOBLIN SLINGER ---
var GOBLIN_SLINGER_HP = 60
var GOBLIN_SLINGER_SPEED_MIN = 80
var GOBLIN_SLINGER_SPEED_MAX = 140
var GOBLIN_SLINGER_BODY_DAMAGE = 12
var GOBLIN_SLINGER_EXP_REWARD = 20

# --- PROJECTILES ---
var ARROW_DAMAGE = 20
var ARROW_SPEED = 400
var POISON_PROJECTILE_DAMAGE = 2  # Урон за тик яда
var POISON_PROJECTILE_SPEED = 350  # Скорость ядовитого снаряда
var POISON_DURATION = 5.0  # Длительность яда в секундах
var POISON_TICK_RATE = 0.5  # Частота тиков яда
var SMITE_DAMAGE = 10
var SMITE_RADIUS = 20
var SMITE_SPEED = 2

# --- BOSS: BEAST GOBLIN ---
var ENEMY_BEASTGOBLIN_HP = 450
var ENEMY_BEASTGOBLIN_MAX_SPEED = 180
var ENEMY_BEASTGOBLIN_BITE_DAMAGE = 30
var ENEMY_BEASTGOBLIN_SLAP_DAMAGE = 25
var ENEMY_BEASTGOBLIN_TAKE_DAMAGE = 10
var ENEMY_BEASTGOBLIN_EXP_REWARD = 50

# --- FLOOR ---
var CURRENT_FLOOR = 1

# --- PROGRESSION ---
var ENEMIES_KILLED = 0
var KILLS_FOR_SPEED_DOUBLE = 5
var KILLS_FOR_HP_DOUBLE = 10
var ROOMS_CLEARED = 0  # Количество зачищенных комнат
var ENEMY_LEVEL = 1  # Текущий уровень врагов
var ENEMY_LEVEL_SCALING = 0.15  # 15% прироста характеристик за уровень 

var _reload_timer_sec := 0.0
var _last_cfg_mtime := -1

func _ready() -> void:
	load_from_disk()
	_last_cfg_mtime = FileAccess.get_modified_time(CONFIG_PATH)

func _process(delta: float) -> void:
	_reload_timer_sec += delta
	if _reload_timer_sec < RELOAD_CHECK_INTERVAL_SEC:
		return
	_reload_timer_sec = 0.0
	
	if FileAccess.file_exists(CONFIG_PATH):
		var current_mtime = FileAccess.get_modified_time(CONFIG_PATH)
		if current_mtime != -1 and current_mtime != _last_cfg_mtime:
			_last_cfg_mtime = current_mtime
			load_from_disk()


func _stats_keys() -> PackedStringArray:
	return PackedStringArray([
		"MAP_MANAGER_ROOM_SIZE_X",
		"MAP_MANAGER_ROOM_SIZE_Y",
		"MAP_MANAGER_CORRIDOR_LENGTH",
		"MAP_MANAGER_GRID_SIZE",
		"PLAYER_MAX_SPEED",
		"PLAYER_MAX_HEALTH",
		"PLAYER_ENEMY_CONTACT_DAMAGE",
		"PLAYER_ATTACK_DAMAGE",
		"PLAYER_ARMOR",
		"PLAYER_DODGE_CHANCE",
		"PLAYER_CRIT_CHANCE",
		"PLAYER_CRIT_MULTIPLIER",
		"PLAYER_LIFESTEAL",
		"PLAYER_ATTACK_SPEED",
		"PLAYER_LEVEL",
		"PLAYER_EXPERIENCE",
		"PLAYER_BASE_EXP_TO_LEVEL",
		"PLAYER_EXP_MULTIPLIER",
		"PLAYER_EXP_MULTIPLIER_BONUS",
		"PLAYER_HEALTH_PER_LEVEL",
		"PLAYER_SPEED_PER_LEVEL",
		"PLAYER_DAMAGE_PER_LEVEL",
		"ENEMY_GOBLIN_AXE_HP",
		"ENEMY_GOBLIN_AXE_MAX_SPEED",
		"ENEMY_GOBLIN_AXE_DAMAGE",
		"ENEMY_GOBLIN_AXE_SMITE_OFFSET",
		"ENEMY_GOBLIN_AXE_TAKE_DAMAGE",
		"ENEMY_GOBLIN_AXE_EXP_REWARD",
		"SKELETON_BOW_HP",
		"SKELETON_BOW_DAMAGE",
		"SKELETON_BOW_SPEED_MIN",
		"SKELETON_BOW_SPEED_MAX",
		"SKELETON_BOW_TAKE_DAMAGE",
		"SKELETON_BOW_BODY_DAMAGE",
		"SKELETON_BOW_EXP_REWARD",
		"ARROW_DAMAGE",
		"ARROW_SPEED",
		"POISON_PROJECTILE_DAMAGE",
		"POISON_PROJECTILE_SPEED",
		"POISON_DURATION",
		"POISON_TICK_RATE",
		"SMITE_DAMAGE",
		"SMITE_RADIUS",
		"SMITE_SPEED",
		"ENEMY_BEASTGOBLIN_HP",
		"ENEMY_BEASTGOBLIN_MAX_SPEED",
		"ENEMY_BEASTGOBLIN_BITE_DAMAGE",
		"ENEMY_BEASTGOBLIN_SLAP_DAMAGE",
		"ENEMY_BEASTGOBLIN_TAKE_DAMAGE",
		"ENEMY_BEASTGOBLIN_EXP_REWARD",
		"ENEMIES_KILLED",
		"KILLS_FOR_SPEED_DOUBLE",
		"KILLS_FOR_HP_DOUBLE",
		"ROOMS_CLEARED",
		"ENEMY_LEVEL",
		"ENEMY_LEVEL_SCALING",
		"CURRENT_FLOOR"
	])

func load_from_disk() -> void:
	var cfg = ConfigFile.new()
	var err = cfg.load(CONFIG_PATH)
	if err != OK:
		save_to_disk()
		return

	# Загружаем ТОЛЬКО прогрессию — статы берём из кода
	var progression_keys = [
		"PLAYER_LEVEL", "PLAYER_EXPERIENCE", "ENEMIES_KILLED",
		"ROOMS_CLEARED", "ENEMY_LEVEL", "CURRENT_FLOOR"
	]
	for key in progression_keys:
		if cfg.has_section_key("stats", key):
			set(key, cfg.get_value("stats", key))
	constants_changed.emit()

func save_to_disk() -> void:
	var cfg = ConfigFile.new()
	for key in _stats_keys():
		cfg.set_value("stats", key, get(key))
	cfg.save(CONFIG_PATH)
	# Обновляем время модификации, чтобы избежать бесконечной перезагрузки после сохранения
	_last_cfg_mtime = FileAccess.get_modified_time(CONFIG_PATH)

func set_stat(key: String, value: Variant, persist := true) -> void:
	if not _stats_keys().has(key):
		return
	# Балансные ограничения (Isaac-like)
	match key:
		"PLAYER_MAX_SPEED":       value = clamp(value, 50,   600)
		"PLAYER_ATTACK_DAMAGE":   value = clamp(value, 1,    999)
		"PLAYER_ATTACK_SPEED":    value = clamp(value, 0.5,  10.0)
		"PLAYER_ARMOR":           value = clamp(value, 0,    99)
		"PLAYER_DODGE_CHANCE":    value = clamp(value, 0.0,  0.9)   # макс 90%
		"PLAYER_CRIT_CHANCE":     value = clamp(value, 0.0,  1.0)
		"PLAYER_CRIT_MULTIPLIER": value = clamp(value, 1.0,  10.0)
		"PLAYER_LIFESTEAL":       value = clamp(value, 0.0,  1.0)   # макс 100%
		"PLAYER_MAX_HEALTH":      value = clamp(value, 1,    9999)
	set(key, value)
	if persist:
		save_to_disk()
	constants_changed.emit()

# Функция для расчета характеристик врага с учетом уровня
func get_scaled_enemy_stat(base_value: float) -> int:
	var multiplier = 1.0 + (ENEMY_LEVEL - 1) * ENEMY_LEVEL_SCALING
	return int(base_value * multiplier)

# Функция для повышения уровня врагов при зачистке комнаты
func on_room_cleared() -> void:
	ROOMS_CLEARED += 1

	# Каждые 2 комнаты - повышение уровня врагов
	if int(ROOMS_CLEARED) % 2 == 0:
		ENEMY_LEVEL += 1
		print("=== УРОВЕНЬ ВРАГОВ ПОВЫШЕН ===")
		print("Новый уровень врагов: ", ENEMY_LEVEL)
		print("Множитель характеристик: x", 1.0 + (ENEMY_LEVEL - 1) * ENEMY_LEVEL_SCALING)
		print("==============================")

	save_to_disk()
	constants_changed.emit()
