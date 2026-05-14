extends Node

signal constants_changed

const CONFIG_PATH = "user://game_consts.cfg"
const RELOAD_CHECK_INTERVAL_SEC = 0.5


## В GDScript 4 нет глобального bool(); cfg / .get() / RPC дают Variant — приводим к bool.
func variant_to_bool(v: Variant) -> bool:
	if v is bool:
		return v
	if v is int or v is float:
		return v != 0
	if v is String:
		return v.to_lower() in ["true", "1", "yes", "on"]
	return false

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

## Препятствия (камни): 0 = нет, 1 = половина от «полного» счётчика, 2 = как задумано в генераторе.
var OBSTACLE_DETAIL_LEVEL: int = 2


func clamp_obstacle_detail_level(v: Variant) -> int:
	return clampi(int(v), 0, 2)

# --- ПАРАМЕТРЫ КАРТЫ ---
var MAP_MANAGER_ROOM_SIZE_X = 864
var MAP_MANAGER_ROOM_SIZE_Y = 608 + 32
var MAP_MANAGER_CORRIDOR_LENGTH = 64
var MAP_MANAGER_GRID_SIZE = 8

# --- ПРЕЛОАДЫ (Загрузка ресурсов) ---
const SKELETON_BOW_ARROW = preload("res://scene/game_objects/enemy/skeleton_bow/arrow.tscn")
const GOBLIN_SLINGER_PROJECTILE = preload("res://scene/game_objects/enemy/goblin_slinger/poison_projectile.tscn")
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

# Яд пращника (poison_projectile.gd)
var POISON_PROJECTILE_DAMAGE: int = 2
var POISON_PROJECTILE_SPEED: float = 350.0
var POISON_DURATION: float = 5.0
var POISON_TICK_RATE: float = 0.5

# Гоблин с топором
var ENEMY_GOBLIN_AXE_HP = 70
var ENEMY_GOBLIN_AXE_MAX_SPEED = 150
## Контактный хитбокс: ~2× урон касания скелета (SKELETON_BOW_BODY_DAMAGE)
var ENEMY_GOBLIN_AXE_DAMAGE = 20
var ENEMY_GOBLIN_AXE_EXP_REWARD = 20
var ENEMY_GOBLIN_AXE_TAKE_DAMAGE: int = 10
## Макс. дистанция удара топором/смайта (меньше зоны detector)
var ENEMY_GOBLIN_AXE_ATTACK_RANGE: float = 105.0

const ENEMY_GOBLIN_AXE_SMITE = preload("res://scene/game_objects/enemy/goblin_axe/smite.tscn")
var ENEMY_GOBLIN_AXE_SMITE_OFFSET: float = 20.0

## Удар смайта: 2× урон стрелы скелета (ARROW_DAMAGE)
var SMITE_DAMAGE: int = 40
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

# --- БОСС: Зверь-гоблин (beast_goblin.gd) ---
var ENEMY_BEASTGOBLIN_HP = 400
var ENEMY_BEASTGOBLIN_MAX_SPEED = 180
var ENEMY_BEASTGOBLIN_BITE_DAMAGE = 30
var ENEMY_BEASTGOBLIN_SLAP_DAMAGE = 25
var ENEMY_BEASTGOBLIN_TAKE_DAMAGE = 10
var ENEMY_BEASTGOBLIN_EXP_REWARD = 200

# --- ПРОГРЕССИЯ ОКРУЖЕНИЯ ---
var _current_floor_internal: int = 1
var CURRENT_FLOOR: int:
	get:
		return _current_floor_internal
	set(value):
		if _current_floor_internal == value:
			return
		_current_floor_internal = value
		var tree := get_tree()
		if tree != null:
			var floor_label := tree.get_first_node_in_group("floor_label")
			if is_instance_valid(floor_label) and "text" in floor_label:
				floor_label.text = "Floor %d" % _current_floor_internal
		constants_changed.emit()

var ENEMY_LEVEL = 1
var ENEMY_LEVEL_SCALING = 0.15

# --- СИСТЕМНЫЕ ПЕРЕМЕННЫЕ (Авто-перезагрузка конфига) ---
var _reload_timer_sec := 0.0
var _last_cfg_mtime := -1

