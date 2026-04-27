# Abilities — Способности атаки

Папка содержит систему атаки игрока.

---

## Файлы

### `atack_ability.tscn`
**Назначение**: Визуализация зоны атаки.

**Структура**:
```
atack_ability
├── Top (Area2D)     # Атака вверх
├── Bot (Area2D)     # Атака вниз
├── Left (Area2D)    # Атака влево
└── Right (Area2D)   # Атака вправо
```

### `atack_spawn.gd`
**Назначение**: Логика активации атаки.

**Текущая проблема**: Файл содержит ошибку — в нём находится логика зелья лечения вместо атаки.

**Правильная логика должна быть**:
```gdscript
extends Node2D

@export var ability: Node
var ready_for_animation = false
var last_attack_time := 0
var cooldown := 100  # мс

func _process(delta):
    if Input.is_action_just_pressed("attack"):
        if can_attack():
            place_player()

func can_attack() -> bool:
    var current_time = Time.get_ticks_msec()
    if current_time - last_attack_time >= cooldown:
        last_attack_time = current_time
        return true
    return false

func place_player():
    var player = get_tree().get_first_node_in_group("player")
    match player.current_dir:
        player.Dir.UP: 
            ability.get_node("Top").get_node("CollisionShape2D").disabled = false
        player.Dir.DOWN:
            ability.get_node("Bot").get_node("CollisionShape2D").disabled = false
        player.Dir.LEFT:
            ability.get_node("Left").get_node("CollisionShape2D").disabled = false
        player.Dir.RIGHT:
            ability.get_node("Right").get_node("CollisionShape2D").disabled = false
    
    await get_tree().create_timer(0.05).timeout
    
    # Отключаем все зоны
    ability.get_node("Top").get_node("CollisionShape2D").disabled = true
    ability.get_node("Bot").get_node("CollisionShape2D").disabled = true
    ability.get_node("Left").get_node("CollisionShape2D").disabled = true
    ability.get_node("Right").get_node("CollisionShape2D").disabled = true
    
    ready_for_animation = true
```

---

## Система атаки

### 4 направления
- **UP**: Атака вверх
- **DOWN**: Атака вниз
- **LEFT**: Атака влево
- **RIGHT**: Атака вправо

### Кулдаун
```gdscript
var cooldown = 100  # мс между атаками

func can_attack() -> bool:
    var current_time = Time.get_ticks_msec()
    return current_time - last_attack_time >= cooldown
```

### Зоны поражения
- Area2D с CollisionShape2D
- Включаются на 0.05 секунды
- Наносят урон при контакте с врагом

---

## Интеграция с игроком

### Вызов атаки из `player.gd`
```gdscript
func attack():
    if not can_attack or is_dead:
        return
    
    can_anim = false
    can_attack = false
    
    # Анимация атаки
    match current_dir:
        Dir.UP: animP.play("attack_up")
        Dir.DOWN: animP.play("attack_down")
        Dir.LEFT: animP.play("attack_left")
        Dir.RIGHT: animP.play("attack_right")
    
    await animP.animation_finished
    
    can_anim = true
    attack_timer.start()
```

---

## Гайд для агентов

### Как добавить новую способность
1. Создайте сцену способности:
```
new_ability.tscn
├── Area2D (зона поражения)
└── Sprite2D (визуализация)
```

2. Создайте скрипт:
```gdscript
extends Node2D

@export var damage: int = 20
@export var cooldown: float = 1.0
@export var duration: float = 0.2

func activate(direction: Vector2):
    # Логика способности
    pass
```

### Как изменить урон атаки
```gdscript
# В game_constants.gd
PLAYER_ATTACK_DAMAGE = 15  # Было 10

# В зоне атаки
func _on_body_entered(body: Node2D):
    if body.is_in_group("enemies"):
        body.take_damage(GameConstants.PLAYER_ATTACK_DAMAGE)
```

### Как добавить комбо-атаку
```gdscript
var combo_count = 0
var combo_timer = 0.0

func _process(delta):
    combo_timer -= delta
    if combo_timer <= 0:
        combo_count = 0

func attack():
    combo_count += 1
    combo_timer = 2.0
    
    match combo_count:
        1: perform_basic_attack()
        2: perform_second_hit()
        3: perform_finisher()
```

### Как добавить снаряд вместо melee
```gdscript
func shoot_projectile():
    var projectile = preload("res://scene/abilities/arrow.tscn").instantiate()
    projectile.global_position = global_position
    projectile.direction = get_attack_direction()
    get_tree().current_scene.add_child(projectile)
```

---

## Зависимости

- `atack_spawn.gd` → `player.gd` (направление атаки)
- `atack_ability.tscn` → враги (группа `enemies` или `enemys`)

---

## Исправление ошибок

**Проблема**: В файле `atack_spawn.gd` находится логика зелья.

**Решение**: Использовать код из раздела выше или проверить, что файл содержит правильную логику атаки.

**Примечание**: В проекте есть дублирование — `atack_ability.tscn` и `player.gd` оба содержат логику атаки. Рекомендуется централизовать в `player.gd`.
