extends Control

@onready var sound_slider: HSlider = $VBoxContainer/SoundRow/Slider
@onready var music_slider: HSlider = $VBoxContainer/MusicRow/Slider
@onready var lang_option: OptionButton = $VBoxContainer/LangRow/OptionButton
@onready var particles_check: CheckButton = $VBoxContainer/ParticlesRow/CheckButton

const LANGS = ["ru", "en", "az"]
const CFG_PATH = "user://settings.cfg"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return
	sound_slider.value = float(cfg.get_value("audio", "sfx", 1.0))
	music_slider.value = float(cfg.get_value("audio", "music", 1.0))
	var lang: String = str(cfg.get_value("settings", "language", "ru"))
	lang_option.selected = LANGS.find(lang) if LANGS.has(lang) else 0
	# Загружаем настройку частиц
	particles_check.button_pressed = GameConstants.variant_to_bool(cfg.get_value("graphics", "show_particles", true))
	# Применяем загруженные настройки громкости
	_apply_bus("SFX", sound_slider.value)
	_apply_bus("Music", music_slider.value)

func _on_sound_changed(value: float) -> void:
	_apply_bus("SFX", value)
	# Сохраняем немедленно для применения
	_save_setting("audio", "sfx", value)

func _on_music_changed(value: float) -> void:
	_apply_bus("Music", value)
	# Сохраняем немедленно для применения
	_save_setting("audio", "music", value)

func _save_setting(section: String, key: String, value) -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)
	cfg.set_value(section, key, value)
	cfg.save(CFG_PATH)

func _on_lang_selected(_idx: int) -> void:
	pass  # applied on save

func _on_particles_toggled(button_pressed: bool) -> void:
	_save_setting("graphics", "show_particles", button_pressed)
	# Обновляем глобальную настройку
	if GameConstants:
		GameConstants.show_particles = button_pressed

func _apply_bus(bus_name: String, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(value) if value > 0 else -80.0)
		AudioServer.set_bus_mute(idx, value == 0.0)

func _on_back_pressed() -> void:
	queue_free()

func _on_controls_pressed() -> void:
	# Сохраняем откуда зашли
	_save_came_from_scene()
	
	# Сохраняем состояние игрока перед сменой сцены
	_save_player_state()
	
	# Снимаем паузу
	get_tree().paused = false
	
	# Закрываем настройки
	queue_free()
	
	# Меняем сцену на тестовую комнату
	get_tree().change_scene_to_file("res://World/joystick_test_room.tscn")

func _save_came_from_scene() -> void:
	# Определяем текущую сцену
	var current_scene = get_tree().current_scene
	var scene_path = ""
	
	if current_scene:
		scene_path = current_scene.scene_file_path
		
		# Если это уже настройки - берём родительскую сцену
		if scene_path.contains("settings"):
			# Проверяем есть ли игрок (значит зашли из игры)
			var player = get_tree().get_first_node_in_group("player")
			if player:
				scene_path = "res://World/layer.tscn"
			else:
				scene_path = "res://World/UI/menu.tscn"
	
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)
	cfg.set_value("joystick_edit", "came_from_scene", scene_path)
	cfg.save(CFG_PATH)

func _save_player_state() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var state = {
		"health": player.health_int,
		"level": player.current_level,
		"exp": player.current_exp,
		"exp_to_next": player.exp_to_next_level,
		"position_x": player.global_position.x,
		"position_y": player.global_position.y,
		"is_poisoned": player.is_poisoned,
		"poison_timer": player.poison_timer,
		"poison_damage": player.poison_damage_per_tick
	}
	
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)
	cfg.set_value("player_state", "saved_state", state)
	cfg.save(CFG_PATH)
