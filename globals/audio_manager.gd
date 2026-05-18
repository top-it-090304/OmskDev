extends Node

# --- МУЗЫКА ---
var MUSIC_EXPLORE = load("res://music/музыка_исследования.ogg")
var MUSIC_COMBAT  = null
var MUSIC_BOSS    = load("res://music/music_boss.ogg")
var MUSIC_BOSS2   = load("res://music/music_boss2.ogg")

# --- SFX ПАПКИ (рандомный выбор) ---
const SFX_FOLDERS = {
	"игрок_атака": "res://music/sfx/игрок1_атака/",
	"игрок1_атака": "res://music/sfx/игрок1_атака/",
	"игрок2_атака": "res://music/sfx/игрок2_атака/",
	"огненный_выстрел": "res://music/sfx/игрок2_атака/",
	"игрок1_ходьба": "res://music/sfx/игрок1_ходьба/",
	"игрок_урон": "res://music/sfx/игрок_урон/",
	"враг_атака_ближний": "res://music/sfx/враг_атака_ближний/",
	"враг_урон": "res://music/sfx/враг_урон/",
	"враг_выстрел_стрела": "res://music/sfx/враг_выстрел_стрела/",
	"враг_полет_стрелы": "res://music/sfx/враг_выстрел_стрела/",
	"двери_открылись": "res://music/sfx/двери_открылись/",
	"двери_закрылись": "res://music/sfx/двери_закрылись/",
	"ульта_игрок2": "res://music/sfx/ульта_игрок2/",
}

# --- SFX ОДИНОЧНЫЕ ФАЙЛЫ ---
const SFX_FILES = {
	"игрок_смерть": "res://music/sfx/игрок1_смерть.mp3",
	"игрок_левелап": "res://music/sfx/игрок_левелап.mp3",
	"игрок_зелье": "res://music/sfx/игрок_зелье.mp3",
	"игрок_артефакт": "res://music/sfx/игрок_артефакт.mp3",
	"враг_яд_выстрел": "res://music/sfx/враг_яд_выстрел.mp3",
	"босс_атака_укус": "res://music/sfx/босс_гоблин_атака_укус.mp3",
	"босс_атака_удар": "res://music/sfx/босс_гоблин_атака_удар.wav",
	"босс_смерть": "res://music/sfx/босс_гоблин_смерть.mp3",
	"люк_открытие": "res://music/sfx/люк_открытие.wav",
	"люк_переход": "res://music/sfx/люк_переход.wav",
	"враг_смерть": "res://music/sfx/враг_яд_выстрел.mp3",  # временно, пока нет файла
	"враг_яд_попадание": "res://music/sfx/враг_яд_выстрел.mp3",  # временно
	"босс_суммон": "res://music/sfx/враг_яд_выстрел.mp3",  # временно
	"босс_атака_выстрел": "res://music/sfx/враг_выстрел_стрела/Bow Attack 1.wav",  # временно
}

# Кэш загруженных файлов и папок
var _sfx_files_cache: Dictionary = {}  # name -> AudioStream
var _sfx_folders_cache: Dictionary = {}  # name -> Array[AudioStream]
var _active_sfx: Dictionary = {}  # name -> Array[AudioStreamPlayer]
var _music_player: AudioStreamPlayer
var _current_music: AudioStream = null
var _is_combat: bool = false

const MAX_SFX_PER_TYPE = 3  # Максимум одновременно играющих звуков одного типа
const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_SFX_VOLUME := 1.0
const DEFAULT_MUSIC_VOLUME := 1.0

func _ready() -> void:
	_ensure_audio_buses()
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)
	
	# Предзагружаем одиночные файлы
	for key in SFX_FILES:
		_sfx_files_cache[key] = load(SFX_FILES[key])
	
	# Применяем сохранённые настройки громкости
	_load_audio_settings()
	
	play_explore()

func _load_audio_settings() -> void:
	var cfg := ConfigFile.new()
	var sfx_vol := DEFAULT_SFX_VOLUME
	var music_vol := DEFAULT_MUSIC_VOLUME
	if cfg.load(SETTINGS_PATH) == OK:
		sfx_vol = _sanitize_volume(cfg.get_value("audio", "sfx", DEFAULT_SFX_VOLUME), DEFAULT_SFX_VOLUME)
		music_vol = _sanitize_volume(cfg.get_value("audio", "music", DEFAULT_MUSIC_VOLUME), DEFAULT_MUSIC_VOLUME)
		if sfx_vol <= 0.0 and music_vol <= 0.0:
			sfx_vol = DEFAULT_SFX_VOLUME
			music_vol = DEFAULT_MUSIC_VOLUME
		cfg.set_value("audio", "sfx", sfx_vol)
		cfg.set_value("audio", "music", music_vol)
		cfg.save(SETTINGS_PATH)
	_apply_bus_volume("SFX", sfx_vol)
	_apply_bus_volume("Music", music_vol)


func _sanitize_volume(raw: Variant, fallback: float) -> float:
	var value := fallback
	if raw is int or raw is float:
		value = float(raw)
	elif raw is String and raw.is_valid_float():
		value = float(raw)
	if is_nan(value) or is_inf(value) or value < 0.0 or value > 1.0:
		return fallback
	return value


func _ensure_audio_buses() -> void:
	_ensure_audio_bus("Music")
	_ensure_audio_bus("SFX")


