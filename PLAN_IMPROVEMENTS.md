# 📋 ПЛАН УЛУЧШЕНИЙ ИГРЫ DUNGEON

**Дата создания:** 2026-04-17  
**Статус:** В разработке

---

## 🎯 ПРИОРИТЕТ 1 - КРИТИЧЕСКИЕ ИСПРАВЛЕНИЯ

### 1.1 Реализовать неиспользуемые характеристики игрока

**Проблема:** Артефакты дают бонусы к броне, уклонению, криту, вампиризму и скорости атаки, но эти характеристики не работают в коде.

**Файлы для изменения:**
- `scene/game_objects/player/player.gd`
- `scene/abilities/atack_ability/atack_spawn.gd`

**Что нужно сделать:**

#### 1.1.1 Броня (PLAYER_ARMOR)
```gdscript
# В player.gd, функция take_damage():
func take_damage(amount: int):
    if not can_take_damage or is_dead:
        return
    
    # ДОБАВИТЬ: Применение брони
    var final_damage = max(1, amount - GameConstants.PLAYER_ARMOR)
    
    can_anim = false 
    can_take_damage = false
    health_int -= final_damage  # Изменить с amount на final_damage
    health_changed.emit(health_int, GameConstants.PLAYER_MAX_HEALTH)
    # ... остальной код
```

#### 1.1.2 Уклонение (PLAYER_DODGE_CHANCE)
```gdscript
# В player.gd, функция take_damage():
func take_damage(amount: int):
    if not can_take_damage or is_dead:
        return
    
    # ДОБАВИТЬ: Проверка уклонения
    if randf() < GameConstants.PLAYER_DODGE_CHANCE:
        print("УКЛОНЕНИЕ!")
        # Можно добавить визуальный эффект
        return
    
    # ... остальной код с броней
```

#### 1.1.3 Критические удары (PLAYER_CRIT_CHANCE, PLAYER_CRIT_MULTIPLIER)
```gdscript
# В player.gd, добавить новую функцию:
func calculate_damage() -> int:
    var base_damage = GameConstants.PLAYER_ATTACK_DAMAGE
    
    # Проверка критического удара
    if randf() < GameConstants.PLAYER_CRIT_CHANCE:
        var crit_damage = int(base_damage * GameConstants.PLAYER_CRIT_MULTIPLIER)
        print("КРИТИЧЕСКИЙ УДАР! Урон: ", crit_damage)
        # Можно добавить визуальный эффект
        return crit_damage
    
    return base_damage

# В player.gd, функция _on_hitbox_attack_body_entered():
func _on_hitbox_attack_body_entered(body: Node2D) -> void:
    print("Удар по объекту: ", body.name)
    if is_dead: return
    if body.is_in_group("enemies"):
        var damage = calculate_damage()  # ИЗМЕНИТЬ: использовать новую функцию
        body.take_damage(damage)
```

#### 1.1.4 Вампиризм (PLAYER_LIFESTEAL)
```gdscript
# В player.gd, функция _on_hitbox_attack_body_entered():
func _on_hitbox_attack_body_entered(body: Node2D) -> void:
    print("Удар по объекту: ", body.name)
    if is_dead: return
    if body.is_in_group("enemies"):
        var damage = calculate_damage()
        body.take_damage(damage)
        
        # ДОБАВИТЬ: Вампиризм
        if GameConstants.PLAYER_LIFESTEAL > 0:
            var heal_amount = int(damage * GameConstants.PLAYER_LIFESTEAL)
            if heal_amount > 0:
                heal(heal_amount)
                print("Вампиризм: восстановлено ", heal_amount, " HP")
```

#### 1.1.5 Скорость атаки (PLAYER_ATTACK_SPEED)
```gdscript
# В player.gd, функция _ready():
func _ready() -> void:
    # ... существующий код ...
    
    # ДОБАВИТЬ: Настройка кулдауна атаки
    if attack_timer:
        var base_cooldown = 0.5  # Базовый кулдаун в секундах
        attack_timer.wait_time = base_cooldown / GameConstants.PLAYER_ATTACK_SPEED
        print("Кулдаун атаки: ", attack_timer.wait_time, " сек")

# ДОБАВИТЬ: Обновление при изменении констант
func _on_constants_changed() -> void:
    # ... существующий код ...
    
    # Обновляем кулдаун атаки
    if attack_timer:
        var base_cooldown = 0.5
        attack_timer.wait_time = base_cooldown / GameConstants.PLAYER_ATTACK_SPEED
```

---

### 1.2 Исправить систему урона игрока

**Проблема:** Используется `PLAYER_ENEMY_CONTACT_DAMAGE` вместо `PLAYER_ATTACK_DAMAGE`

**Файл:** `scene/game_objects/player/player.gd:199`

