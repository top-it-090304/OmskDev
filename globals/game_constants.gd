extends Node

signal constants_changed

const CONFIG_PATH = "user://game_consts.cfg"
const RELOAD_CHECK_INTERVAL_SEC = 0.5

# --- СТАТИСТИКА И ПРОГРЕСС ---
var ENEMIES_KILLED: int = 0
var ROOMS_CLEARED: int = 0  # Теперь объявлено только здесь (ошибка дублирования исправлена)

# --- ГРАФИКА ---
var SHOW_PARTICLES: bool = true
## Совместимость со старым кодом и настройками (settings.gd)
var show_particles: bool:
	get:
		return SHOW_PARTICLES
	set(value):
		SHOW_PARTICLES = value

# --- ПАРАМЕТРЫ КАРТЫ ---
var MAP_MANAGER_ROOM_SIZE_X = 864
var MAP_MANAGER_ROOM_SIZE_Y = 608 + 32
var MAP_MANAGER_CORRIDOR_LENGTH = 64
var MAP_MANAGER_GRID_SIZE = 8

# --- ПРЕЛОАДЫ (Загрузка ресурсов) ---
const SKELETON_BOW_ARROW = preload("res://scene/game_objects/enemy/skeleton_bow/arrow.tscn")
const HEALTH_POTION = preload("res://scene/pick_up/Heal potion/heal_potion.tscn")

# --- ХАРАКТЕРИСТИКИ ИГРОКА ---
var PLAYER_MAX_SPEED = 200
var PLAYER_MAX_HEALTH = 300
var PLAYER_ATTACK_DAMAGE = 100
var PLAYER_ARMOR = 0
var PLAYER_DODGE_CHANCE = 0.0
var PLAYER_CRIT_CHANCE = 0.0
var PLAYER_CRIT_MULTIPLIER = 2.0
var PLAYER_LIFESTEAL = 0.0
var PLAYER_ATTACK_SPEED = 1.3
var PLAYER_ENEMY_CONTACT_DAMAGE = 100

# --- СИСТЕМА УРОВНЕЙ ИГРОКА ---
var PLAYER_LEVEL: int = 1
var PLAYER_EXPERIENCE: int = 0
var PLAYER_BASE_EXP_TO_LEVEL = 50
var PLAYER_EXP_MULTIPLIER = 1.3
var PLAYER_EXP_MULTIPLIER_BONUS = 1.0

# Параметры прироста при повышении уровня
var PLAYER_HEALTH_PER_LEVEL = 20
var PLAYER_SPEED_PER_LEVEL = 5
var PLAYER_DAMAGE_PER_LEVEL = 2

# Настройки всплывающих чисел (добавлено для совместимости с кодом игрока)
var SHOW_DAMAGE_NUMBERS: bool = true
var SHOW_HEAL_NUMBERS: bool = true

# --- ВРАГИ: БАЛАНС ---

# Скелет-лучник: стрела (arrow.gd)
var ARROW_SPEED: float = 400.0
var ARROW_DAMAGE: int = 20

# Скелет-лучник
var SKELETON_BOW_HP = 50
var SKELETON_BOW_SPEED_MIN = 70 
var SKELETON_BOW_SPEED_MAX = 110
var SKELETON_BOW_DAMAGE = 20
var SKELETON_BOW_BODY_DAMAGE = 10
var SKELETON_BOW_EXP_REWARD = 18

# Гоблин-пращник
var GOBLIN_SLINGER_HP = 60
var GOBLIN_SLINGER_SPEED_MIN = 60
var GOBLIN_SLINGER_SPEED_MAX = 100
var GOBLIN_SLINGER_BODY_DAMAGE = 15
var GOBLIN_SLINGER_EXP_REWARD = 20

