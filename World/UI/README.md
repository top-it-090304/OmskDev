# World/UI — Меню и интерфейс мира

Папка содержит UI элементы основного мира: меню, паузу, настройки.

---

## Файлы

### `menu.tscn` + `newgame.gd`
**Назначение**: Главное меню игры.

**Функции**:
- Новая игра
- Продолжить (если есть сохранение)
- Выход

**Логика новой игры**:
```gdscript
# В newgame.gd
func _on_new_game_pressed():
    # Сброс к базовым значениям
    SaveSystem.reset_to_base_values()
    
    # Удаление сохранений
    SaveSystem.delete_save()
    
    # Загрузка игровой сцены
    get_tree().change_scene_to_file("res://World/layer.tscn")
```

---

### `continue_button.gd`
**Назначение**: Кнопка продолжения игры.

**Логика**:
```gdscript
func _on_pressed():
    if SaveSystem.has_save():
        SaveSystem.load_game()
        get_tree().change_scene_to_file("res://World/layer.tscn")
```

---

### `paused.gd` (Control)
**Назначение**: Меню паузы.

**Группа Godot**: (нет, процесс всегда активен)

**Функции**:
- Продолжить игру
- Настройки
- Выход в главное меню

**Логика**:
```gdscript
extends Control

@export var scene_to_open: PackedScene  # Настройки
@export var target_scene = "res://World/UI/menu.tscn"

func _ready():
    process_mode = Node.PROCESS_MODE_ALWAYS
    get_tree().paused = true

func _on_texture_button_pressed():
    # Продолжить
    get_tree().paused = false
    queue_free()

func _on_texture_button_2_pressed():
    # Настройки
    var settings = scene_to_open.instantiate()
    add_child(settings)

func _on_texture_button_3_pressed():
    # Выход в меню
    SaveSystem.save_game()
    
    var map_manager = get_tree().get_first_node_in_group("map_manager")
    if map_manager:
        map_manager.save_dungeon_state()
    
    get_tree().paused = false
    get_tree().change_scene_to_file(target_scene)
```

---

### `settings.gd`
**Назначение**: Настройки игры.

**Функции**:
- Громкость музыки/SFX
- Управление
- Графические настройки (если есть)

---

### `gameover.tscn`
**Назначение**: Экран смерти игрока.

**Функции**:
- Показать причину смерти (опционально)
- Кнопка "Продолжить" (загрузить последнее сохранение)
- Кнопка "В главное меню"

---

## Гайд для агентов

### Как добавить кнопку в меню
1. Откройте `menu.tscn`
2. Добавьте `TextureButton` в иерархию
3. Подключите сигнал:
```gdscript
func _on_new_button_pressed():
    # Логика кнопки
    pass
```

### Как изменить логику паузы
```gdscript
# В paused.gd
func _on_texture_button_3_pressed():
    # Сохраняем перед выходом
    SaveSystem.save_game()
    map_manager.save_dungeon_state()
    
    # Сбрасываем флаг восстановления
    SaveSystem.should_restore_player = false
    
    # Выходим в меню
    get_tree().paused = false
    get_tree().change_scene_to_file(target_scene)
```

### Как добавить настройки громкости
```gdscript
# В settings.gd
@onready var music_slider = $MusicSlider
@onready var sfx_slider = $SFXSlider

func _ready():
    music_slider.value = AudioServer.get_bus_volume_db(0)
    sfx_slider.value = AudioServer.get_bus_volume_db(1)

func _on_music_slider_changed(value):
    AudioServer.set_bus_volume_db(0, value)

func _on_sfx_slider_changed(value):
    AudioServer.set_bus_volume_db(1, value)
```

### Как показать экран смерти
```gdscript
# В player.gd: die()
func die():
    is_dead = true
    # ... анимация смерти ...
    
    var gameover = preload("res://World/UI/gameover.tscn").instantiate()
    add_child(gameover)
```

---

## Зависимости

- `paused.gd` → `SaveSystem` (сохранение при выходе)
- `paused.gd` → `map_manager` (сохранение данжена)
- `newgame.gd` → `SaveSystem` (сброс сохранений)
- `continue_button.gd` → `SaveSystem` (загрузка сохранения)

---

## Примеры

### Сохранить перед выходом
```gdscript
func exit_to_menu():
    # Сохраняем игру
    SaveSystem.save_game()
    
    # Сохраняем состояние данжена
    var map_manager = get_tree().get_first_node_in_group("map_manager")
    if map_manager and map_manager.has_method("save_dungeon_state"):
        map_manager.save_dungeon_state()
    
    # Выходим
    get_tree().paused = false
    get_tree().change_scene_to_file("res://World/UI/menu.tscn")
```

### Проверить наличие сохранения для кнопки "Продолжить"
```gdscript
func _ready():
    var continue_button = $ContinueButton
    continue_button.disabled = not SaveSystem.has_save()
    
    if SaveSystem.has_save():
        continue_button.modulate = Color(1, 1, 1, 1)
    else:
        continue_button.modulate = Color(0.5, 0.5, 0.5, 0.5)
```
