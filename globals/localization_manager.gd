extends Node

const SAVE_KEY = "language"
const SUPPORTED = ["ru", "en", "az"]

func _ready() -> void:
	TranslationServer.set_locale(_load_saved())

func set_language(locale: String) -> void:
	if locale not in SUPPORTED:
		return
	TranslationServer.set_locale(locale)
	_save(locale)

func get_language() -> String:
	return TranslationServer.get_locale()

func _save(locale: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("settings", SAVE_KEY, locale)
	cfg.save("user://settings.cfg")

func _load_saved() -> String:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		return cfg.get_value("settings", SAVE_KEY, "ru")
	return "ru"