# Гоблин с топором
var ENEMY_GOBLIN_AXE_HP = 70
var ENEMY_GOBLIN_AXE_MAX_SPEED = 150
var ENEMY_GOBLIN_AXE_DAMAGE = 10
var ENEMY_GOBLIN_AXE_EXP_REWARD = 20
var ENEMY_GOBLIN_AXE_TAKE_DAMAGE: int = 10

const ENEMY_GOBLIN_AXE_SMITE = preload("res://scene/game_objects/enemy/goblin_axe/smite.tscn")
var ENEMY_GOBLIN_AXE_SMITE_OFFSET: float = 20.0

var SMITE_DAMAGE: int = 10
var SMITE_RADIUS: float = 20.0
var SMITE_SPEED: float = 2.0

# --- БОССЫ ---
var ENEMY_SKELETON_KING_HP = 600
var ENEMY_SKELETON_KING_MAX_SPEED = 100
var ENEMY_SKELETON_KING_MELEE_DAMAGE = 40
var ENEMY_SKELETON_KING_AOE_DAMAGE = 25
var ENEMY_SKELETON_KING_BONE_SPEAR_DAMAGE = 60
var ENEMY_SKELETON_KING_TAKE_DAMAGE = 20
var ENEMY_SKELETON_KING_EXP_REWARD = 350
var SKELETON_KING_MINION = preload("res://scene/game_objects/enemy/skeleton_bow/skeleton_bow.tscn")
var SKELETON_KING_BONE_PROJECTILE = preload("res://scene/game_objects/enemy/skeleton_bow/arrow.tscn")

# --- ПРОГРЕССИЯ ОКРУЖЕНИЯ ---
var _current_floor_internal: int = 1
var CURRENT_FLOOR: int:
	get:
		return _current_floor_internal
	set(value):
		if _current_floor_internal == value:
			return
		_current_floor_internal = value
		var floor_label = get_tree().get_first_node_in_group("floor_label")
		if floor_label and "text" in floor_label:
			floor_label.text = "Floor %d" % _current_floor_internal
		constants_changed.emit()

var ENEMY_LEVEL = 1
var ENEMY_LEVEL_SCALING = 0.15

# --- СИСТЕМНЫЕ ПЕРЕМЕННЫЕ (Авто-перезагрузка конфига) ---
var _reload_timer_sec := 0.0
var _last_cfg_mtime := -1

func _ready() -> void:
	load_from_disk()
	if FileAccess.file_exists(CONFIG_PATH):
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

func get_scaled_enemy_stat(base_value: float) -> int:
	var multiplier = 1.0 + (ENEMY_LEVEL - 1) * ENEMY_LEVEL_SCALING
	return int(base_value * multiplier)

func on_room_cleared() -> void:
	ROOMS_CLEARED += 1
	if ROOMS_CLEARED > 0 and ROOMS_CLEARED % 2 == 0:
		ENEMY_LEVEL += 1
	save_to_disk()
	constants_changed.emit()


## Только счётчики (без save) — для гостей при синхроне зачистки с хоста
func on_room_cleared_clients_sync() -> void:
	ROOMS_CLEARED += 1
	if ROOMS_CLEARED > 0 and ROOMS_CLEARED % 2 == 0:
		ENEMY_LEVEL += 1
	constants_changed.emit()

func save_to_disk() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("stats", "ENEMY_LEVEL", ENEMY_LEVEL)
	cfg.set_value("stats", "CURRENT_FLOOR", _current_floor_internal)
	cfg.set_value("stats", "ROOMS_CLEARED", ROOMS_CLEARED)
	cfg.save(CONFIG_PATH)
	_last_cfg_mtime = FileAccess.get_modified_time(CONFIG_PATH)

func load_from_disk() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		_current_floor_internal = cfg.get_value("stats", "CURRENT_FLOOR", 1)
		ENEMY_LEVEL = cfg.get_value("stats", "ENEMY_LEVEL", 1)
		ROOMS_CLEARED = cfg.get_value("stats", "ROOMS_CLEARED", 0)
	constants_changed.emit()