func _ready() -> void:
	load_from_disk()
	_load_user_settings_graphics()
	if FileAccess.file_exists(CONFIG_PATH):
		_last_cfg_mtime = FileAccess.get_modified_time(CONFIG_PATH)


const USER_SETTINGS_PATH := "user://settings.cfg"


func _load_user_settings_graphics() -> void:
	var scfg := ConfigFile.new()
	if scfg.load(USER_SETTINGS_PATH) != OK:
		return
	if not scfg.has_section("graphics"):
		return
	SHOW_PARTICLES = variant_to_bool(scfg.get_value("graphics", "show_particles", SHOW_PARTICLES))
	OBSTACLE_DETAIL_LEVEL = clamp_obstacle_detail_level(scfg.get_value("graphics", "obstacle_detail", OBSTACLE_DETAIL_LEVEL))

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
	cfg.load(CONFIG_PATH)
	cfg.set_value("stats", "ENEMY_LEVEL", ENEMY_LEVEL)
	cfg.set_value("stats", "CURRENT_FLOOR", _current_floor_internal)
	cfg.set_value("stats", "ROOMS_CLEARED", ROOMS_CLEARED)
	cfg.set_value("stats", "ENEMIES_KILLED", ENEMIES_KILLED)
	cfg.save(CONFIG_PATH)
	_last_cfg_mtime = FileAccess.get_modified_time(CONFIG_PATH)

func load_from_disk() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	_current_floor_internal = int(cfg.get_value("stats", "CURRENT_FLOOR", _current_floor_internal))
	ENEMY_LEVEL = int(cfg.get_value("stats", "ENEMY_LEVEL", ENEMY_LEVEL))
	ROOMS_CLEARED = int(cfg.get_value("stats", "ROOMS_CLEARED", ROOMS_CLEARED))
	ENEMIES_KILLED = int(cfg.get_value("stats", "ENEMIES_KILLED", ENEMIES_KILLED))
	_apply_stats_section_from_cfg(cfg, "stats")
	constants_changed.emit()


## Все числовые/булевы поля баланса из [stats] — единая точка чтения с диска (user://game_consts.cfg).
func _apply_stats_section_from_cfg(cfg: ConfigFile, section: String) -> void:
	if not cfg.has_section(section):
		return
	var allowed := {}
	for p in get_property_list():
		if not (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		if String(p.name).begins_with("_"):
			continue
		allowed[p.name] = p
	for key in cfg.get_section_keys(section):
		if key == "CURRENT_FLOOR" or key == "ENEMY_LEVEL" or key == "ROOMS_CLEARED" or key == "ENEMIES_KILLED":
			continue
		if not allowed.has(key):
			continue
		var raw: Variant = cfg.get_value(section, key)
		var curv: Variant = get(key)
		var t := typeof(curv)
		match t:
			TYPE_INT:
				set(key, int(raw))
			TYPE_FLOAT:
				set(key, float(raw))
			TYPE_BOOL:
				set(key, variant_to_bool(raw))
			_:
				pass


## Снимок прогресса/статов хоста при старте коопа — гости получают те же числа, что и в одиночной игре.
func capture_coop_start_state() -> Dictionary:
	var d := {}
	for p in get_property_list():
		if not (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var n := String(p.name)
		if n.begins_with("_"):
			continue
		if n in [&"SHOW_PARTICLES", &"show_particles", &"OBSTACLE_DETAIL_LEVEL"]:
			continue
		var v: Variant = get(n)
		var t := typeof(v)
		if t == TYPE_INT or t == TYPE_FLOAT or t == TYPE_BOOL or t == TYPE_STRING:
			d[n] = v
	return d


func apply_coop_start_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	for k in state.keys():
		var key := String(k)
		if not _is_script_var_property(key):
			continue
		var incoming: Variant = state[k]
		var cur: Variant = get(key)
		if cur is int:
			set(key, int(incoming))
		elif cur is float:
			set(key, float(incoming))
		elif cur is bool:
			set(key, variant_to_bool(incoming))
		elif cur is String:
			set(key, String(incoming))
		else:
			var it := typeof(incoming)
			if it == TYPE_INT or it == TYPE_FLOAT or it == TYPE_BOOL or it == TYPE_STRING:
				set(key, incoming)
	constants_changed.emit()


func _is_script_var_property(nm: String) -> bool:
	for p in get_property_list():
		if String(p.name) != nm:
			continue
		return (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0
	return false
