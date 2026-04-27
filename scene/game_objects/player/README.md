# Player — Игрок и компоненты

Папка содержит сцену игрока и связанные компоненты (здоровье, опыт, рюкзак).

---

## Файлы

### `player.gd` (CharacterBody2D)
**Назначение**: Основная логика игрока.

**Группа Godot**: `player`

**Ключевые возможности**:
- Движение (WASD + виртуальный джойстик)
- Атака по 4 направлениям
- Система здоровья и урона
- Система опыта и уровней
- Система отравления

**Переменные**:
```gdscript
# Здоровье
var health_int: int
var can_take_damage: bool
var last_known_max_health: int

# Состояния
var is_dead: bool
var can_move: bool
var can_attack: bool
var can_anim: bool

# Направление (enum Dir)
enum Dir { DOWN, UP, LEFT, RIGHT }
var current_dir: Dir

# Отравление
var is_poisoned: bool
var poison_timer: float
var poison_damage_per_tick: int
var poison_tick_rate: float = 0.5

# Уровни
var current_level: int = 1
var current_exp: int = 0
var exp_to_next_level: int = 100
```

**Сигналы**:
```gdscript
signal health_changed(new_health, max_health)
signal exp_changed(current_exp, exp_needed)
signal level_up(new_level)
```

**Важные методы**:
```gdscript
# Бой
attack() -> void
take_damage(amount: int) -> void
apply_knockback(source_position: Vector2, force: float) -> void
heal(amount: int) -> void

# Отравление
apply_poison(duration, damage_per_tick, tick_rate) -> void
remove_poison() -> void

# Уровни
add_experience(amount: int) -> void
level_up_player() -> void

# Анимации
update_direction(dir_vec: Vector2) -> void
play_walk_animation() -> void
play_idle_animation() -> void
```

---

### `health.gd` (Node)
**Назначение**: Компонент здоровья (опционально, если вынесено отдельно).

---

### `backpack.gd` (CharacterBody2D)
**Назначение**: Рюкзак для артефактов.

**Группа Godot**: `backpack`

**Ключевые возможности**:
- Сетка 8 колонок
- Отображение иконок артефактов
- Tooltips с описанием
- Анимация появления

**Методы**:
```gdscript
add_artefact(artefact_data) -> void
has_artefact(name: String) -> bool
get_artefact_count() -> int
clear_backpack() -> void
get_collected_artefact_names() -> Array  # Для сохранения
```

---

### `exp_bar.gd` (Control)
**Назначение**: Полоска опыта.

**Подписка**:
- `exp_changed` → обновление UI
- `level_up` → анимация повышения уровня

---

### `cooldown.gd` / `cooldownspawner.gd`
**Назначение**: Визуализация кулдаунов способностей.

---

## Гайд для агентов

### Как добавить новую способность
1. Создайте сцену способности в `scene/abilities/`
2. В `player.gd` добавьте метод:
```gdscript
func use_new_ability():
    if can_use_ability():
        # Логика способности
```

### Как изменить урон игрока
```gdscript
# В game_constants.gd
PLAYER_ATTACK_DAMAGE = 15  # Было 10

# Или через set_stat
GameConstants.set_stat("PLAYER_ATTACK_DAMAGE", 15, true)
```

### Как добавить новый статус-эффект
1. Добавьте переменные в `player.gd`:
```gdscript
var is_burned = false
var burn_timer = 0.0
```
2. Обработайте в `_process()`:
```gdscript
if is_burned:
    burn_timer -= delta
    if burn_timer <= 0:
        remove_burn()
```
3. Добавьте метод применения:
```gdscript
func apply_burn(duration, damage_per_tick):
    is_burned = true
    burn_timer = duration
```

### Как получить доступ к игроку из любой сцены
```gdscript
var player = get_tree().get_first_node_in_group("player")
player.take_damage(10)
player.add_experience(50)
```

### Как изменить скорость атаки
```gdscript
# В player.gd: attack()
attack_timer.wait_time = 0.5 / GameConstants.PLAYER_ATTACK_SPEED
```

---

## Зависимости

- `player.gd` → `GameConstants`, `SaveSystem`
- `backpack.gd` → `SaveSystem` (для сохранения артефактов)
- `exp_bar.gd` → `player` (сигналы)

---

## Примеры

### Нанести урон игроку
```gdscript
var player = get_tree().get_first_node_in_group("player")
player.take_damage(10)
```

### Выдать опыт
```gdscript
var player = get_tree().get_first_node_in_group("player")
player.add_experience(100)
```

### Применить яд
```gdscript
var player = get_tree().get_first_node_in_group("player")
player.apply_poison(
    duration = 5.0,
    damage_per_tick = 2,
    tick_rate = 0.5
)
```

### Проверить, жив ли игрок
```gdscript
var player = get_tree().get_first_node_in_group("player")
if not player.is_dead:
    # Игрок жив
```
