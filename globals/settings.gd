extends Node

# Settings singleton for managing audio volumes and language
const MUSIC_BUS = "Master/Music"
const SFX_BUS = "Master/SFX"

var music_volume: float = 0.75
var sfx_volume: float = 0.75
var current_language: String = "en"  # en, ru, az

func _ready() -> void:
    # Load saved settings
    load_settings()
    # Apply initial volumes
    apply_volumes()
    # Apply initial language
    apply_language()

func save_settings() -> void:
    var data = {
        "music_volume": music_volume,
        "sfx_volume": sfx_volume,
        "language": current_language
    }
    var file = FileAccess.open("user://settings.save", FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data, "\t"))
        file.close()
        print("Settings saved")
    else:
        push_error("Cannot open settings file for writing")

func load_settings() -> void:
    if not FileAccess.file_exists("user://settings.save"):
        # First run, use defaults
        return
    var file = FileAccess.open("user://settings.save", FileAccess.READ)
    if not file:
        push_error("Cannot open settings file for reading")
        return
    var json_string = file.get_as_text()
    file.close()
    var json = JSON.new()
    var result = json.parse(json_string)
    if result != OK:
        push_error("Failed to parse settings: " + json.get_error_message())
        return
    var data = json.data
    music_volume = data.get("music_volume", 0.75)
    sfx_volume = data.get("sfx_volume", 0.75)
    current_language = data.get("language", "en")
    print("Settings loaded: music=", music_volume, " sfx=", sfx_volume, " lang=", current_language)

func apply_volumes() -> void:
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MUSIC_BUS), linear_to_db(music_volume))
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index(SFX_BUS), linear_to_db(sfx_volume))
    print("Applied volumes: music=", music_volume, " sfx=", sfx_volume)

func set_music_volume(volume: float) -> void:
    music_volume = clamp(volume, 0.0, 1.0)
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MUSIC_BUS), linear_to_db(music_volume))
    save_settings()

func set_sfx_volume(volume: float) -> void:
    sfx_volume = clamp(volume, 0.0, 1.0)
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index(SFX_BUS), linear_to_db(sfx_volume))
    save_settings()

func set_language(lang_code: String) -> void:
    # lang_code: "en", "ru", "az"
    if lang_code == current_language:
        return
    current_language = lang_code
    apply_language()
    save_settings()

func apply_language() -> void:
    var translation_file = "res://translations/" + current_language + ".csv"
    if FileAccess.file_exists(translation_file):
        var translation = Translation.new()
        var err = translation.load_from_csv(translation_file)
        if err == OK:
            TranslationServer.set_locale("custom")
            TranslationServer.add_translation(translation)
            print("Language set to: ", current_language)
        else:
            push_error("Failed to load translation: " + translation_file)
    else:
        push_error("Translation file not found: " + translation_file)

func linear_to_db(value: float) -> float:
    if value <= 0.0:
        return -80.0
    return AudioServer.linear_to_db(value)