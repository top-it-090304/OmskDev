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
	"игрок1_ходьба": "res://music/sfx/игрок1_ходьба/",
	"игрок_урон": "res://music/sfx/игрок_урон/",
	"враг_атака_ближний": "res://music/sfx/враг_атака_ближний/",
	"враг_урон": "res://music/sfx/враг_урон/",
	"враг_выстрел_стрела": "res://music/sfx/враг_выстрел_стрела/",
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

func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	add_child(_music_player)
	
	# Предзагружаем одиночные файлы
	for key in SFX_FILES:
		_sfx_files_cache[key] = load(SFX_FILES[key])
	
	play_explore()

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
	if new_stream == null or _music_player.stream == new_stream:
		return
	
	# Если это первый запуск - играем сразу без затухания
	if _music_player.stream == null:
		_music_player.stream = new_stream
		_music_player.play()
		return
	
	var tween = create_tween()
	tween.tween_property(_music_player, "volume_db", -40.0, 1.0)
	await tween.finished
	_music_player.stream = new_stream
	_music_player.play()
	var tween2 = create_tween()
	tween2.tween_property(_music_player, "volume_db", 0.0, 1.0)

func stop_music() -> void:
	var tween = create_tween()
	tween.tween_property(_music_player, "volume_db", -40.0, 0.5)
	await tween.finished
	_music_player.stop()
	_is_combat = false

# --- SFX (АСИНХРОННОЕ ПРОИГРЫВАНИЕ) ---

func play_sfx(name: String) -> void:
	# Инициализируем массив если нужно
	if not _active_sfx.has(name):
		_active_sfx[name] = []
	
	var active: Array = _active_sfx[name]
	
	# Удаляем завершённые звуки из отслеживания
	active = active.filter(func(p): return p and is_instance_valid(p) and p.playing)
	_active_sfx[name] = active
	
	# ВАЖНО: Используем MAX_SFX_PER_TYPE, чтобы не спамить звуками
	# Дляигрок_атакаограничиваем до одного одновременно
	var limit := MAX_SFX_PER_TYPE
	if name == "игрок_атака":
		limit = 1
	if active.size() >= limit:
		return # Если уже играют нужное количество звуков, новый не играем
	
	# Создаём новый плеер
	var stream = _get_sfx_stream(name)
	if stream == null:
		return
	
	var player = AudioStreamPlayer.new()
	player.bus = "Master"
	player.stream = stream
	add_child(player)
	player.play()
	active.append(player)
	
	# Удаляем плеер после окончания
	player.finished.connect(func():
		if is_instance_valid(player):
			player.queue_free()
		if _active_sfx.has(name):
			_active_sfx[name].erase(player)
	)

func _get_sfx_stream(name: String) -> AudioStream:
	# Сначала проверяем кэш файлов
	if _sfx_files_cache.has(name):
		return _sfx_files_cache[name]
	
	# Проверяем папки
	if SFX_FOLDERS.has(name):
		return _get_random_from_folder(name, SFX_FOLDERS[name])
	
	return null

func _get_random_from_folder(cache_key: String, folder_path: String) -> AudioStream:
	# Если папка уже загружена - берём рандомный
	if _sfx_folders_cache.has(cache_key):
		var files: Array = _sfx_folders_cache[cache_key]
		if files.is_empty():
			return null
		return files[randi() % files.size()]
	
	# Загружаем папку
	var files: Array[AudioStream] = []
	var dir = DirAccess.open(folder_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and (file_name.ends_with(".wav") or file_name.ends_with(".mp3")):
				var stream = load(folder_path + file_name)
				if stream:
					files.append(stream)
			file_name = dir.get_next()
		dir.list_dir_end()
	
	_sfx_folders_cache[cache_key] = files
	
	if files.is_empty():
		return null
	return files[randi() % files.size()]
