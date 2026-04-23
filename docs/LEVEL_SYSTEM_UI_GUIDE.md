# Гайд по созданию UI для системы уровней

## ✅ Что уже реализовано

### Backend (логика):
- ✅ Система опыта и уровней в Player.gd
- ✅ Выдача опыта при убийстве врагов:
  - Goblin Axe: 15 опыта
  - Skeleton Bow: 12 опыта
  - Beast Goblin (босс): 50 опыта
- ✅ Прирост характеристик за уровень:
  - +20 HP
  - +5 скорости
  - +2 урона
- ✅ Формула опыта: 100 * (1.5 ^ (уровень - 1))
- ✅ Сигналы для UI:
  - `exp_changed(current_exp, exp_needed)` - изменение опыта
  - `level_up(new_level)` - повышение уровня
  - `health_changed(new_health, max_health)` - изменение здоровья

## 📋 Что нужно сделать для UI

### 1. Создать сцену для EXP бара

**Путь:** `scene/game_objects/player/exp_bar.tscn`

**Структура:**
```
ExpBar (Control или CanvasLayer)
├── Background (TextureRect или ColorRect)
├── ProgressBar (TextureProgressBar)
├── LevelLabel (Label) - "Уровень: 5"
└── ExpLabel (Label) - "150 / 225"
```

**Настройки TextureProgressBar:**
- Mode: Fill
- Fill Mode: Left to Right
- Min Value: 0
- Max Value: 100 (будем работать с процентами)

### 2. Создать скрипт exp_bar.gd

```gdscript
extends Control

@onready var progress_bar = $ProgressBar
@onready var level_label = $LevelLabel
@onready var exp_label = $ExpLabel

var player: Node = null

func _ready():
	# Находим игрока
	player = get_tree().get_first_node_in_group("player")
	
	if player:
		# Подключаемся к сигналам
		player.exp_changed.connect(_on_exp_changed)
		player.level_up.connect(_on_level_up)
		
		# Инициализируем начальные значения
		_update_display(player.current_exp, player.exp_to_next_level, player.current_level)

func _on_exp_changed(current_exp: int, exp_needed: int):
	_update_display(current_exp, exp_needed, player.current_level)

func _on_level_up(new_level: int):
	level_label.text = "Уровень: " + str(new_level)
	# Можно добавить анимацию level up
	_play_level_up_animation()

func _update_display(current: int, needed: int, level: int):
	var percentage = (float(current) / float(needed)) * 100.0
	progress_bar.value = percentage
	
	level_label.text = "Уровень: " + str(level)
	exp_label.text = str(current) + " / " + str(needed)

func _play_level_up_animation():
	# Простая анимация: увеличение и уменьшение
	var tween = create_tween()
	tween.tween_property(level_label, "scale", Vector2(1.5, 1.5), 0.2)
	tween.tween_property(level_label, "scale", Vector2(1.0, 1.0), 0.2)
```

### 3. Добавить EXP бар в Player.tscn

**Вариант А: Локальный UI (следует за игроком)**
- Добавь `exp_bar.tscn` как child в Player
- Установи position над головой игрока (например, y = -50)

**Вариант Б: Глобальный UI (фиксированный на экране)**
- Добавь `exp_bar.tscn` в основную сцену (World)
- Установи anchors: Top Left или Bottom Left
- Margins: отступ от края экрана

### 4. Создать всплывающий текст Level Up (опционально)

**Путь:** `scene/ui/level_up_popup.tscn`

**Структура:**
```
LevelUpPopup (Control)
└── Label (Label) - "LEVEL UP!"
```

**Скрипт level_up_popup.gd:**
```gdscript
extends Control

@onready var label = $Label

func _ready():
	# Анимация появления и исчезновения
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Движение вверх
	tween.tween_property(self, "position:y", position.y - 100, 1.5)
	
	# Fade out
	tween.tween_property(label, "modulate:a", 0.0, 1.5)
	
	# Удаляем после анимации
	tween.finished.connect(queue_free)
```

**Добавь в Player.gd:**
```gdscript
const LEVEL_UP_POPUP = preload("res://scene/ui/level_up_popup.tscn")

func level_up_player() -> void:
	# ... существующий код ...
	
	# Показываем popup
	_show_level_up_popup()

func _show_level_up_popup():
	var popup = LEVEL_UP_POPUP.instantiate()
	popup.global_position = global_position + Vector2(0, -50)
	get_tree().current_scene.add_child(popup)
```

### 5. Добавить визуальные эффекты (опционально)

**Частицы при Level Up:**
1. Создай CPUParticles2D или GPUParticles2D
2. Настрой:
   - Amount: 20-30
   - Lifetime: 1.0
   - Explosiveness: 1.0
   - Direction: вверх
   - Spread: 45 градусов
3. Добавь в Player и вызывай `emit()` при level_up

**Звук Level Up:**
```gdscript
@onready var level_up_sound = $LevelUpSound

func level_up_player() -> void:
	# ... существующий код ...
	level_up_sound.play()
```

## 🎨 Рекомендации по дизайну

### Цвета:
- **EXP бар фон:** темно-серый (#2c2c2c)
- **EXP бар заполнение:** золотой градиент (#ffd700 → #ffaa00)
- **Текст уровня:** белый с черной обводкой
- **Level Up текст:** яркий желтый (#ffff00)

### Размеры:
- **EXP бар:** 200x20 пикселей
- **Шрифт уровня:** 16-18px
- **Шрифт опыта:** 12-14px
- **Level Up текст:** 32-48px

### Позиционирование:
- **Верхний левый угол:** для основного UI
- **Над головой игрока:** для локального отображения
- **Нижний центр:** альтернативный вариант

## 🧪 Тестирование

Для быстрого тестирования добавь в Player.gd:
```gdscript
func _input(event):
	if event.is_action_pressed("ui_accept"):  # Пробел
		add_experience(50)  # Добавить 50 опыта для теста
```

## 📊 Текущие значения

- **Уровень 1 → 2:** 100 опыта
- **Уровень 2 → 3:** 150 опыта
- **Уровень 3 → 4:** 225 опыта
- **Уровень 4 → 5:** 337 опыта

**Примерное количество убийств для уровня:**
- Уровень 2: ~7 гоблинов или ~8 скелетов или 2 босса
- Уровень 3: ~10 гоблинов
- Уровень 4: ~15 гоблинов

## ✨ Дополнительные идеи

1. **Анимация заполнения бара** - плавное изменение через Tween
2. **Звездочки/искры** при получении опыта
3. **Экран статистики** - показывать все характеристики игрока
4. **История уровней** - сколько раз повысился уровень за забег
5. **Комбо-счетчик** - бонусный опыт за быстрые убийства подряд

---

**Готово!** Теперь у тебя есть полная система уровней с backend логикой. Осталось только создать визуальный UI по этому гайду.