```gdscript
# БЫЛО:
body.take_damage(GameConstants.PLAYER_ENEMY_CONTACT_DAMAGE)

# ДОЛЖНО БЫТЬ:
var damage = calculate_damage()  # С учетом критов
body.take_damage(damage)
```

---

### 1.3 Улучшить систему атаки

**Проблема:** Хитбоксы активны только 50ms, что может пропускать врагов

**Файл:** `scene/abilities/atack_ability/atack_spawn.gd`

**Варианты решения:**

**Вариант А (простой):** Увеличить время активности хитбокса
```gdscript
# В функции place_player():
await get_tree().create_timer(0.15).timeout  # Было 0.05
```

**Вариант Б (правильный):** Использовать систему из player.gd
- Удалить `atack_spawn.gd` полностью
- Вся логика атаки уже есть в `player.gd`
- Убрать дублирование кода

---

## 🔧 ПРИОРИТЕТ 2 - ВАЖНЫЕ УЛУЧШЕНИЯ

### 2.1 Рефакторинг системы артефактов

**Проблема:** 34 почти идентичных файла с дублированием кода

**Решение:** Data-driven подход с ресурсами

**Создать новый файл:** `scene/pick_up/artefacts/artefact_data.gd`
```gdscript
extends Resource
class_name ArtefactData

@export var artefact_name: String = "Artefact"
@export var artefact_description: String = "Описание"
@export var artefact_icon: Texture2D

# Бонусы
@export_group("Stat Bonuses")
@export var speed_bonus: int = 0
@export var health_bonus: int = 0
@export var damage_bonus: int = 0
@export var armor_bonus: int = 0
@export var dodge_chance_bonus: float = 0.0
@export var crit_chance_bonus: float = 0.0
@export var crit_multiplier_bonus: float = 0.0
@export var lifesteal_bonus: float = 0.0
@export var attack_speed_bonus: float = 0.0
@export var health_per_level_bonus: int = 0
@export var speed_per_level_bonus: int = 0
@export var damage_per_level_bonus: int = 0
@export var exp_multiplier_bonus: float = 0.0
```

**Изменить:** `scene/pick_up/artefacts/artefact_pickup.gd`
```gdscript
extends Node2D

@export var artefact_data: ArtefactData

func _ready():
    if artefact_data:
        artefact_name = artefact_data.artefact_name
        artefact_description = artefact_data.artefact_description
        artefact_icon = artefact_data.artefact_icon
        speed_bonus = artefact_data.speed_bonus
        # ... и так далее для всех полей
    
    super._ready()
```

**Результат:** Вместо 34 .gd файлов будет 34 .tres файла с данными

---

### 2.2 Система сохранения

**Создать файл:** `globals/save_system.gd`

```gdscript
extends Node

const SAVE_PATH = "user://save_game.dat"

func save_game():
    var save_data = {
        "player_level": GameConstants.PLAYER_LEVEL,
        "player_exp": GameConstants.PLAYER_EXPERIENCE,
        "player_stats": {
            "max_health": GameConstants.PLAYER_MAX_HEALTH,
            "max_speed": GameConstants.PLAYER_MAX_SPEED,
            "attack_damage": GameConstants.PLAYER_ATTACK_DAMAGE,
            "armor": GameConstants.PLAYER_ARMOR,
            # ... остальные характеристики
        },
        "rooms_cleared": GameConstants.ROOMS_CLEARED,
        "enemy_level": GameConstants.ENEMY_LEVEL,
        "enemies_killed": GameConstants.ENEMIES_KILLED,
    }
    
    var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file:
        file.store_var(save_data)
        file.close()
        return true
    return false

func load_game():
    if not FileAccess.file_exists(SAVE_PATH):
        return false
    
    var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file:
        var save_data = file.get_var()
        file.close()
        
        GameConstants.PLAYER_LEVEL = save_data.get("player_level", 1)
        GameConstants.PLAYER_EXPERIENCE = save_data.get("player_exp", 0)
        # ... восстановление остальных данных
        
        return true
    return false
```

**Добавить в autoload:** `project.godot`
```
[autoload]
GameConstants="*res://globals/game_constants.gd"
SaveSystem="*res://globals/save_system.gd"
```

---

### 2.3 Оптимизация производительности

#### 2.3.1 Исправить обновление UI каждый кадр

**Файл:** `scene/ui/enemy_level_display.gd`

```gdscript
# УДАЛИТЬ функцию _process полностью:
# func _process(_delta: float) -> void:
#     update_level_display()

# Оставить только:
func _ready() -> void:
    update_level_display()
    if not GameConstants.constants_changed.is_connected(_on_constants_changed):
        GameConstants.constants_changed.connect(_on_constants_changed)

func _on_constants_changed() -> void:
    update_level_display()
```

#### 2.3.2 Вынести константы в GameConstants

