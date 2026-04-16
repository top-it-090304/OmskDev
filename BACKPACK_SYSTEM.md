# Система рюкзака (Backpack System)

Полноценная система инвентаря в стиле The Binding of Isaac для отображения собранных артефактов.

## Компоненты системы

### 1. Backpack (scene/game_objects/player/backpack.gd)
Основной UI компонент, отображающий собранные артефакты в виде сетки иконок.

**Настройки:**
- `grid_columns: int = 8` - количество колонок в сетке
- `icon_size: int = 32` - размер каждой иконки в пикселях
- `icon_spacing: int = 4` - отступ между иконками

**Функции:**
- `add_artefact(artefact_data)` - добавляет артефакт в рюкзак
- `get_artefact_count() -> int` - возвращает количество собранных артефактов
- `has_artefact(name: String) -> bool` - проверяет наличие артефакта по имени
- `clear_backpack()` - очищает весь рюкзак

### 2. Создание артефактов

Каждый артефакт должен иметь следующие экспортируемые переменные:

```gdscript
@export var artefact_name: String = "Название"
@export var artefact_icon: Texture2D  # Иконка для рюкзака
@export var artefact_description: String = "Описание эффекта"
```

**Пример артефакта (boots_of_travel.gd):**

```gdscript
extends Node2D

@export var artefact_name: String = "Boots of Travel"
@export var artefact_icon: Texture2D
@export var artefact_description: String = "+70 к скорости"
@export var speed_bonus: int = 70

func _ready():
    # Автоматически получаем иконку из Sprite2D
    if not artefact_icon and has_node("Sprite2D"):
        var sprite = get_node("Sprite2D")
        if sprite.texture:
            artefact_icon = sprite.texture

func _on_area_2d_area_entered(area: Area2D) -> void:
    if area.get_parent().is_in_group("player"):
        var player = area.get_parent()
        pickup(player)

func pickup(player: Node) -> void:
    # Применяем эффект
    GameConstants.PLAYER_MAX_SPEED += speed_bonus
    
    # Добавляем в рюкзак
    var backpack = get_tree().get_first_node_in_group("backpack")
    if backpack and backpack.has_method("add_artefact"):
        backpack.add_artefact(self)
    
    queue_free()
```

### 3. Структура сцены артефакта

```
Node2D (скрипт артефакта)
├── Area2D (collision_mask = 9 для детекции игрока)
│   └── CollisionShape2D
└── Sprite2D (текстура артефакта)
```

**Важно:** Подключите сигнал `area_entered` от Area2D к методу `_on_area_2d_area_entered`

## Особенности

1. **Автоматическое получение иконки** - если `artefact_icon` не задана, система автоматически использует текстуру из Sprite2D

2. **Анимация появления** - каждая новая иконка появляется с анимацией увеличения и fade-in

3. **Tooltip** - при наведении на иконку показывается название и описание артефакта

4. **Автоматическое переполнение** - когда заполняется 8 колонок, новые иконки автоматически добавляются в следующий ряд

5. **Стилизация** - темный фон с рамкой для каждой иконки

## Интеграция в проект

Backpack уже добавлен в `World/layer.tscn` в UI слой и находится в правом верхнем углу экрана.

## Примеры артефактов

- **Boots of Travel** (`artefact(boots_of_travel).gd`) - увеличивает скорость на 70
- **Health Ring** (`artefact_health_ring.gd`) - увеличивает максимальное здоровье на 50

## Создание нового артефакта

1. Создайте новую сцену с Node2D
2. Добавьте Area2D с CollisionShape2D
3. Добавьте Sprite2D с текстурой
4. Создайте скрипт по примеру выше
5. Настройте экспортируемые переменные
6. Подключите сигнал area_entered

Готово! Артефакт автоматически появится в рюкзаке при подборе.
