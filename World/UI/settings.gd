extends Control

@onready var music_slider: HSlider = $VBoxContainer/HBoxContainer_Music/MusicSlider
@onready var sfx_slider: HSlider = $VBoxContainer/HBoxContainer_SFX/SFXSlider
@onready var language_option: OptionButton = $VBoxContainer/HBoxContainer_Language/LanguageOption
@onready var back_button: TextureButton = $VBoxContainer/TextureButton_Back
@onready var settings: Node = get_node("/root/Settings")

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    # Ставим игру на паузу при открытии меню настроек
    get_tree().paused = true
    
    # Initialize sliders with saved values
    music_slider.value = settings.music_volume
    sfx_slider.value = settings.sfx_volume
    
    # Populate language options
    language_option.clear()
    language_option.add_item("English", 0)
    language_option.add_item("Русский", 1)
    language_option.add_item("Azərbaycan", 2)
    
    # Set current language
    match settings.current_language:
        "en":
            language_option.select(0)
        "ru":
            language_option.select(1)
        "az":
            language_option.select(2)
        _:
            language_option.select(0)  # Default to English
    
    # Connect signals
    music_slider.connect("value_changed", Callable(self, "_on_music_slider_changed"))
    sfx_slider.connect("value_changed", Callable(self, "_on_sfx_slider_changed"))
    language_option.connect("item_selected", Callable(self, "_on_language_changed"))
    back_button.connect("pressed", Callable(self, "_on_back_button_pressed"))

func _on_music_slider_changed(value: float) -> void:
    settings.set_music_volume(value)

func _on_sfx_slider_changed(value: float) -> void:
    settings.set_sfx_volume(value)

func _on_language_changed(index: int) -> void:
    var lang_code: String
    match index:
        0:
            lang_code = "en"
        1:
            lang_code = "ru"
        2:
            lang_code = "az"
        _:
            lang_code = "en"
    settings.set_language(lang_code)

func _on_back_button_pressed() -> void:
    # Возобновляем игру при закрытии настроек
    get_tree().paused = false
    queue_free()