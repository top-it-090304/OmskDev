# UI — Элементы интерфейса

Папка содержит UI компоненты для игрового процесса.

---

## Файлы

### `level_up_popup.gd`
**Назначение**: Всплывающее уведомление при повышении уровня.

**Гайд**:
- Спавнится в `player.gd: _show_level_up_popup()`
- Позиционируется над игроком: `global_position = player.global_position + Vector2(0, -50)`

---

### `artefact_popup.gd`
**Назначение**: Уведомление о получении артефакта.

**Использование**:
```gdscript
# В artefact_base.gd: pickup()
func pickup(player: Node):
    # ...
    show_artefact_popup()

func show_artefact_popup():
    var popup = preload("res://scene/ui/artefact_popup.tscn").instantiate()
    get_tree().current_scene.add_child(popup)
```

---

### `enemy_level_display.gd`
**Назначение**: Отображение текущего уровня врагов.

**Логика**:
```gdscript
extends Control

@onready var level_label = $LevelLabel

func _process(_delta):
    update_level_display()

func update_level_display():
    level_label.text = "%d" % GameConstants.ENEMY_LEVEL
```

**Подключение**:
- Автоматически обновляется при изменении `GameConstants.ENEMY_LEVEL`

---

## Гайд для агентов

### Как добавить новый UI элемент
1. Создайте сцену в `scene/ui/`:
```
new_popup.tscn
├── Panel (фон)
├── Label (текст)
└── AnimationPlayer (опционально)
```

2. Создайте скрипт:
```gdscript
extends Control

func _ready():
    # Автоскрытие через 2 секунды
    await get_tree().create_timer(2.0).timeout
    queue_free()
```

### Как показать UI из любой сцены
```gdscript
# Способ 1: Добавить в текущую сцену
var popup = preload("res://scene/ui/level_up_popup.tscn").instantiate()
get_tree().current_scene.add_child(popup)

# Способ 2: Добавить в слой UI
var ui_layer = get_tree().get_first_node_in_group("ui_layer")
if ui_layer:
    ui_layer.add_child(popup)
```

### Как создать всплывающий текст (floating combat text)
```gdscript
# floating_text.gd
extends Label

func setup(text: String, position: Vector2):
    self.text = text
    global_position = position
    
    # Анимация подъёма
    var tween = create_tween()
    tween.tween_property(self, "global_position:y", global_position.y - 50, 1.0)
    tween.tween_property(self, "modulate:a", 0.0, 1.0)
    tween.tween_callback(queue_free)
```

---

## Зависимости

- `enemy_level_display.gd` → `GameConstants` (уровень врагов)
- `level_up_popup.gd` → `player.gd` (спавн при level up)
- `artefact_popup.gd` → `artefact_base.gd` (спавн при подборе)

---

## Примеры

### Показать уведомление
```gdscript
func show_notification(message: String):
    var popup = preload("res://scene/ui/notification.tscn").instantiate()
    popup.message = message
    get_tree().current_scene.add_child(popup)
```

### Обновить UI здоровья
```gdscript
# В player.gd: health_changed сигнал
health_changed.connect(_on_health_changed)

func _on_health_changed(new_health, max_health):
    $UI/HealthBar.value = new_health
    $UI/HealthBar.max_value = max_health
```
