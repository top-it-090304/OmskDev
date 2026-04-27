# 2D Top-Down Roguelike (Isaac-like)

Игра в жанре roguelike с процедурной генерацией данжена, системой артефактов и боями.

---

## Структура проекта

```
.
├── README.md                 # Этот файл
├── globals/                  # Глобальные системы
│   ├── game_constants.gd     # Игровые константы и статы
│   └── save_system.gd        # Система сохранений
├── scene/                    # Игровые сцены
│   ├── game_objects/         # Сущности
│   │   ├── player/           # Игрок и компоненты
│   │   ├── enemy/            # Обычные враги
│   │   └── bosses/           # Боссы
│   ├── pick_up/              # Подбираемые предметы
│   │   ├── artefacts/        # Артефакты (30+)
│   │   └── Heal potion/      # Зелья лечения
│   ├── abilities/            # Способности атаки
│   └── ui/                   # UI элементы
├── World/                    # Основной мир
│   ├── map_manager.tscn      # Генератор данжена
│   ├── minimap.tscn          # Миникарта
│   ├── layer.tscn            # Основной слой мира
│   └── UI/                   # Меню и пауза
└── addons/                   # Сторонние плагины
```

---

## Быстрый старт для агентов

### 1. Понять архитектуру
Начните с чтения:
1. `globals/README.md` — глобальные системы
2. `World/README.md` — генерация мира
3. `scene/game_objects/player/README.md` — логика игрока

### 2. Добавить нового врага
См. `scene/game_objects/enemy/README.md`

### 3. Добавить артефакт
См. `scene/pick_up/artefacts/README.md`

### 4. Изменить баланс
См. `globals/README.md` → `game_constants.gd`

---

## Ключевые системы

| Система | Файл | Описание |
|---------|------|----------|
| Генерация | `World/map_manager.gd` | Процедурная генерация 8x8 |
| Бой | `scene/game_objects/player/player.gd` | 4 направления, кулдауны |
| Уровни | `scene/game_objects/player/player.gd` | EXP, level up, масштабирование |
| Артефакты | `scene/pick_up/artefacts/` | 30+ предметов с эффектами |
| Сохранения | `globals/save_system.gd` | JSON + dungeon state |
| Враги | `scene/game_objects/enemy/` | 3 типа + масштабирование |
| Босс | `scene/game_objects/bosses/` | Beast Goblin с 3 атаками |

---

## Технические детали

- **Движок**: Godot 4.x
- **Язык**: GDScript
- **Основная ветка**: `features`
- **Группы Godot**: `player`, `enemys`, `map_manager`, `backpack`

---

## Ссылки на документацию по папкам

- [`globals/README.md`](globals/README.md) — Глобальные системы
- [`World/README.md`](World/README.md) — Генерация мира
- [`World/UI/README.md`](World/UI/README.md) — Меню и пауза
- [`scene/game_objects/player/README.md`](scene/game_objects/player/README.md) — Игрок
- [`scene/game_objects/enemy/README.md`](scene/game_objects/enemy/README.md) — Враги
- [`scene/game_objects/bosses/README.md`](scene/game_objects/bosses/README.md) — Боссы
- [`scene/pick_up/artefacts/README.md`](scene/pick_up/artefacts/README.md) — Артефакты
- [`scene/pick_up/Heal potion/README.md`](scene/pick_up/Heal%20potion/README.md) — Зелья
- [`scene/abilities/README.md`](scene/abilities/README.md) — Способности
- [`scene/ui/README.md`](scene/ui/README.md) — UI элементы
- [`scene/room_variants/README.md`](scene/room_variants/README.md) — Комнаты
