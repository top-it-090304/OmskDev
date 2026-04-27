# Artefacts — Артефакты

Папка содержит 30+ артефактов с уникальными эффектами.

---

## Архитектура

### Базовый класс: `artefact_base.gd`
```gdscript
class_name ArtefactBase
extends Node2D

@export var artefact_name: String
@export var artefact_icon: Texture2D
@export var artefact_description: String

signal picked_up(artefact: ArtefactBase)

func apply_effect(player: Node) -> void:
    # Переопределяется в наследниках
    pass
```

### Наследники (примеры)
| Артефакт | Файл | Эффект |
|----------|------|--------|
| Red Potion | `red_potion.gd` | +50 HP, +2 урона |
| Boots of Travel | `artefact(boots_of_travel).tscn` | (базовый класс) |
| Crown | `crown.gd` | (наследуется) |
| Diamond | `diamond.gd` | (наследуется) |
| ... | 28+ файлов | Разные эффекты |

---

## Жизненный цикл артефакта

### 1. Спавн в Treasure Room
```gdscript
# В map_manager.gd: _spawn_treasure_items()
item_scene = _get_next_treasure_item()
item_instance = item_scene.instantiate()
room_node.add_child(item_instance)
item_instance.global_position = room_node.to_global(center)
```

### 2. Подбор игроком
```gdscript
# В artefact_base.gd: _on_area_entered()
func _on_area_entered(area: Area2D):
    if area.get_parent().is_in_group("player"):
        pickup(player)

func pickup(player: Node):
    apply_effect(player)      # Применить эффект
    backpack.add_artefact(self)  # Добавить в рюкзак
    mark_room_as_collected()  # Отметить комнату
    queue_free()              # Удалить с карты
```

### 3. Сохранение
```gdscript
# В save_system.gd
collected_artefacts = [
    {"name": "Red Potion", "icon_path": "...", "description": "..."},
    ...
]
```

---

## Система колоды

### "Колода" артефактов (`map_manager.gd`)
```gdscript
var item_draw_pile: Array[PackedScene] = []

func _get_next_treasure_item() -> PackedScene:
    if item_draw_pile.is_empty():
        item_draw_pile = treasure_items.duplicate()
        item_draw_pile.shuffle()
    
    return item_draw_pile.pop_back()
```

**Как работает**:
1. При старте данжена колода пуста
2. При первом запросе копируем `treasure_items` и перемешиваем
3. Выдаём артефакты по одному (pop_back)
4. Когда колода заканчивается — снова копируем и перемешиваем

---

## Гайд для агентов

### Как добавить новый артефакт
1. Создайте сцену в `scene/pick_up/artefacts/`:
```
my_artefact.tscn
├── Sprite2D (иконка)
└── Area2D (для подбора)
```

2. Создайте скрипт:
```gdscript
extends ArtefactBase

func _ready():
    artefact_name = "My Artefact"
    artefact_description = "Описание эффекта"
    # Иконка берётся из Sprite2D автоматически

func apply_effect(player: Node) -> void:
    # Применить эффект
    GameConstants.PLAYER_ATTACK_DAMAGE += 5
    GameConstants.constants_changed.emit()
```

3. Добавьте сцену в `map_manager.gd`:
```gdscript
@export var treasure_items: Array[PackedScene] = []
# Перетащите сцену в массив в инспекторе
```

### Как сделать артефакт с пассивным эффектом
```gdscript
# В artefact_my.gd
extends ArtefactBase

func apply_effect(player: Node):
    # Постоянный эффект (например, +скорость)
    GameConstants.PLAYER_MAX_SPEED += 50
    GameConstants.constants_changed.emit()
```

### Как сделать артефакт с активацией
```gdscript
# В artefact_my.gd
extends ArtefactBase

var is_active = false

func apply_effect(player: Node):
    # Сохранить ссылку на игрока
    self.player = player

func activate():
    if not is_active:
        is_active = true
        # Эффект активации
```

### Как изменить шанс выпадения
Артефакты выдаются из колоды равномерно. Для изменения шансов:
```gdscript
# В map_manager.gd: _get_next_treasure_item()
# Добавьте веса
var weights = {
    "rare_artefact": 0.1,
    "common_artefact": 0.9
}
```

---

## Интеграция с другими системами

### Рюкзак (`backpack.gd`)
- Отображает иконки артефактов в сетке
- Показывает tooltip с названием и описанием
- Анимация появления

### Сохранения (`save_system.gd`)
- Сохраняет названия, иконки, описания
- Восстанавливает при загрузке

### Игрок (`player.gd`)
- Получает эффекты от артефактов
- Некоторые артефакты могут влиять на статы напрямую

---

## Список всех артефактов

```
artefact(boots_of_travel).tscn
blue_shroom.tscn
clock.tscn
coffee_mug.tscn
crown.tscn
diamond.tscn
golden_cup.tscn
injector.tscn
metal_shield.tscn
old_book.tscn
red_potion.gd
bottle.gd
pill.gd
button.gd
letter.gd
waffle.gd
juice_box.gd
ramen_bowl.gd
milk_box.gd
lime_juice.gd
pill_can.gd
small_cactus.gd
snow_ball.gd
bongo.gd
flashlight.gd
vhs_cassette.gd
uno_reverse_card.gd
disco_ball.gd
fairy_bottle.gd
golden_ball.gd
top_hat.gd
electronic_key.gd
```

---

## Примеры

### Применить эффект артефакта
```gdscript
# В apply_effect()
GameConstants.PLAYER_MAX_HEALTH += 50
GameConstants.PLAYER_ATTACK_DAMAGE += 5
GameConstants.constants_changed.emit()
```

### Проверить, есть ли артефакт у игрока
```gdscript
var backpack = get_tree().get_first_node_in_group("backpack")
if backpack.has_artefact("Red Potion"):
    print("У игрока есть Red Potion!")
```

### Получить все артефакты игрока
```gdscript
var backpack = get_tree().get_first_node_in_group("backpack")
var artefacts = backpack.collected_artefacts
for artefact in artefacts:
    print(artefact.name)
```
