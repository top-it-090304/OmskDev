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
const HEALTH_POTION = preload("res://scene/pick_up/Heal potion/heal_potion.tscn")

# --- PLAYER STATS ---
var PLAYER_MAX_SPEED = 300
var PLAYER_MAX_HEALTH = 100
var PLAYER_ENEMY_CONTACT_DAMAGE = 10

# --- ENEMY: GOBLIN AXE ---
var ENEMY_GOBLIN_AXE_HP = 20
var ENEMY_GOBLIN_AXE_MAX_SPEED = 150
var ENEMY_GOBLIN_AXE_DAMAGE = 10
var ENEMY_GOBLIN_AXE_SMITE_OFFSET = 20
var ENEMY_GOBLIN_AXE_TAKE_DAMAGE = 10

# --- ENEMY: SKELETON BOW ---
var SKELETON_BOW_HP = 20
var SKELETON_BOW_DAMAGE = 20
var SKELETON_BOW_SPEED_MIN = 70
var SKELETON_BOW_SPEED_MAX = 160
var SKELETON_BOW_TAKE_DAMAGE = 10
var SKELETON_BOW_BODY_DAMAGE = 10

# --- PROJECTILES ---
var ARROW_DAMAGE = 20
var ARROW_SPEED = 10
var SMITE_DAMAGE = 10
var SMITE_RADIUS = 20
var SMITE_SPEED = 2

# --- BOSS: BEAST GOBLIN ---
var ENEMY_BEASTGOBLIN_HP = 150
var ENEMY_BEASTGOBLIN_MAX_SPEED = 120
var ENEMY_BEASTGOBLIN_BITE_DAMAGE = 30
var ENEMY_BEASTGOBLIN_SLAP_DAMAGE = 15
var ENEMY_BEASTGOBLIN_TAKE_DAMAGE = 10

# --- PROGRESSION ---
var ENEMIES_KILLED = 0
var KILLS_FOR_SPEED_DOUBLE = 5
var KILLS_FOR_HP_DOUBLE = 10 

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
		"ENEMY_GOBLIN_AXE_HP",
		"ENEMY_GOBLIN_AXE_MAX_SPEED",
		"ENEMY_GOBLIN_AXE_DAMAGE",
		"ENEMY_GOBLIN_AXE_SMITE_OFFSET",
		"ENEMY_GOBLIN_AXE_TAKE_DAMAGE",
		"SKELETON_BOW_HP",
		"SKELETON_BOW_DAMAGE",
		"SKELETON_BOW_SPEED_MIN",
		"SKELETON_BOW_SPEED_MAX",
		"SKELETON_BOW_TAKE_DAMAGE",
		"SKELETON_BOW_BODY_DAMAGE",
		"ARROW_DAMAGE",
		"ARROW_SPEED",
		"SMITE_DAMAGE",
		"SMITE_RADIUS",
		"SMITE_SPEED",
		"ENEMY_BEASTGOBLIN_HP",
		"ENEMY_BEASTGOBLIN_MAX_SPEED",
		"ENEMY_BEASTGOBLIN_BITE_DAMAGE",
		"ENEMY_BEASTGOBLIN_SLAP_DAMAGE",
		"ENEMY_BEASTGOBLIN_TAKE_DAMAGE",
		"ENEMIES_KILLED",
		"KILLS_FOR_SPEED_DOUBLE",
		"KILLS_FOR_HP_DOUBLE"
	])

func load_from_disk() -> void:
	var cfg = ConfigFile.new()
	var err = cfg.load(CONFIG_PATH)
	if err != OK:
		save_to_disk()
		return
	for key in _stats_keys():
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
	set(key, value)
	if persist:
		save_to_disk()
	constants_changed.emit()
