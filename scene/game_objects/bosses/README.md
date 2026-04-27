# Bosses — Боссы

Папка содержит сцены и скрипты боссов.

---

## Босс: Beast Goblin

**Файл**: `beast_goblin.gd`

**Характеристики**:
- HP: 150 (масштабируется)
- Урон: 30 (укус), 15 (удар)
- Скорость: 120
- Награда EXP: 50

**Особенности**:
- 3 зоны обнаружения (bite, slap, shoot)
- 3 типа атак в приоритете
- Стреляет стрелами на дистанции

---

## Архитектура босса

### Зоны обнаружения
```
Beast Goblin
├── detector_bite (Area2D)   — Ближняя зона (укус)
├── detector_slap (Area2D)   — Средняя зона (удар)
└── detector_shoot (Area2D)  — Дальняя зона (выстрел)
```

### Приоритет атак
1. **Bite** (укус) — если игрок в `detector_bite`
2. **Slap** (удар) — если игрок в `detector_slap`
3. **Shoot** (выстрел) — если игрок в `detector_shoot`

---

## Структура скрипта

```gdscript
extends CharacterBody2D

# Характеристики
var hp = 0
var speed = 0.0

# Зоны (флаги)
var player_in_bite_zone = false
var player_in_slap_zone = false
var player_in_shoot_zone = false

# Состояния
var can_walk = true
var can_attack = true
var is_attacking = false  # Блокирует повторные вызовы
var is_dead = false

# Анимации
@onready var anim = $AnimatedSprite2D
@onready var animP = $AnimationPlayer
@onready var hp_bar = $TextureProgressBar
```

---

## Система атак

### Bite (Укус)
```gdscript
func spawn_bite_swing():
    smite_instance = GameConstants.ENEMY_GOBLIN_AXE_SMITE.instantiate()
    get_tree().current_scene.add_child(smite_instance)
    smite_instance.global_position = global_position + direction * 35

func activate_bite():
    smite_instance.visible = true
    smite_instance.monitoring = true
```

### Slap (Удар)
- Area2D `_on_slap_body_entered()`
- Наносит урон + knockback (800.0)

### Shoot (Выстрел)
```gdscript
func shoot():
    var arrow = GameConstants.SKELETON_BOW_ARROW.instantiate()
    arrow.global_position = global_position
    arrow.direction = (player.global_position - global_position).normalized()
    arrow.rotation = arrow.direction.angle()
    get_tree().current_scene.add_child(arrow)
```

---

## Жизненный цикл

### 1. Инициализация
```gdscript
func _ready():
    hp = GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_BEASTGOBLIN_HP)
    speed = GameConstants.get_scaled_enemy_stat(GameConstants.ENEMY_BEASTGOBLIN_MAX_SPEED)
    attack_timer.one_shot = true
```

### 2. Обновление
```gdscript
func _physics_process(delta):
    if is_dead: return
    
    var is_aggressive = parent_node and parent_node.get("aggression")
    
    if can_walk and player and is_aggressive:
        # Движение к игроку
        if not (player_in_bite_zone or player_in_slap_zone):
            velocity = direction * speed
        
        # Приоритет атак
        if can_attack and not is_attacking:
            if player_in_bite_zone:
                attack("bite")
            elif player_in_slap_zone:
                attack("slap")
            elif player_in_shoot_zone:
                attack("shoot")
```

### 3. Атака
```gdscript
func attack(type: String):
    if not can_attack or is_dead or is_attacking: return
    
    is_attacking = true
    can_attack = false
    can_walk = false
    can_anim = false
    
    # Анимация
    var anim_name = type + "_" + _get_dir_string()
    animP.play(anim_name)
    await animP.animation_finished
    
    _reset_after_attack()

func _reset_after_attack():
    is_attacking = false
    can_walk = true
    can_anim = true
    _play_idle_animation()
    attack_timer.start()
```

### 4. Смерть
```gdscript
func death():
    is_dead = true
    anim.play("death_" + _get_dir_string())
    await anim.animation_finished
    
    _give_exp_to_player()
    
    # 75% шанс лута (выше чем у обычных врагов)
    if randf() <= 0.75:
        _spawn_loot()
    
    queue_free()
```

---

## Гайд для агентов

### Как добавить нового босса
1. Создайте сцену босса в `scene/game_objects/bosses/`
2. Добавьте константы в `game_constants.gd`:
```gdscript
var ENEMY_NEW_BOSS_HP = 200
var ENEMY_NEW_BOSS_DAMAGE = 40
var ENEMY_NEW_BOSS_SPEED = 100
var ENEMY_NEW_BOSS_EXP_REWARD = 100
```
3. Добавьте в `map_manager.gd`:
```gdscript
@export var boss_variations: Array[PackedScene] = []
```

### Как добавить новую атаку боссу
1. Добавьте зону обнаружения:
```gdscript
var player_in_new_zone = false
func _on_detector_new_body_entered(body):
    if body.is_in_group("player"): player_in_new_zone = true
```
2. Добавьте логику в `attack()`:
```gdscript
if player_in_new_zone:
    attack("new_attack")
```
3. Создайте анимацию `new_attack_up/down/left/right`

### Как изменить баланс босса
```gdscript
# В game_constants.gd
ENEMY_BEASTGOBLIN_HP = 200  # Было 150
ENEMY_BEASTGOBLIN_BITE_DAMAGE = 40  # Было 30
```

### Как добавить фазы боссу
```gdscript
var current_phase = 1
var phase_threshold = 0.5  # 50% HP

func take_damage(amount):
    hp -= amount
    
    # Смена фазы
    if hp < max_hp * phase_threshold and current_phase == 1:
        current_phase = 2
        on_phase_change()
    
    if hp <= 0:
        death()

func on_phase_change():
    speed *= 1.5
    attack_timer.wait_time /= 2
```

---

## Зависимости

- `beast_goblin.gd` → `GameConstants` (статы, масштабирование)
- `beast_goblin.gd` → `player` (атака, опыт)
- `beast_goblin.gd` → `SKELETON_BOW_ARROW` (снаряд для выстрела)

---

## Примеры

### Проверить, жив ли босс
```gdscript
var boss = get_tree().get_first_node_in_group("boss")
if boss and not boss.is_dead:
    # Босс ещё жив
```

### Получить текущую фазу (если добавлено)
```gdscript
var phase = boss.current_phase
if phase == 2:
    print("Босс в ярости!")
```
