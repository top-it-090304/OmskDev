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
var PLAYER_MAX_HEALTH = 450
var PLAYER_ATTACK_DAMAGE = 40
var PLAYER2_MAX_HEALTH = 200
var PLAYER2_ATTACK_DAMAGE = 15
var PLAYER_ARMOR = 0
var PLAYER_DODGE_CHANCE = 0.0
var PLAYER_CRIT_CHANCE = 0.0
var PLAYER_CRIT_MULTIPLIER = 2.0
var PLAYER_LIFESTEAL = 0.0
var PLAYER_ATTACK_SPEED = 1.3
var PLAYER_ENEMY_CONTACT_DAMAGE = 15
## Неуязвимость после удара (сек). Слишком мало — смерть от пачки врагов за кадр.
var PLAYER_DAMAGE_INVINCIBILITY_SEC: float = 0.35

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

func get_player2_max_health() -> int:
	return maxi(1, PLAYER2_MAX_HEALTH)


func get_player2_attack_damage() -> int:
	return maxi(1, PLAYER2_ATTACK_DAMAGE)


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

# Маг
var ENEMY_MAGICAN_HP = 55
var ENEMY_MAGICAN_MAX_SPEED = 95
var ENEMY_MAGICAN_WAVE_DAMAGE = 24
var ENEMY_MAGICAN_WAVE_SPEED: float = 210.0
var ENEMY_MAGICAN_EXP_REWARD = 24
var ENEMY_MAGICAN_TARGET_DISTANCE: float = 170.0
var ENEMY_MAGICAN_ATTACK_RANGE: float = 260.0
var ENEMY_MAGICAN_ATTACK_COOLDOWN: float = 2.2

# Одержимый со стиком
var ENEMY_MAN_STICK_HP = 80
var ENEMY_MAN_STICK_MAX_SPEED = 145
var ENEMY_MAN_STICK_DAMAGE = 22
var ENEMY_MAN_STICK_EXP_REWARD = 22
var ENEMY_MAN_STICK_ATTACK_RANGE: float = 100.0
var ENEMY_MAN_STICK_ATTACK_COOLDOWN: float = 1.5
var ENEMY_MAN_STICK_SMITE_OFFSET: float = 20.0

# Скелет-grunt
const ENEMY_SKELETON_GRUNT_SMITE = preload("res://scene/game_objects/enemy/goblin_axe/smite.tscn")
var ENEMY_SKELETON_GRUNT_HP = 60
var ENEMY_SKELETON_GRUNT_MAX_SPEED = 130
var ENEMY_SKELETON_GRUNT_DAMAGE = 18
var ENEMY_SKELETON_GRUNT_EXP_REWARD = 18
var ENEMY_SKELETON_GRUNT_TAKE_DAMAGE: int = 8
var ENEMY_SKELETON_GRUNT_ATTACK_RANGE: float = 90.0
var ENEMY_SKELETON_GRUNT_SMITE_OFFSET: float = 22.0

## Удар смайта: 2× урон стрелы скелета (ARROW_DAMAGE)
var SMITE_DAMAGE: int = 40
var SMITE_RADIUS: float = 20.0
var SMITE_SPEED: float = 2.0

# --- БОССЫ ---
var ENEMY_SKELETON_KING_HP = 600
var ENEMY_SKELETON_KING_MAX_SPEED = 80
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

# --- БОСС: Goblin Raider ---
var ENEMY_GOBLIN_RAIDER_HP = 360
var ENEMY_GOBLIN_RAIDER_MAX_SPEED = 210
var ENEMY_GOBLIN_RAIDER_BITE_DAMAGE = 35
var ENEMY_GOBLIN_RAIDER_WAVE_DAMAGE = 32
var ENEMY_GOBLIN_RAIDER_ROCK_DAMAGE = 28
var ENEMY_GOBLIN_RAIDER_ROCK_SPLASH_DAMAGE_MIN = 8
var ENEMY_GOBLIN_RAIDER_ROCK_SPLASH_DAMAGE_MAX = 18
var ENEMY_GOBLIN_RAIDER_ROCK_SPLASH_RADIUS: float = 58.0
var ENEMY_GOBLIN_RAIDER_EXP_REWARD = 240
var ENEMY_GOBLIN_RAIDER_TARGET_DISTANCE: float = 165.0
var ENEMY_GOBLIN_RAIDER_BITE_RANGE: float = 70.0
var ENEMY_GOBLIN_RAIDER_WAVE_RANGE: float = 210.0
var ENEMY_GOBLIN_RAIDER_THROW_RANGE: float = 300.0
var ENEMY_GOBLIN_RAIDER_BITE_COOLDOWN: float = 2.2
var ENEMY_GOBLIN_RAIDER_WAVE_COOLDOWN: float = 3.4
var ENEMY_GOBLIN_RAIDER_THROW_COOLDOWN: float = 2.8