**Файл:** `scene/pick_up/Heal potion/heal_potion.gd`

```gdscript
# БЫЛО:
player_node.heal(20)

# ДОЛЖНО БЫТЬ:
player_node.heal(GameConstants.HEALTH_POTION_HEAL_AMOUNT)
```

**Добавить в:** `globals/game_constants.gd`
```gdscript
var HEALTH_POTION_HEAL_AMOUNT = 20
```

---

## 💡 ПРИОРИТЕТ 3 - ЖЕЛАТЕЛЬНЫЕ УЛУЧШЕНИЯ

### 3.1 Звуковая система

**Создать:** `globals/audio_manager.gd`

```gdscript
extends Node

var sounds = {
    "player_attack": preload("res://sounds/player_attack.wav"),
    "player_hurt": preload("res://sounds/player_hurt.wav"),
    "enemy_death": preload("res://sounds/enemy_death.wav"),
    "pickup": preload("res://sounds/pickup.wav"),
    "level_up": preload("res://sounds/level_up.wav"),
}

func play_sound(sound_name: String):
    if sound_name in sounds:
        var player = AudioStreamPlayer.new()
        add_child(player)
        player.stream = sounds[sound_name]
        player.play()
        player.finished.connect(func(): player.queue_free())
```

**Добавить вызовы:**
- `AudioManager.play_sound("player_attack")` при атаке
- `AudioManager.play_sound("pickup")` при подборе артефакта
- И т.д.

---

### 3.2 Расширение контента

#### 3.2.1 Новые враги
- Goblin Mage (дальний бой, магия)
- Skeleton Knight (ближний бой, щит)
- Slime (медленный, много HP)

#### 3.2.2 Новые боссы
- Necromancer (призывает скелетов)
- Dragon (летает, огненное дыхание)

#### 3.2.3 Новые артефакты
- Категория "Проклятые" (сильный бонус + штраф)
- Категория "Синергия" (бонус при наличии других артефактов)

---

### 3.3 Улучшение UI

#### 3.3.1 Адаптивный layout
```gdscript
# Использовать Control containers:
# - MarginContainer для отступов
# - VBoxContainer/HBoxContainer для автоматического размещения
# - AspectRatioContainer для сохранения пропорций
```

#### 3.3.2 Миникарта
- Показывать посещенные комнаты
- Отмечать текущую комнату
- Показывать тип комнаты (обычная/босс/сокровищница)

#### 3.3.3 Меню паузы
- Продолжить
- Настройки (громкость, управление)
- Выход в главное меню

---

### 3.4 Визуальные эффекты

#### 3.4.1 Частицы
```gdscript
# При атаке игрока:
var particles = CPUParticles2D.new()
particles.emitting = true
particles.one_shot = true
particles.amount = 10
particles.lifetime = 0.5
# ... настройка параметров
add_child(particles)
```

#### 3.4.2 Screen shake
```gdscript
# При получении урона:
func apply_screen_shake(intensity: float):
    var camera = get_viewport().get_camera_2d()
    if camera:
        var tween = create_tween()
        for i in range(5):
            var offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
            tween.tween_property(camera, "offset", offset, 0.05)
        tween.tween_property(camera, "offset", Vector2.ZERO, 0.05)
```

---

## 🐛 ИСПРАВЛЕНИЕ БАГОВ

### Баг 1: Опечатка в анимации смерти босса
**Файл:** `scene/game_objects/bosses/goblin/beast_goblin.gd:231`
```gdscript
# БЫЛО:
if _get_dir_string() == "down": d_anim = "death_dowm"

# ДОЛЖНО БЫТЬ:
if _get_dir_string() == "down": d_anim = "death_down"
```

### Баг 2: Неконсистентные названия
- Переименовать `atack` → `attack` везде
- Переименовать `enemys` → `enemies` в группах

### Баг 3: Дублирование структуры папок
**Проблема:** `scene/pick_up/artefacts/scene/pick_up/artefacts/`

**Решение:** Переместить все файлы из вложенной папки в основную:
```bash
mv scene/pick_up/artefacts/scene/pick_up/artefacts/* scene/pick_up/artefacts/
rm -rf scene/pick_up/artefacts/scene/
```

---

## 📊 МЕТРИКИ УСПЕХА

После реализации всех изменений:

- ✅ Все характеристики игрока работают
- ✅ Артефакты дают реальный эффект
- ✅ Нет дублирования кода
- ✅ Есть система сохранения
- ✅ Звуки и музыка
- ✅ Оптимизированная производительность
- ✅ Расширенный контент

**Целевая оценка:** 9/10

---

## 📝 ПРИМЕЧАНИЯ

- Все изменения должны быть протестированы
- Создавать коммиты после каждого завершенного пункта
- Сохранять обратную совместимость где возможно
- Документировать новые системы

---

**Последнее обновление:** 2026-04-17