func _ensure_audio_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")

func _apply_bus_volume(bus_name: String, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		var normalized := _sanitize_volume(value, 1.0)
		AudioServer.set_bus_volume_db(idx, linear_to_db(normalized) if normalized > 0.0 else -80.0)
		AudioServer.set_bus_mute(idx, normalized <= 0.0)

# --- МУЗЫКА ---

func play_explore() -> void:
	if _is_combat == false and _music_player.stream == MUSIC_EXPLORE:
		return
	_is_combat = false
	_crossfade(MUSIC_EXPLORE)

func play_combat() -> void:
	if _is_combat == true and _music_player.stream == MUSIC_COMBAT:
		return
	_is_combat = true
	_crossfade(MUSIC_COMBAT)

func play_boss(boss_type: String = "skeleton_king") -> void:
	var new_stream = MUSIC_BOSS if boss_type == "skeleton_king" else MUSIC_BOSS2
	if _music_player.stream == new_stream:
		return
	_is_combat = true
	_crossfade(new_stream)

func _crossfade(new_stream: AudioStream) -> void:
	if new_stream == null:
		return
	
	# Если та же музыка уже играет - не делаем ничего
	if _music_player.stream == new_stream and _music_player.playing:
		return
	
	# Если это первый запуск или плеер остановлен - играем сразу
	if _music_player.stream == null or not _music_player.playing:
		_music_player.stream = new_stream
		_music_player.volume_db = 0.0
		_music_player.play()
		_current_music = new_stream
		return
	
	# Затухание текущей музыки
	var tween = create_tween()
	tween.tween_property(_music_player, "volume_db", -40.0, 1.0)
	await tween.finished
	
	# Переключаем на новую музыку
	_music_player.stream = new_stream
	_music_player.play()
	_current_music = new_stream
	
	# Нарастание новой музыки
	var tween2 = create_tween()
	tween2.tween_property(_music_player, "volume_db", 0.0, 1.0)

func restart_music() -> void:
	# Перезапускает музыку (полезно после загрузки сохранения)
	if _current_music == null:
		_current_music = MUSIC_EXPLORE
	
	_music_player.stop()
	_music_player.stream = _current_music
	_music_player.volume_db = 0.0
	_music_player.play()

func stop_music() -> void:
	var tween = create_tween()
	tween.tween_property(_music_player, "volume_db", -40.0, 0.5)
	await tween.finished
	_music_player.stop()
	_is_combat = false

# --- SFX (АСИНХРОННОЕ ПРОИГРЫВАНИЕ) ---

func play_sfx(sfx_name: String) -> void:
	# Инициализируем массив если нужно
	if not _active_sfx.has(sfx_name):
		_active_sfx[sfx_name] = []
	
	var active: Array = _active_sfx[sfx_name]
	
	# Удаляем завершённые звуки из отслеживания
	active = active.filter(func(p): return p and is_instance_valid(p) and p.playing)
	_active_sfx[sfx_name] = active
	
	# ВАЖНО: Используем MAX_SFX_PER_TYPE, чтобы не спамить звуками
	# Дляигрок_атакаограничиваем до одного одновременно
	var limit := MAX_SFX_PER_TYPE
	if sfx_name == "игрок_атака":
		limit = 1
	if active.size() >= limit:
		return # Если уже играют нужное количество звуков, новый не играем
	
	# Создаём новый плеер
	var stream = _get_sfx_stream(sfx_name)
	if stream == null:
		return
	
	var player = AudioStreamPlayer.new()
	player.bus = "SFX"
	player.stream = stream
	add_child(player)
	player.play()
	active.append(player)
	
	# Удаляем плеер после окончания
	player.finished.connect(func():
		if is_instance_valid(player):
			player.queue_free()
		if _active_sfx.has(sfx_name):
			_active_sfx[sfx_name].erase(player)
	)

func _get_sfx_stream(sfx_name: String) -> AudioStream:
	# Сначала проверяем кэш файлов
	if _sfx_files_cache.has(sfx_name):
		return _sfx_files_cache[sfx_name]
	
	# Проверяем папки
	if SFX_FOLDERS.has(sfx_name):
		return _get_random_from_folder(sfx_name, SFX_FOLDERS[sfx_name])
	
	return null

func _get_random_from_folder(cache_key: String, folder_path: String) -> AudioStream:
	# Если папка уже загружена - берём рандомный
	if _sfx_folders_cache.has(cache_key):
		var cached_files: Array = _sfx_folders_cache[cache_key]
		if cached_files.is_empty():
			return null
		return cached_files[randi() % cached_files.size()]
	
	# Загружаем папку
	var loaded_files: Array[AudioStream] = []
	var dir = DirAccess.open(folder_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and _is_audio_file(file_name):
				var stream = load(folder_path + file_name)
				if stream:
					loaded_files.append(stream)
			file_name = dir.get_next()
		dir.list_dir_end()
	
	_sfx_folders_cache[cache_key] = loaded_files
	
	if loaded_files.is_empty():
		return null
	return loaded_files[randi() % loaded_files.size()]


func _is_audio_file(file_name: String) -> bool:
	var lower := file_name.to_lower()
	return lower.ends_with(".wav") or lower.ends_with(".mp3") or lower.ends_with(".ogg")
