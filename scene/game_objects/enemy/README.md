# Enemy — Враги

Папка содержит сцены и скрипты обычных врагов.

---

## Типы врагов

| Враг | Файл | HP | Урон | Скорость | Особенность |
|------|------|-----|------|----------|-------------|
| Goblin Axe | `enemy(goblin_axe).gd` | 70 | 10 | 150 | Ближний бой, Smite |
| Skeleton Bow | `skeleton_bow.gd` | 50 | 20 | 70-160 | Стрельба луком |
| Goblin Slinger | `goblin_slinger.gd` | 60 | 12 | 80-140 | Ядовитые снаряды |

---

## Общая архитектура врага

Все враги наследуют общую структуру:

```gdscript
extends CharacterBody2D

# Параметры (масштабируются)
var hp = 0
var max_speed = 0.0
var damage = 0

# Ссылки
var player: Node2D
var parent_node: Node  # Container "Enemys" в комнате
var room_node: Node2D  # Сама комната

# Состояния
var can_move = true
var can_attack = false
var player_in_range = false
var is_dead = false
var can_anim = true

# Направления
enum Dir { DOWN, UP, LEFT, RIGHT }
var current_dir: Dir
```

---

## Жизненный цикл врага

### 1. Спавн (`map_manager.gd`)
```gdscript
_spawn_enemies_after_physics():
	enemy = enemy_scene.instantiate()
	enemys_container.add_child(enemy)
```

### 2. Инициализация (`_ready()`)
```gdscript
hp = GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_..._HP)
max_speed = GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_..._SPEED)
player = get_tree().get_first_node_in_group("player")
```

### 3. Обновление (`_physics_process()`)
```gdscript
if is_dead: return

# Если агрессивный и игрок в зоне атаки
if is_aggressive and player_in_range and can_attack:
	attack()

# Движение к игроку
if is_aggressive and get_closer:
	velocity = direction * max_speed
```

### 4. Получение урона (`take_damage()`)
```gdscript
hp -= amount
hp_bar.update_hp(hp, max_hp)

if hp <= 0:
	death()
	return

# Прервать анимацию, показать hurt
```

### 5. Смерть (`death()`)
```gdscript
is_dead = true
can_move = false
can_attack = false

# Анимация смерти
await anim.animation_finished

# Выдать опыт
_give_exp_to_player()

# Спавнуть лут (25% шанс)
if randf() <= 0.25:
	_spawn_loot()

queue_free()
```

---

## Детекторы зон

### Зона обнаружения (`detector`)
- Area2D с CollisionShape2D
- При входе игрока: `player_in_range = true`
- При выходе: `player_in_range = false`

### Зона атаки (`hitbox`)
- Area2D для контакта с игроком
- Наносит урон при столкновении

---

## Гайд для агентов

### Как добавить нового врага
1. Создайте сцену врага в `scene/game_objects/enemy/`
2. Добавьте скрипт с общей структурой (см. выше)
3. Добавьте константы в `game_constants.gd`:
```gdscript
var ENEMY_NEW_TYPE_HP = 100
var ENEMY_NEW_TYPE_DAMAGE = 15
var ENEMY_NEW_TYPE_SPEED = 120
var ENEMY_NEW_TYPE_EXP_REWARD = 25
```
4. Добавьте в `map_manager.gd`:
```gdscript
@export var enemy_variations: Array[PackedScene] = []
# Добавьте сцену нового врага в массив
```

### Как изменить характеристики врага
```gdscript
# В game_constants.gd
ENEMY_GOBLIN_AXE_HP = 100  # Было 70

# Или динамически
GameConstants.set_stat("ENEMY_GOBLIN_AXE_HP", 100, true)
```

### Как изменить масштабирование врагов
```gdscript
# В game_constants.gd
ENEMY_LEVEL_SCALING = 0.20  # Было 0.15 (+20% за уровень вместо +15%)
```

### Как добавить новую атаку
```gdscript
# В enemy.gd
func attack():
	if not can_attack or not player_in_range: return
	
	can_attack = false
	can_move = false
	
	# Анимация атаки
	match current_dir:
		Dir.UP: animP.play("attack_up")
		# ...
	
	await animP.animation_finished
	
	# Логика атаки
	spawn_projectile()  # Или melee_attack()
	
	# Перезапуск таймера
	if not is_dead:
		can_move = true
		attack_timer.start()
```

### Как добавить снаряд
```gdscript
# В game_constants.gd
const ENEMY_NEW_PROJECTILE = preload("res://scene/game_objects/enemy/.../projectile.tscn")

# В enemy.gd
func shoot_projectile():
	var projectile = GameConstants.ENEMY_NEW_PROJECTILE.instantiate()
	projectile.global_position = global_position
	
	var target_dir = (player.global_position - global_position).normalized()
	projectile.direction = target_dir
	projectile.rotation = target_dir.angle()
	
	get_tree().current_scene.add_child.call_deferred(projectile)
```

---

## Зависимости

- Все враги → `GameConstants` (для статов и масштабирования)
- Все враги → `player` (для атаки и выдачи опыта)
- Все враги → `SaveSystem` (не напрямую, но для прогресса)

---

## Примеры

### Получить все活ые враги в комнате
```gdscript
var enemys_node = room_node.find_child("Enemys")
var alive_enemies = []
for enemy in enemys_node.get_children():
	if not enemy.is_dead:
		alive_enemies.append(enemy)
```

### Проверить, зачищена ли комната
```gdscript
var enemys_node = room_node.find_child("Enemys")
var is_cleared = enemys_node.get_child_count() == 0

if is_cleared:
	GameConstants.on_room_cleared()
```

### Найти конкретного врага по типу
```gdscript
for enemy in enemys_node.get_children():
	if enemy is GoblinSlinger:
		print("Найдён Goblin Slinger!")
```
