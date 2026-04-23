# Globals — Глобальные системы

Папка содержит узлы-синглтоны с глобальными данными игры.

---

## Файлы

### `game_constants.gd`
**Назначение**: Централизованное хранилище всех игровых констант и статов.

**Автозагрузка**: Да (добавлен в Project Settings → Autoload)

**Ключевые возможности**:
- Все характеристики игрока (HP, скорость, урон, крит, уклонение и т.д.)
- Все характеристики врагов (HP, урон, скорость, награда EXP)
- Параметры снарядов и способностей
- Система масштабирования врагов по уровням
- Автосохранение при изменении значений

**Структура данных**:
```gdscript
# Player stats (var — можно менять в runtime)
PLAYER_MAX_SPEED = 200
PLAYER_MAX_HEALTH = 200
PLAYER_ATTACK_DAMAGE = 10
PLAYER_ARMOR = 0
PLAYER_CRIT_CHANCE = 0.0
PLAYER_LIFESTEAL = 0.0

# Level system
PLAYER_LEVEL = 1
PLAYER_EXPERIENCE = 0
PLAYER_BASE_EXP_TO_LEVEL = 50
PLAYER_EXP_MULTIPLIER = 1.3

# Enemy scaling
ENEMY_LEVEL = 1
ENEMY_LEVEL_SCALING = 0.15  # +15% за уровень

# Enemy base stats
ENEMY_GOBLIN_AXE_HP = 70
SKELETON_BOW_HP = 50
GOBLIN_SLINGER_HP = 60
ENEMY_BEASTGOBLIN_HP = 150
```

**Важные методы**:
```gdscript
# Получить масштабированный стат врага
GameConstants.get_scaled_enemy_stat(base_value: float) -> int

# Повысить уровень врагов (при зачистке комнаты)
GameConstants.on_room_cleared() -> void

# Сохранить на диск
GameConstants.save_to_disk() -> void

# Загрузить с диска (автоматически при старте)
GameConstants.load_from_disk() -> void

# Установить значение с автосохранением
GameConstants.set_stat(key: String, value: Variant, persist := true) -> void
```

**Сигналы**:
```gdscript
GameConstants.constants_changed.connect(_on_constants_changed)
```

---

### `save_system.gd`
**Назначение**: Управление сохранениями игры.

**Автозагрузка**: Да

**Структура сохранения** (`user://save_game.dat`):
```json
{
  "player_stats": { /* все статы игрока */ },
  "player_progression": { /* уровень, опыт, множители */ },
  "game_progress": { /* убито врагов, зачищено комнат, уровень врагов */ },
  "player_current_health": 150,
  "player_position": { "x": 100, "y": 200, "room_x": 3, "room_y": 4 },
  "collected_artefacts": [ /* массив артефактов */ ],
  "collected_treasure_rooms": [ /* позиции комнат с собранными артефактами */ ]
}
```

**Состояние данжена** (`user://dungeon_state.dat`):
```json
{
  "generation_seed": 12345,
  "current_room_pos": { "x": 5, "y": 3 },
  "visited_rooms": [ /* посещённые комнаты */ ],
  "seen_rooms": [ /* увиденные комнаты (для миникарты) */ ],
  "cleared_rooms": [ /* зачищенные комнаты (без врагов) */ ],
  "collected_treasure_rooms": [ /* собранные артефакты */ ]
}
```

**Важные методы**:
```gdscript
# Сохранить/загрузить игру
SaveSystem.save_game() -> bool
SaveSystem.load_game() -> bool

# Проверить наличие сохранения
SaveSystem.has_save() -> bool

# Удалить сохранение
SaveSystem.delete_save() -> void

# Состояние данжена
SaveSystem.save_dungeon_data(data: Dictionary) -> bool
SaveSystem.load_dungeon_data() -> Dictionary
SaveSystem.has_dungeon_state() -> bool

# Артефакты
SaveSystem.get_collected_artefacts() -> Array
SaveSystem.mark_treasure_collected(room_pos: Vector2i) -> void
SaveSystem.is_treasure_collected(room_pos: Vector2i) -> bool

# Восстановление после загрузки
SaveSystem.restore_player_state() -> void
```

**Переменные состояния**:
```gdscript
SaveSystem.should_restore_player  # Флаг восстановления HP/позиции
SaveSystem.saved_player_health    # Сохранённое здоровье
SaveSystem.saved_player_position  # Сохранённая позиция
SaveSystem.collected_artefacts    # Массив собранных артефактов
```

---

## Гайд для агентов

### Как изменить баланс игрока
1. Откройте `game_constants.gd`
2. Найдите нужную константу (например, `PLAYER_MAX_HEALTH`)
3. Измените значение
4. Изменения применятся автоматически (файл мониторится каждые 0.5с)

### Как получить доступ к статам из любой сцены
```gdscript
# Чтение
var hp = GameConstants.PLAYER_MAX_HEALTH
var damage = GameConstants.PLAYER_ATTACK_DAMAGE

# Запись (с автосохранением)
GameConstants.set_stat("PLAYER_ATTACK_DAMAGE", 15, true)

# Без автосохранения (для временных эффектов)
GameConstants.PLAYER_ATTACK_DAMAGE = 20
GameConstants.constants_changed.emit()
```

### Как масштабировать врага
```gdscript
# В _ready() врага
hp = GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_GOBLIN_AXE_HP)
speed = GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_GOBLIN_AXE_MAX_SPEED)

# При повышении уровня врагов автоматически пересчитывается
```

### Как сохранить игру
```gdscript
# В любом месте кода
SaveSystem.save_game()

# Перед выходом в меню
SaveSystem.save_game()
map_manager.save_dungeon_state()
```

### Как восстановить состояние игрока
```gdscript
# В player.gd _ready()
if SaveSystem.should_restore_player:
    SaveSystem.restore_player_state()
```

---

## Зависимости

- `game_constants.gd` → независимый
- `save_system.gd` → зависит от `GameConstants` для загрузки статов

---

## Примеры использования

### Повышение уровня врагов при зачистке комнаты
```gdscript
# В enemy.gd при смерти
GameConstants.ENEMIES_KILLED += 1

# В map_manager.gd при очистке комнаты
GameConstants.on_room_cleared()  # Автоматически проверяет каждые 2 комнаты
```

### Добавление нового стата
1. Добавьте переменную в `game_constants.gd`:
```gdscript
var PLAYER_NEW_STAT = 0
```
2. Добавьте ключ в `_stats_keys()`:
```gdscript
"PLAYER_NEW_STAT",
```
3. Добавьте в `BASE_VALUES` в `save_system.gd`:
```gdscript
"PLAYER_NEW_STAT": 0,
```
4. Добавьте загрузку/сохранение в `save_game()`/`load_game()`
