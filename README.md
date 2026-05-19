<div align="center">

# 🗡️ Dungeon

**2D-roguelike с процедурным данжем, артефактами и онлайн-кооперативом до 8 игроков**

[![Godot](https://img.shields.io/badge/Godot-4.4-478CBF?logo=godotengine&logoColor=white)](https://godotengine.org/)
[![Language](https://img.shields.io/badge/GDScript-100%25-355570?logo=godotengine&logoColor=white)](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html)
[![Platform](https://img.shields.io/badge/Platform-Mobile%20%7C%20Android%20%7C%20AuroraOS-3DDC84?logo=android&logoColor=white)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](#-contributing)

</div>

---

## 📖 О проекте

**Dungeon** — top-down action roguelike в духе классических dungeon-краулеров. Каждый забег — это процедурно сгенерированный данж из связанных комнат: старт → обычные комнаты → сокровищницы → босс → переход на следующий этаж. Между забегами игрок копит **артефакты с постоянными бонусами** и растёт в уровне.

Проект собирается с флагом **Mobile** (touch-управление виртуальными джойстиками, viewport-стретч), но запускается и на десктопе через клавиатуру/мышь.

### Ключевые особенности

- 🎲 **Процедурная генерация с seed** — забеги воспроизводимы, состояние данжа сохраняется в `user://dungeon_state.dat`.
- 🤝 **Онлайн-кооператив до 8 человек** (1 хост + 7 гостей, ENet, авторитативный хост).
- 🗺️ **Туман войны и миникарта** — посещённые/увиденные/зачищенные комнаты.
- ⚔️ **Несколько типов врагов и боссов** — Goblin Axe, Skeleton Bow, Goblin Slinger, Skeleton King, Beast Goblin.
- 💎 **Большой набор артефактов** — постоянные бонусы к HP, скорости, урону, криту, вампиризму и пр.
- 🎵 **Адаптивная музыка** — отдельные плейлисты для исследования / боя / босса.
- ⚙️ **Горячая перезагрузка баланса** — `globals/game_consts.cfg` пересчитывается на лету в одиночке.
- 🌍 **Локализация:** русский, английский, азербайджанский.

---

## 🧰 Технологический стек

| Компонент   | Версия / примечание                                              |
|-------------|------------------------------------------------------------------|
| **Движок**  | Godot **4.4** (`config/features=4.4, Mobile`)                    |
| **Язык**    | GDScript (без .NET/C#/Mono)                                      |
| **Рендер**  | `mobile` renderer, viewport stretch, ETC2/ASTC-сжатие текстур    |
| **Сеть**    | Встроенный `MultiplayerAPI` + `ENetMultiplayerPeer`, порт `4242` |
| **Плагины** | `addons/AS2P` (sprite → collision), 3× `addons/virtual_joystick*`|

---

## 📋 Prerequisites (требования)

### Для запуска и разработки

- **[Godot 4.4](https://github.com/savegame/godot/releases/tag/4.4.1-auroraos-4)** — desktop-редактор с поддержкой Mobile-рендера. Mono-версия **не требуется**.
- **Git** ≥ 2.30 — для клонирования и работы с историей.
- ~500 МБ свободного места на диске (с учётом импортов в `.godot/`).

### Для экспорта в `.apk` (Android)

- Godot 4.4 → Editor Settings → Export → Android: настроенные пути к **Android SDK**, **JDK 17** и **debug keystore**. Подробности — в [официальной документации Godot](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html).
- В репозитории уже есть пресет в `export_presets.cfg` (target API: `arm64-v8a`, package `com.example.dungeon`).

### Для экспорта в AuroraOS

- Шаблон экспорта AuroraOS для Godot 4.4 (`architectures/armv7hl=true`). Конфигурация лежит в `export_presets.cfg → preset.0`.

---

## 🚀 Quick Start

### 1. Клонирование

```bash
git clone https://github.com/top-it-090304/OmskDev
cd OmskDev
```

### 2. Импорт проекта

Откройте Godot 4.4 и нажмите **Import** → выберите файл `project.godot` в корне репозитория. Godot создаст папку `.godot/` и проимпортирует все ресурсы (первый раз это занимает 1–2 минуты).

### 3. Запуск

В редакторе нажмите **F5** — стартовая сцена уже сконфигурирована (`World/UI/menu.tscn`, поле `run/main_scene` в `project.godot`).

### 4. Smoke-test из CLI (опционально)

Проверка, что проект корректно импортируется и не падает:

```bash
# Windows (PowerShell)
& "<path-to-godot>\Godot.windows.editor.x86_64.exe" --path . --headless --quit-after 1

# Linux / macOS
godot4 --path . --headless --quit-after 1
```

Команда должна завершиться с кодом `0` и без критических ошибок в stderr.

### 5. Локальный кооп (две машины в одной сети)

1. На обоих устройствах должна быть открыта по UDP/TCP **`4242`** в firewall.
2. **Хост:** меню → *Мультиплеер* → *Создать игру* → запомнить код комнаты (это локальный IP).
3. **Клиент:** меню → *Мультиплеер* → *Присоединиться* → ввести код.
4. Хост стартует забег — клиенту приходит снимок состояния данжа и `GameConstants`.

---

## 🎮 Управление

| Действие              | Клавиатура           | Touch                    |
|-----------------------|----------------------|--------------------------|
| Движение              | `W` / `A` / `S` / `D`| Левый виртуальный стик   |
| Атака                 | ЛКМ / стрелки        | Правый виртуальный стик  |
| Открыть карту         | `Tab`                | Кнопка «карта» в HUD     |

Полная карта инпута — секция `[input]` в `project.godot`.

---

## 📁 Структура проекта

```
dungeon/
├── project.godot               ← конфигурация: autoload, main scene, input map, локали
├── LICENSE                     ← MIT License
├── README.md                   ← вы здесь
├── export_presets.cfg          ← пресеты экспорта (Android, AuroraOS)
├── default_bus_layout.tres     ← аудио-шины (Master / Music / SFX)
│
├── globals/                    ← autoload-синглтоны и баланс
│   ├── game_constants.gd       ←   стат-холдер игрока/врагов, сигнал constants_changed
│   ├── game_consts.cfg         ←   горячо-перезагружаемый конфиг баланса
│   ├── save_system.gd          ←   JSON-сохранения (player + dungeon)
│   ├── audio_manager.gd        ←   музыка/SFX, чтение громкости
│   ├── network_manager.gd      ←   ENet host/join, RPC, кооп-логика
│   ├── player_manager.gd       ←   спавн игроков, кооп-spawn-points
│   └── localization_manager.gd ←   языки (ru/en/az)
│
├── World/                      ← основная игровая сцена и менеджеры
│   ├── layer.tscn              ←   слой с MapManager + UI + миникартой
│   ├── map_manager.tscn/.gd    ←   генерация комнат и коридоров (8×8 сетка)
│   ├── minimap.tscn/.gd
│   ├── camera_manager.gd
│   └── UI/                     ←   меню, лобби, пауза, настройки
│
├── scene/
│   ├── game_objects/
│   │   ├── player/             ←   player.tscn, опыт, бой, инвентарь
│   │   ├── enemy/              ←   Goblin Axe / Skeleton Bow / Goblin Slinger
│   │   └── bosses/             ←   Skeleton King, Beast Goblin
│   ├── pick_up/                ←   артефакты, зелья, люк
│   │   └── artefacts/          ←   ~30 артефактов, общий artefact_pickup.gd
│   ├── room_variants/          ←   префабы комнат, тайлсеты
│   ├── abilities/              ←   логика и визуал атак
│   ├── effects/                ←   партиклы, FX
│   ├── ui/                     ←   всплывающие UI (попап артефакта и т.д.)
│   └── button/                 ←   виртуальные джойстики
│
├── addons/
│   ├── AS2P/                   ←   AnimatedSprite2D → Polygon2D-коллизии
│   ├── virtual_joystick/
│   ├── virtual_joystick_attack/
│   └── virtual_joystick_move/
│
├── translations/               ←   translations.csv + ru/en/az .translation
├── assets/, sprites/, music/, Font/, icons/   ←   арт и аудио
└── docs/                       ←   архитектурные доки и история изменений
    ├── ARTEFACTS_SUMMARY.md
    ├── BACKPACK_SYSTEM.md
    ├── CHANGELOG_ARTEFACTS.md
    ├── LEVEL_SYSTEM_UI_GUIDE.md
    ├── PLAN_IMPROVEMENTS.md
    └── SAVE_SYSTEM.md
```

> **Внимание:** файлы `Player.gd`, `PlayerInput.gd`, `LevelSetup.gd`, `test_network.gd`, `artefact(boots_of_travel).gd`, `void.png` в **корне** репозитория — устаревшие прототипы и тестовые скрипты, **не используются** в собираемом проекте. Их планируется убрать; новый код кладите в соответствующие подпапки (`scene/`, `World/`, `globals/`).

---

## 🧠 Архитектура: autoload-синглтоны

Все глобальные сервисы зарегистрированы в `project.godot → [autoload]`:

| Имя                   | Скрипт                              | Роль                                                |
|-----------------------|-------------------------------------|-----------------------------------------------------|
| `GameConstants`       | `globals/game_constants.gd`         | Статы игрока/врагов, сигнал `constants_changed`     |
| `SaveSystem`          | `globals/save_system.gd`            | JSON-сохранения игрока и данжа                      |
| `AudioManager`        | `globals/audio_manager.gd`          | Музыка и SFX, чтение громкости из настроек          |
| `NetworkManager`      | `globals/network_manager.gd`        | Подключение, RPC, кооп-логика                       |
| `PlayerManager`       | `globals/player_manager.gd`         | Спавн игроков, утилиты «ближайший игрок» для AI     |
| `LocalizationManager` | `globals/localization_manager.gd`   | Язык интерфейса (ru/en/az)                          |

Поиск узлов в рантайме — через **группы**: `player`, `local_player`, `enemys`, `map_manager`, `backpack`, `inventory_screen`, `ui_layer`.

---

## 💾 Пользовательские файлы

| Файл                            | Назначение                                                                |
|---------------------------------|---------------------------------------------------------------------------|
| `user://save_game.dat`          | Прогресс игрока, статы, опыт, собранные артефакты                         |
| `user://dungeon_state.dat`      | Seed данжа, посещённые/зачищенные комнаты, плотность препятствий          |
| `user://game_consts.cfg`        | Баланс и размеры карты (`[stats]`), горячая перезагрузка в одиночке       |
| `user://settings.cfg`           | Громкость, частицы, плотность камней, раскладка джойстиков                |

Расположение `user://` — см. [Godot docs: File paths](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html). На Windows это обычно `%APPDATA%\Godot\app_userdata\Dungeon\`.

---

## 📡 Сеть и кооператив

| Тема              | Реализация                                                                 |
|-------------------|----------------------------------------------------------------------------|
| Транспорт         | `ENetMultiplayerPeer`, **порт 4242** (`network_manager.gd:48`)             |
| Максимум игроков  | **8** (1 хост + `MAX_CLIENT_PEERS = 7` гостей)                             |
| Лобби             | `World/UI/lobby.gd`, код комнаты = локальный IP                            |
| Старт забега      | RPC передаёт список peer'ов и снимок `GameConstants`                       |
| Синхрон данжа     | Хост публикует `dungeon_state`, клиенты вызывают `load_dungeon_state()`    |
| Авторитет         | Хост авторитативен для урона, зачисток, лута и перехода этажей             |
| Game over         | Общий — если погиб любой участник                                          |

Подробности RPC — в `globals/network_manager.gd`.

---

## 📚 Дополнительная документация

- [`globals/README.md`](globals/README.md) — баланс, сохранения, константы
- [`World/README.md`](World/README.md) — генерация, двери, туман войны
- [`World/UI/README.md`](World/UI/README.md) — меню, пауза, лобби
- [`scene/game_objects/player/README.md`](scene/game_objects/player/README.md) — игрок, опыт, бой
- [`scene/game_objects/enemy/README.md`](scene/game_objects/enemy/README.md) — враги
- [`scene/game_objects/bosses/README.md`](scene/game_objects/bosses/README.md) — боссы
- [`scene/pick_up/artefacts/README.md`](scene/pick_up/artefacts/README.md) — артефакты
- [`scene/room_variants/README.md`](scene/room_variants/README.md) — устройство комнат
- [`scene/abilities/README.md`](scene/abilities/README.md) — способности
- [`docs/SAVE_SYSTEM.md`](docs/SAVE_SYSTEM.md), [`docs/BACKPACK_SYSTEM.md`](docs/BACKPACK_SYSTEM.md), [`docs/LEVEL_SYSTEM_UI_GUIDE.md`](docs/LEVEL_SYSTEM_UI_GUIDE.md) — углублённые архитектурные заметки.

---

## 🛠️ Сборка

### Android (.apk)

1. В Godot: **Project → Export → Android**.
2. Убедитесь, что в *Editor Settings → Export → Android* настроены пути к **adb**, **JDK 17**, **debug keystore**.
3. Нажмите **Export Project** → выберите путь сохранения. Текущий пресет таргетит `arm64-v8a`, минимальный SDK = 24.

### AuroraOS (.rpm)

Пресет `AuroraOS` (preset.0) собирает под `armv7hl`. Требуется установленный шаблон экспорта AuroraOS для Godot 4.4 (см. [официальную документацию ОмП](https://omprussia.ru/developer)).

---

## 🤝 Contributing

Pull-реквесты и issue приветствуются! Краткие правила:

1. **Форкните** репозиторий и создайте ветку: `git checkout -b feature/<short-description>`.
2. **Стиль кода:** табы для отступов (как в существующем GDScript), `snake_case` для функций/переменных, `PascalCase` для классов и узлов.
3. **Коммиты:** одна логическая правка = один коммит. Префиксы по [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `refactor:`, `docs:`, `chore:`.
4. **Перед PR** прогоните headless smoke-test:
   ```bash
   godot4 --path . --headless --quit-after 1
   ```
   — стартового вывода должно хватать, чтобы убедиться, что нет ошибок импорта.
5. **Не коммитьте** `.godot/`, `user://`-данные, экспортированные `.apk` и сторонние ассеты под несовместимой лицензией.
6. **Описание PR** — что меняется, почему, как тестировалось.

> Раздел Contribution guidelines пока минимальный — если хотите его расширить (CoC, CLA, шаблоны issue/PR), откройте issue с тегом `meta`.

---

## 🐞 Troubleshooting / FAQ

<details>
<summary><strong>«Failed to bind socket» при создании комнаты</strong></summary>

Порт **4242** уже занят другим процессом или заблокирован firewall.
- Закройте предыдущий запуск Godot.
- Откройте 4242/UDP во входящих правилах Windows Defender Firewall.
- Если нужен другой порт — измените `DEFAULT_PORT` в `globals/network_manager.gd`.
</details>

<details>
<summary><strong>Клиент видит «другие» комнаты, чем хост</strong></summary>

Это значит, что сид данжа не дошёл до клиента. Проверьте, что:
- Клиент дождался сигнала `dungeon_sync_received` перед загрузкой.
- В `user://game_consts.cfg` у обоих участников одинаковые `MAP_MANAGER_*` поля **либо** клиент позволил хосту перезаписать константы при старте сессии.
</details>

<details>
<summary><strong>Плагин AS2P не загружается / красные ошибки в Output</strong></summary>

Удалите `.godot/` и перезапустите редактор — Godot переимпортирует все ресурсы. Если ошибки остались, проверьте, что в `project.godot` секция `[editor_plugins]` содержит `res://addons/AS2P/plugin.cfg`.
</details>

<details>
<summary><strong>Сохранения пропали после переустановки</strong></summary>

Сохранения лежат вне репозитория — в `user://` (`%APPDATA%\Godot\app_userdata\Dungeon\` на Windows). Переустановка Godot их не удаляет; удаление профиля Godot — удалит.
</details>

<details>
<summary><strong>Низкий FPS на слабом телефоне</strong></summary>

В *Настройках* выставьте «**Камни → Нет**» — это резко снизит число коллайдеров и партиклов на этаже.
</details>

---

## 📜 License

Распространяется под лицензией **MIT** — см. файл [`LICENSE`](LICENSE).

```
Copyright (c) 2026 top-it-090304
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software ...
```

---

## 🙏 Acknowledgements

- [Godot Engine](https://github.com/savegame/godot/releases/tag/4.4.1-auroraos-4) — open-source движок.
- [AS2P plugin](https://github.com/) (Animated-Sprite2D-to-Polygon2D) — генерация коллизий.
- Виртуальные джойстики — на базе свободно распространяемых аддонов под Godot 4.
- Спасибо всем тестерам и контрибьюторам.

---

## 📬 Контакты

- **Issues / баги:** [GitHub Issues](https://github.com/top-it-090304/OmskDev)
- **Email команды:** `rabotarabocij17@gmail.com n.shmykov@yandex.ru`
- **Discord / Telegram:** `https://t.me/TarlanNaz https://t.me/x00zzz`

---

<sub>Документ предназначен для онбординга разработчиков и презентации продукта. Технические детали всегда уточняйте по актуальному коду в указанных путях.</sub>
