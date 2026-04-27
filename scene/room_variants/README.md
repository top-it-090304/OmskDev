# Room Variants — Варианты комнат

Папка содержит сцены комнат для генерации данжена.

---

## Типы комнат

| Тип | Описание | Где используется |
|-----|----------|------------------|
| Start Room | Стартовая комната | `map_manager.start_room_variations` |
| Normal Room | Обычная комната с врагами | `map_manager.normal_room_variations` |
| Boss Room | Комната с боссом | `map_manager.boss_room_variations` |
| Treasure Room | Комната с артефактом | `map_manager.treasure_room_variations` |
| Corridor H | Горизонтальный коридор | `map_manager.corridor_h_scene` |
| Corridor V | Вертикальный коридор | `map_manager.corridor_v_scene` |

---

## Структура комнаты

```
BaseRoom0 (Node2D, класс: RoomBase)
├── TileMap (пол и стены)
├── Walls (Node2D)
│   ├── left_wall
│   ├── right_wall
│   ├── top_wall
│   └── down_wall
├── Doors (Node2D)
│   ├── left_door
│   ├── right_door
│   ├── top_door
│   └── down_door
├── Enemys (Node2D)  # Контейнер для врагов
├── Obstacles (Node2D)  # Контейнер для препятствий
└── PlayerSpawn (Marker2D)  # Точка спавна игрока
```

---

## Базовый класс: `RoomBase`

**Примечание**: В текущей версии класс `RoomBase` может отсутствовать как отдельный скрипт. Комнаты используют общую структуру через сцены.

### Методы комнаты
```gdscript
# В base_room_0.gd или аналогичном
func setup_room(has_left, has_right, has_top, has_bottom):
    # Открывает/закрывает двери
    if not has_left: close_door("left")
    if not has_right: close_door("right")
    # ...
```

---

## Двери

### Логика дверей (`door.gd`)
```gdscript
extends Node2D

var is_open = false
var is_locked = false

func open_door():
    is_open = true
    # Анимация открытия

func close_door():
    is_open = false
    # Анимация закрытия

func try_open():
    if not is_locked:
        open_door()
```

### Условия открытия
- **Все враги убиты** → двери открываются
- **Игрок вошёл** → двери закрываются (опционально)

---

## Гайд для агентов

### Как добавить новую комнату
1. Создайте сцену в `scene/room_variants/BaseRoom[0]/`:
```
new_room.tscn
├── TileMap (текстура пола)
├── Walls (стены)
├── Doors (двери с 4 сторон)
├── Enemys (контейнер)
└── Obstacles (контейнер)
```

2. Добавьте экспорты для вариативности:
```gdscript
@export var obstacle_density: float = 0.5
@export var enemy_spawn_chance: float = 0.8
```

3. Добавьте в `map_manager.gd`:
```gdscript
@export var normal_room_variations: Array[PackedScene] = []
# Перетащите новую сцену в массив
```

### Как изменить размер комнаты
```gdscript
# В game_constants.gd
MAP_MANAGER_ROOM_SIZE_X = 1024  # Было 864
MAP_MANAGER_ROOM_SIZE_Y = 768   # Было 640
```

**Важно**: После изменения размера нужно обновить:
- Позиции дверей
- Позиции маркеров спавна
- Коллизии стен

### Как добавить секретную комнату
```gdscript
# В map_manager.gd: generate_layout()
enum RoomType { ..., SECRET }

# Шанс на секретную комнату
if randf() < 0.1:  # 10% шанс
    layout[x][y] = RoomType.SECRET
```

### Как сделать комнату с ловушками
1. Добавьте в сцену комнаты:
```
Traps (Node2D)
├── Spike1 (Area2D)
├── Spike2 (Area2D)
└── MovingWall (CharacterBody2D)
```

2. Создайте скрипт ловушки:
```gdscript
extends Area2D

@export var damage: int = 10

func _on_body_entered(body: Node2D):
    if body.is_in_group("player"):
        body.take_damage(damage)
```

---

## Зависимости

- Комнаты → `map_manager.gd` (спавн, настройка)
- Комнаты → `door.gd` (логика дверей)
- Комнаты → `GameConstants` (размеры)

---

## Примеры

### Проверить, зачищена ли комната
```gdscript
var enemys_node = room_node.find_child("Enemys")
var is_cleared = enemys_node.get_child_count() == 0

if is_cleared:
    open_all_doors()
```

### Открыть все двери
```gdscript
func open_all_doors():
    for door in $Doors.get_children():
        if door.has_method("open_door"):
            door.open_door()
```

### Найти комнату по типу
```gdscript
var map_manager = get_tree().get_first_node_in_group("map_manager")
for room_data in map_manager.spawned_rooms:
    if room_data.type == RoomType.BOSS:
        print("Босс в позиции: ", room_data.grid_pos)
```