# --- БОСС: Skeleton Swordman ---
var ENEMY_SKELETON_SWORDMAN_HP = int(ENEMY_BEASTGOBLIN_HP * 1.5)
var ENEMY_SKELETON_SWORDMAN_MAX_SPEED = 135
var ENEMY_SKELETON_SWORDMAN_DAMAGE = 28
var ENEMY_SKELETON_SWORDMAN_STRONG_DAMAGE = 30
var ENEMY_SKELETON_SWORDMAN_WAVE_DAMAGE = 30
var ENEMY_SKELETON_SWORDMAN_TAKE_DAMAGE = 10
var ENEMY_SKELETON_SWORDMAN_EXP_REWARD = 275

# --- ПРОГРЕССИЯ ОКРУЖЕНИЯ ---
const DEFAULT_FLOOR_SCENE_PATH := "res://World/layer.tscn"
const ACT2_FLOOR_SCENE_PATH := "res://World/layer_act2.tscn"
const LAYER3_FLOOR_SCENE_PATH := "res://World/layer3.tscn"
const LAYER4_FLOOR_SCENE_PATH := "res://World/layer4.tscn"

const BOSS_ARTEFACT_SCENE_PATHS_BY_FLOOR := {
	1: [
		"res://scene/pick_up/artefacts/small_cactus.tscn",
		"res://scene/pick_up/artefacts/lime_juice.tscn",
		"res://scene/pick_up/artefacts/ramen_bowl.tscn",
	],
	2: [
		"res://scene/pick_up/artefacts/pill.tscn",
		"res://scene/pick_up/artefacts/pill_can.tscn",
		"res://scene/pick_up/artefacts/juice_box.tscn",
	],
	3: [
		"res://scene/pick_up/artefacts/fairy_bottle.tscn",
		"res://scene/pick_up/artefacts/flashlight.tscn",
		"res://scene/pick_up/artefacts/top_hat.tscn",
	],
	4: [
		"res://scene/pick_up/artefacts/snow_ball.tscn",
		"res://scene/pick_up/artefacts/disco_ball.tscn",
		"res://scene/pick_up/artefacts/bongo.tscn",
	],
}

const BOSS_ARTEFACT_RECENT_LIMIT := 5
var _recent_boss_artefact_paths: Array[String] = []
var _used_artefact_scene_paths: Array[String] = []

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


func get_scene_path_for_floor(floor_index: int) -> String:
	match floor_index:
		1:
			return DEFAULT_FLOOR_SCENE_PATH
		2:
			return ACT2_FLOOR_SCENE_PATH
		3:
			return LAYER3_FLOOR_SCENE_PATH
		_:
			return LAYER4_FLOOR_SCENE_PATH


func get_current_floor_scene_path() -> String:
	return get_scene_path_for_floor(CURRENT_FLOOR)


func get_boss_artefact_scene_paths_for_floor(floor_index: int) -> Array[String]:
	var pool_key := floor_index if floor_index <= 4 else 4
	var raw_pool: Array = BOSS_ARTEFACT_SCENE_PATHS_BY_FLOOR.get(pool_key, BOSS_ARTEFACT_SCENE_PATHS_BY_FLOOR[4])
	var result: Array[String] = []
	for path: String in raw_pool:
		result.append(path)
	return result


func get_all_boss_artefact_scene_paths() -> Array[String]:
	var result: Array[String] = []
	for floor_key in BOSS_ARTEFACT_SCENE_PATHS_BY_FLOOR.keys():
		var raw_pool: Array = BOSS_ARTEFACT_SCENE_PATHS_BY_FLOOR[floor_key]
		for path: String in raw_pool:
			if not result.has(path):
				result.append(path)
	return result


func get_random_boss_artefact_scenes(count: int = 1) -> Array[PackedScene]:
	return get_unique_artefact_scenes_from_paths(get_all_boss_artefact_scene_paths(), count, true)


func get_unique_artefact_scenes_from_paths(paths: Array, count: int = 1, allow_reuse_when_exhausted: bool = true) -> Array[PackedScene]:
	var candidates: Array[String] = []
	for raw_path in paths:
		var path := str(raw_path)
		if path.is_empty() or candidates.has(path) or _used_artefact_scene_paths.has(path):
			continue
		candidates.append(path)
	if candidates.size() < maxi(1, count) and allow_reuse_when_exhausted:
		candidates.clear()
		for raw_path in paths:
			var path := str(raw_path)
			if not path.is_empty() and not candidates.has(path):
				candidates.append(path)
	candidates.shuffle()
	var result: Array[PackedScene] = []
	for _i in range(maxi(1, count)):
		if candidates.is_empty():
			break
		var idx := 0
		if candidates.size() > 1:
			idx = randi() % candidates.size()
		var path := candidates[idx]
		var scene := load(path) as PackedScene
		candidates.remove_at(idx)
		if scene != null:
			result.append(scene)
			remember_artefact_scene_path(path)
	return result


