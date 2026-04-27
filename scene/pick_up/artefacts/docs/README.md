# Система артефактов

Полная система из **31 артефакта** с 4 уровнями редкости.

## 📊 Статистика

- **Всего артефактов:** 31
- **🟠 Legendary:** 2 (6.5%)
- **🟣 Epic:** 5 (16%)
- **🔵 Rare:** 9 (29%)
- **🟢 Common:** 15 (48.5%)

**📖 Полный список с описаниями:** `FULL_LIST.md`

---

## 🎯 Быстрый обзор по тирам

### 🟠 Legendary (2)
1. **Golden Cup** - +2 всех характеристик/lvl, +20% EXP
2. **Uno Reverse Card** - x1.5 ко всем характеристикам, +50% EXP

### 🟣 Epic (5)
3. **Disco Ball** - +1 всех характеристик/lvl
4. **Fairy Bottle** - +50 HP, +20 SPD, +3 DMG
5. **Golden Ball** - +2 DMG/lvl
6. **Top Hat** - +2 HP/lvl, +1 SPD/lvl
7. **Electronic Key** - +30 SPD, +30 HP, +2 DMG

### 🔵 Rare (9)
8. **Metal Shield** - +100 HP
9. **Crown** - +3 HP/lvl
10. **Blue Shroom** - +20 SPD, +30 HP
11. **Injector** - +3 DMG, +15 SPD
12. **Clock** - +1 DMG/lvl
13. **Red Potion** - +50 HP, +2 DMG
14. **Diamond** - +5 DMG
15. **Old Book** - +1 SPD/lvl
16. **Coffee Mug** - +30 SPD

### 🟢 Common (15)
17. **Bottle** - +15 HP
18. **Pill** - +10 SPD
19. **Button** - +1 DMG
20. **Letter** - +5 HP, +5 SPD
21. **Waffle** - +20 HP
22. **Juice Box** - +8 SPD
23. **Ramen Bowl** - +25 HP
24. **Milk Box** - +10 HP, +3 SPD
25. **Lime Juice** - +12 SPD
26. **Pill Can** - +15 HP, +1 DMG
27. **Small Cactus** - +1 DMG, +5 SPD
28. **Snow Ball** - +10 HP, +5 SPD
29. **Bongo** - +8 SPD, +8 HP
30. **Flashlight** - +1 DMG, +3 SPD
31. **VHS Cassette** - +10 HP, +1 DMG

---

## 🎮 Рекомендуемые билды

### 🛡️ Танк
Metal Shield, Crown, Red Potion, Ramen Bowl, Top Hat

### ⚡ Скорость
Coffee Mug, Blue Shroom, Old Book, Lime Juice, Electronic Key

### ⚔️ Урон
Diamond, Injector, Golden Ball, Clock, Fairy Bottle

### 🌟 Универсал
Golden Cup, Disco Ball, Uno Reverse Card, Electronic Key

### 📈 Фарм опыта
Golden Cup + Uno Reverse Card = **x1.8 к опыту!**

---

## 🔧 Базовый класс ArtefactPickup

Все артефакты наследуются от `artefact_pickup.gd`

### Экспортируемые параметры:
```gdscript
# Базовая информация
@export var artefact_name: String
@export var artefact_icon: Texture2D
@export var artefact_description: String

# Бонусы к характеристикам
@export var speed_bonus: int = 0
@export var health_bonus: int = 0
@export var damage_bonus: int = 0

# Бонусы за уровень
@export var health_per_level_bonus: int = 0
@export var speed_per_level_bonus: int = 0
@export var damage_per_level_bonus: int = 0
```

### Особенности:
- ✅ Автоматическое получение иконки из Sprite2D
- ✅ Размер увеличен в 4 раза (scale 3.2x)
- ✅ Анимация покачивания на земле
- ✅ Анимация подбора (увеличение и исчезновение)
- ✅ Автоматическое добавление в рюкзак
- ✅ **Popup с отображением всех бонусов**
- ✅ Цветовая кодировка бонусов
- ✅ Метод `custom_effect()` для уникальных эффектов

---

## 📝 Popup система

При подборе артефакта появляется окно с:
- Названием артефакта (золотым цветом, 32px)
- Списком всех бонусов с цветами:
  - 🟢 Зеленый - скорость
  - 🔴 Красный - здоровье
  - 🟠 Оранжевый - урон
  - 🔵 Синий - специальные эффекты
- Анимацией появления/исчезновения
- Автоматически пропадает через 3 секунды

---

## 🆕 Как создать новый артефакт

1. Создайте скрипт, наследующий `artefact_pickup.gd`:
```gdscript
extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
    artefact_name = "Название"
    artefact_description = "Описание"
    speed_bonus = 10  # или другие бонусы
    super._ready()

# Для уникальных эффектов
func custom_effect() -> void:
    GameConstants.SOME_STAT += 10
    stat_changes.append({
        "text": "Описание эффекта", 
        "color": Color(1, 1, 0)
    })
```

2. Создайте сцену:
```
Node2D (ваш скрипт)
├── Area2D (collision_mask = 9)
│   └── CollisionShape2D (CircleShape2D, radius = 60)
└── Sprite2D (текстура из 40 Random Items)
```

3. Подключите сигнал `area_entered` к методу `_on_area_2d_area_entered`

---

## 💡 Советы и механики

### Множители опыта
- Golden Cup: +20% (x1.2)
- Uno Reverse Card: +50% (x1.5)
- **Комбо:** x1.8 к получаемому опыту!

### Uno Reverse Card стратегия
- Подбирайте **в конце игры**, когда характеристики высокие
- x1.5 от 200 HP = +100 HP
- x1.5 от 50 HP = +25 HP

### Бонусы за уровень
- Стакаются с другими артефактами
- Golden Cup + Disco Ball = +3 всех характеристик/lvl
- Эффективны на длинных забегах

### Размещение на карте
- Все артефакты автоматически добавлены в `treasure_items` в MapManager
- Случайно спавнятся в комнатах
- Размер увеличен в 4 раза для лучшей видимости

---

## 📁 Структура файлов

```
scene/pick_up/artefacts/
├── artefact_pickup.gd          # Базовый класс
├── README.md                    # Этот файл
├── FULL_LIST.md                 # Полный список всех 31 артефакта
├── TIERS_PLAN.md                # План по тирам
├── [31 .gd файлов]              # Скрипты артефактов
└── [31 .tscn файлов]            # Сцены артефактов
```

---

## 🎨 Иконки

Все иконки взяты из папки `40 Random Items/`:
- Bottle.png, Pill.png, Button.png, Letter.png
- Waffle.png, JuiceBox.png, RamenBowl.png
- MilkBox.png, LimeJuice.png, PillCan.png
- SmallСactus.png, SnowBall.png, Bongo.png
- Flashlight.png, VhsCassette.png
- MetalShield.png, Crown.png, BlueShroom.png
- Injector.png, Clock.png, RedPotion.png
- Diamond.png, OldBook.png, CoffeMug.png
- FairyBottle.png, DiscoBall.png, ElectronicKey.png
- TopHat.png, GoldenBall.png
- GoldenCup.png, UnoReverseCard.png

Все готово к использованию! 🎉
