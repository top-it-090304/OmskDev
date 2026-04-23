# Heal Potion — Зелья лечения

Папка содержит зелья для восстановления здоровья.

---

## Файлы

### `heal_potion.gd` (Area2D)
**Назначение**: Подбираемый предмет для восстановления HP.

**Примечание**: В текущей версии файл `heal_potion.gd` содержит ошибку — в нём находится логика `atack_spawn.gd`. Правильная логика зелья должна быть:

```gdscript
extends Area2D

@export var heal_amount: int = 20

func _on_body_entered(body: Node2D):
    if body.is_in_group("player"):
        if body.has_method("heal"):
            body.heal(heal_amount)
        queue_free()
```

**Текущее содержимое файла** (ошибочное):
```gdscript
extends Area2D
func _on_area_2d_area_entered(area: Area2D) -> void:
    var player_node = get_tree().get_first_node_in_group("player")
    player_node.heal(20)
    queue_free()
```

---

## Спавн зелий

### Источники
1. **Goblin Axe** (25% шанс при смерти)
2. **Skeleton Bow** (25% шанс при смерти)
3. **Goblin Slinger** (25% шанс при смерти)
4. **Beast Goblin** (75% шанс при смерти)

### Код спавна
```gdscript
# В enemy.gd: _spawn_loot()
func _spawn_loot():
    var potion = GameConstants.HEALTH_POTION.instantiate()
    potion.global_position = global_position
    room_node.add_child(potion)  # Добавляем в комнату, не в Enemys
```

---

## Гайд для агентов

### Как изменить количество лечения
```gdscript
# В game_constants.gd добавьте константу
var HEALTH_POTION_HEAL_AMOUNT = 30

# В heal_potion.gd
@export var heal_amount: int = GameConstants.HEALTH_POTION_HEAL_AMOUNT
```

### Как добавить новый тип зелья
1. Создайте сцену в `scene/pick_up/`:
```
greater_heal_potion.tscn
├── Sprite2D (новая текстура)
└── Area2D
```

2. Создайте скрипт:
```gdscript
extends Area2D

@export var heal_amount: int = 50

func _on_body_entered(body: Node2D):
    if body.is_in_group("player"):
        body.heal(heal_amount)
        queue_free()
```

3. Добавьте константу в `game_constants.gd`:
```gdscript
const GREATER_HEALTH_POTION = preload("res://scene/pick_up/greater_heal_potion.tscn")
```

### Как изменить шанс выпадения
```gdscript
# В enemy.gd: death()
if randf() <= 0.50:  # Было 0.25 (25% → 50%)
    _spawn_loot()
```

### Как добавить другие эффекты к зелью
```gdscript
func _on_body_entered(body: Node2D):
    if body.is_in_group("player"):
        body.heal(heal_amount)
        
        # Дополнительные эффекты
        if "apply_buff" in body:
            body.apply_buff("regeneration", 5.0, 2)
        
        queue_free()
```

---

## Зависимости

- `heal_potion.gd` → `player.gd` (метод `heal()`)
- `heal_potion.gd` → `GameConstants.HEALTH_POTION` (презагрузка)

---

## Исправление ошибки

**Проблема**: В файле `heal_potion.gd` находится код из `atack_spawn.gd`.

**Решение**: Заменить содержимое на:
```gdscript
extends Area2D

@export var heal_amount: int = 20

func _on_body_entered(body: Node2D):
    if body.is_in_group("player"):
        if body.has_method("heal"):
            body.heal(heal_amount)
        queue_free()
```
