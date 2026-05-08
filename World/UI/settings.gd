extends Control

@onready var sound_slider: HSlider = $VBoxContainer/SoundRow/Slider
@onready var music_slider: HSlider = $VBoxContainer/MusicRow/Slider
@onready var lang_option: OptionButton = $VBoxContainer/LangRow/OptionButton

const LANGS = ["ru", "en", "az"]
const CFG_PATH = "user://settings.cfg"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_load_settings()

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return
	sound_slider.value = float(cfg.get_value("audio", "sfx", 1.0))
	music_slider.value = float(cfg.get_value("audio", "music", 1.0))
	var lang: String = str(cfg.get_value("settings", "language", "ru"))
	lang_option.selected = LANGS.find(lang) if LANGS.has(lang) else 0

func _on_sound_changed(value: float) -> void:
	_apply_bus("SFX", value)

func _on_music_changed(value: float) -> void:
	_apply_bus("Music", value)

func _on_lang_selected(_idx: int) -> void:
	pass  # applied on save

func _on_save_pressed() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)
	cfg.set_value("audio", "sfx", sound_slider.value)
	cfg.set_value("audio", "music", music_slider.value)
	var lang: String = LANGS[lang_option.selected]
	cfg.set_value("settings", "language", lang)
	cfg.save(CFG_PATH)
	_apply_bus("SFX", sound_slider.value)
	_apply_bus("Music", music_slider.value)
	LocalizationManager.set_language(lang)

func _apply_bus(bus_name: String, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(value) if value > 0 else -80.0)
		AudioServer.set_bus_mute(idx, value == 0.0)

func _on_back_pressed() -> void:
	get_tree().paused = false
	queue_free()
