# World — Основной мир и генерация данжена

Папка содержит основную сцену мира, генератор данжена и связанные системы.

---

## Файлы

### `map_manager.gd` (Node2D)
**Назначение**: Процедурная генерация данжена и управление комнатами.

**Группа Godot**: `map_manager`

**Ключевые возможности**:
- Генерация карты 8x8 с использованием seed
- Спавн комнат, коридоров, препятствий и врагов
- Отслеживание посещённых/увиденных комнат
- Сохранение/загрузка состояния данжена

**Структура данных**:
```gdscript
# Типы комнат
enum RoomType { EMPTY, START, NORMAL, BOSS, TREASURE }

# Массив сгенерированных комнат
var spawned_rooms = [
    {
        "node": Node2D,          # Ссылка на инстанс комнаты
        "type": RoomType,        # Тип комнаты
        "grid_pos": Vector2i     # Позиция в сетке
    }
]

# Отслеживание
var visited_rooms = []      # Игрок заходил в комнату
var seen_rooms = []         # Видит соседние комнаты (для миникарты)
var current_room_grid_pos = Vector2i
```

**Сигналы**:
```gdscript
signal room_changed(new_grid_pos)
```

**Важные методы**:
```gdscript
# Генерация
generate_layout() -> void           # Создать структуру карты
draw_map() -> void                  # Заспавнить комнаты и коридоры
_spawn_player() -> void             # Поставить игрока в стартовую комнату
_spawn_obstacles_after_physics()    # Спавн препятствий (после физики)
_spawn_enemies_after_physics()      # Спавн врагов (после физики)
_spawn_treasure_items()             # Спавн артефактов в Treasure Room

# Навигация
change_current_room(new_x, new_y) -> void
is_valid_pos(pos) -> bool
get_random_room_of_type(type) -> Vector2i

# Сохранение
save_dungeon_state() -> void
load_dungeon_state() -> void
```

**Алгоритм генерации**:
1. Создаётся пустая сетка 8x8
2. Стартовая комната в центре (3, 3)
3. Босс в случайной позиции справа (6, Y)
4. Прокладывается путь к боссу (70% прямо, 30% поворот)
5. Добавляется 3-6 случайных нормальных комнат
6. К нормальным комнатам приклеивается **4–6** Treasure Room (до 15 попыток, перемешанные направления)

---

### `minimap.gd` (Control)
**Назначение**: Отрисовка миникарты.

**Группа Godot**: `minimap`

**Как работает**:
- Подключается к `map_manager.room_changed`
- Отрисовывает посещённые комнаты (полностью)
- Отрисовывает увиденные комнаты (контур)
- Показывает текущую позицию игрока

---

### `layer.tscn`
**Назначение**: Корневая сцена игрового мира.

**Содержит**:
- `MapManager` — генератор данжена
- `Player` — игрок
- `Minimap` — миникарта
- `UI` — игровой интерфейс (здоровье, опыт)

---

## Гайд для агентов

### Как изменить размер карты
```gdscript
# В game_constants.gd или инспекторе MapManager
MAP_MANAGER_GRID_SIZE = 10  # Было 8
```

### Как добавить новый тип комнаты
1. Добавьте сцену комнаты в `scene/room_variants/`
2. Унаследуйте от `RoomBase` (если есть базовый класс)
3. Добавьте в `map_manager.gd`:
```gdscript
@export var new_room_variations: Array[PackedScene] = []

enum RoomType { EMPTY, START, NORMAL, BOSS, TREASURE, NEW_TYPE }
```
4. Обработайте в `draw_map()` и `generate_layout()`

### Как изменить логику генерации
Отредактируйте `map_manager.gd:generate_layout()`:
```gdscript
# Пример: изменить число сокровищниц (см. map_manager.gd: treasure_count = randi_range(4, 6))
var treasure_count = randi_range(4, 6)
```

### Как получить доступ к MapManager из любой сцены
```gdscript
var map_manager = get_tree().get_first_node_in_group("map_manager")
var current_pos = map_manager.current_room_grid_pos
```

### Как изменить спавн врагов
```gdscript
# В map_manager.gd: _spawn_enemies_after_physics()
if room_type == RoomType.NORMAL:
    enemy_count = randi_range(3, 7)  # Было 2-5
```

### Как добавить препятствия
```gdscript
# В map_manager.gd: obstacle_data
@export var obstacle_data: Array[Dictionary] = [
    {"scene": preload("res://..."), "size": Vector2(32, 32)},
    # Добавьте новый тип
]
```

---

## Зависимости

- `map_manager.gd` → `GameConstants`, `SaveSystem`
- `minimap.gd` → `map_manager` (через сигнал)

---

## Примеры

### Получить все зачищенные комнаты
```gdscript
var map_manager = get_tree().get_first_node_in_group("map_manager")
var cleared = []
for room_data in map_manager.spawned_rooms:
    var enemys = room_data.node.find_child("Enemys")
    if enemys and enemys.get_child_count() == 0:
        cleared.append(room_data.grid_pos)
```

### Проверить, является ли комната боссом
```gdscript
var map_manager = get_tree().get_first_node_in_group("map_manager")
for room in map_manager.spawned_rooms:
    if room.type == map_manager.RoomType.BOSS:
        print("Босс в позиции: ", room.grid_pos)
```