func remember_artefact_scene_path(path: String) -> void:
	if path.is_empty():
		return
	if not _used_artefact_scene_paths.has(path):
		_used_artefact_scene_paths.append(path)
	_recent_boss_artefact_paths.erase(path)
	_recent_boss_artefact_paths.append(path)
	while _recent_boss_artefact_paths.size() > BOSS_ARTEFACT_RECENT_LIMIT:
		_recent_boss_artefact_paths.remove_at(0)


func is_artefact_scene_path_used(path: String) -> bool:
	return _used_artefact_scene_paths.has(path)


func clear_used_artefact_scene_paths() -> void:
	_used_artefact_scene_paths.clear()
	_recent_boss_artefact_paths.clear()


func set_used_artefact_scene_paths(paths: Array) -> void:
	clear_used_artefact_scene_paths()
	for raw_path in paths:
		remember_artefact_scene_path(str(raw_path))


func get_used_artefact_scene_paths() -> Array[String]:
	var result: Array[String] = []
	for path in _used_artefact_scene_paths:
		result.append(path)
	return result

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


## В коопе размер сетки/комнаты должен совпадать с хостом; иначе горячая перезагрузка user://game_consts.cfg у гостя ломает миникарту и генерацию.
func _cfg_map_geometry_key(key: String) -> bool:
	match key:
		"MAP_MANAGER_GRID_SIZE", "MAP_MANAGER_ROOM_SIZE_X", "MAP_MANAGER_ROOM_SIZE_Y", "MAP_MANAGER_CORRIDOR_LENGTH":
			return true
		_:
			return false


## Все числовые/булевы поля баланса из [stats] — единая точка чтения с диска (user://game_consts.cfg).
func _apply_stats_section_from_cfg(cfg: ConfigFile, section: String) -> void:
	if not cfg.has_section(section):
		return
	var skip_map_geometry := NetworkManager.is_multiplayer_active()
	var allowed := {}
	for p in get_property_list():
		if not (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		if String(p.name).begins_with("_"):
			continue
		allowed[p.name] = p
	for key in cfg.get_section_keys(section):
		var ks := String(key)
		if skip_map_geometry and _cfg_map_geometry_key(ks):
			continue
		if ks == "CURRENT_FLOOR" or ks == "ENEMY_LEVEL" or ks == "ROOMS_CLEARED" or ks == "ENEMIES_KILLED":
			continue
		if not allowed.has(ks):
			continue
		var raw: Variant = cfg.get_value(section, key)
		var curv: Variant = get(ks)
		var t := typeof(curv)
		match t:
			TYPE_INT:
				set(ks, int(raw))
			TYPE_FLOAT:
				set(ks, float(raw))
			TYPE_BOOL:
				set(ks, variant_to_bool(raw))
			_:
				pass


## Общий прогресс коопа (без бонусов артефактов — они только у подобравшего).
const COOP_SHARED_STATE_KEYS: Array[String] = [
	"PLAYER_LEVEL",
	"PLAYER_EXPERIENCE",
	"PLAYER_BASE_EXP_TO_LEVEL",
	"PLAYER_EXP_MULTIPLIER",
	"PLAYER_EXP_MULTIPLIER_BONUS",
	"PLAYER_MAX_HEALTH",
	"PLAYER_MAX_SPEED",
	"PLAYER_ATTACK_DAMAGE",
	"ENEMIES_KILLED",
	"ROOMS_CLEARED",
	"CURRENT_FLOOR",
]


func capture_coop_shared_state() -> Dictionary:
	var d := {}
	for key in COOP_SHARED_STATE_KEYS:
		if _is_script_var_property(key):
			d[key] = get(key)
	return d


func apply_coop_shared_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	for key in COOP_SHARED_STATE_KEYS:
		if not state.has(key):
			continue
		if not _is_script_var_property(key):
			continue
		var incoming: Variant = state[key]
		var cur: Variant = get(key)
		if cur is int:
			set(key, int(incoming))
		elif cur is float:
			set(key, float(incoming))
		elif cur is bool:
			set(key, variant_to_bool(incoming))
		elif cur is String:
			set(key, String(incoming))
	constants_changed.emit()


## Подтянуть общий уровень на хосте после левелапа клиента (без копирования его статов от артефактов).
func catch_up_coop_levels_to(target_level: int) -> void:
	var goal := maxi(1, target_level)
	while PLAYER_LEVEL < goal:
		_apply_coop_shared_level_up_grant()
		PLAYER_LEVEL += 1


func _apply_coop_shared_level_up_grant() -> void:
	PLAYER_MAX_HEALTH = mini(PLAYER_MAX_HEALTH + PLAYER_HEALTH_PER_LEVEL, 9999)
	PLAYER_MAX_SPEED = mini(PLAYER_MAX_SPEED + PLAYER_SPEED_PER_LEVEL, 600)
	PLAYER_ATTACK_DAMAGE = mini(PLAYER_ATTACK_DAMAGE + PLAYER_DAMAGE_PER_LEVEL, 999)


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
