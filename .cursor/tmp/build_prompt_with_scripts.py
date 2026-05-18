# -*- coding: utf-8 -*-
"""Сборка промпта для ИИ со встроенными скриптами проекта Dungeon."""

from pathlib import Path

ROOT = Path(r"D:\Games\game")
OUT = ROOT / "Dungeon_report_prompt_with_scripts.txt"

PROMPT = """Ты — помощник по подготовке учебных проектных отчётов.

Я скидываю тебе PDF-пример отчёта по проектной деятельности и текст ниже со скриптами моей игры. ZIP-архива не будет.

Твоя задача: написать отчёт по проектной деятельности для моей игры, строго по структуре PDF-примера. Структуру, порядок разделов, стиль и логику из примера нужно сохранить максимально близко. Не добавляй лишние разделы.

ИСХОДНЫЕ ДАННЫЕ ПРО ПРОЕКТ

Автор отчёта: Назаров Тарлан.

Тема отчёта: «Разработка 2D roguelike-игры «Dungeon» на игровом движке Godot 4.4.1».

Движок: Godot Engine 4.4.1, пользовательская сборка.
Язык: GDScript.
Жанр: 2D roguelike / dungeon crawler.
Целевая платформа: ПК, в первую очередь Windows. Потенциально возможен экспорт на Linux/macOS и другие платформы Godot.

Основная идея игры: игрок проходит процедурно сгенерированное подземелье, зачищает комнаты, сражается с врагами и боссами, собирает артефакты, получает опыт, улучшает характеристики и сохраняет прогресс. В игре есть одиночный режим и сетевой кооператив на двух игроков.

Сетевой режим: используется Godot Multiplayer API, ENetMultiplayerPeer, RPC-вызовы, модель «хост — клиенты». Хост является авторитетной стороной для урона, врагов, артефактов и синхронизации состояния.

ВАЖНЫЕ ПРАВИЛА

1. Структура отчёта должна быть как в PDF-примере. Не придумывай новые разделы.
2. Если пример отчёта про «Шахматы», замени тему на игру «Dungeon».
3. Если в примере автор Эллерт Владиславович, замени на Назаров Тарлан.
4. Если в примере есть ОС Аврора, Flutter, Dart, Stockfish, шахматные движки или шахматные приложения, адаптируй это под Godot Engine 4.4.1, GDScript, ENetMultiplayerPeer, GameConstants, SaveSystem, NetworkManager, процедурную генерацию, артефакты и roguelike-игры.
5. Можно адаптировать текст внутри разделов под мою игру, но нельзя выдумывать лишние разделы.
6. Используй скрипты ниже как источник фактов о моей игре. Не вставляй код в отчёт, а описывай системы человеческим языком.
7. Если информации из скриптов недостаточно, пиши обобщённо, но не противоречь коду.
8. Используй реальные сведения из интернета о Godot 4.4.1 и аналогах. Не выдумывай факты.
9. Стиль отчёта — деловой, учебный, академический.
10. Итог должен быть готовым текстом для .docx или сразу .docx, если ты умеешь его создавать.

ОФОРМЛЕНИЕ

Сделай как в PDF-примере:
- Times New Roman 14;
- межстрочный интервал 1.5;
- абзацный отступ 1.25 см;
- поля: левое 3 см, правое 1.5 см, верхнее 2 см, нижнее 2 см;
- заголовки разделов жирным;
- крупные разделы с новой страницы;
- таблицы оформить аккуратно;
- подписи к рисункам: «Рисунок 1 — ...»;
- подписи к таблицам: «Таблица 1 — ...».

ОБЯЗАТЕЛЬНАЯ ЛОГИКА РАЗДЕЛОВ

Сохрани разделы из PDF-примера. Если они там есть, сделай:

1. Титульный лист.
2. Реферат.
3. Содержание.
4. Обозначения и сокращения.
5. Введение.
6. Раздел 1 — системный анализ команды/организации/предметной области.
7. Раздел 2 — обоснование разработки программного продукта.
8. IDEF0-модель.
9. Анализ аналогичных программных продуктов.
10. Сравнительная таблица.
11. Обоснование разработки собственного решения.
12. Заключение.
13. Список использованных источников.

ДАННЫЕ ДЛЯ РЕФЕРАТА

Ключевые слова: GODOT, GDSCRIPT, DUNGEON, ROGUELIKE, ПРОЦЕДУРНАЯ ГЕНЕРАЦИЯ, КООПЕРАТИВ, ENET, RPC, АРТЕФАКТЫ, БОССЫ, IDEF0, СИСТЕМНЫЙ АНАЛИЗ.

В реферате кратко напиши, что в работе:
- изучена структура разработки игры Dungeon;
- описан технологический стек;
- построена IDEF0-модель;
- проведён анализ аналогов;
- обоснована необходимость разработки собственной игры.

ДАННЫЕ ДЛЯ IDEF0

Построй IDEF0-модель для системы «Dungeon».

Контекстная диаграмма:
A0 — «Dungeon».

Входы:
- команды игрока;
- выбранный режим игры;
- сохранённые данные;
- настройки игры.

Выходы:
- пройденные комнаты;
- полученный опыт;
- собранные артефакты;
- сохранённый прогресс;
- результат забега.

Механизмы:
- Godot Engine 4.4.1;
- GDScript;
- GameConstants;
- SaveSystem;
- NetworkManager;
- PlayerManager;
- MapManager;
- сцены игроков, врагов, боссов, артефактов;
- ENetMultiplayerPeer.

Управление:
- правила игрового цикла;
- баланс характеристик;
- настройки сложности;
- правила генерации комнат;
- правила сетевой синхронизации;
- ограничения движка Godot.

Декомпозиция A0:
A1 — Инициализировать игру и интерфейс.
A2 — Выбрать режим игры.
A3 — Сгенерировать этаж подземелья.
A4 — Выполнить игровой цикл комнаты.
A5 — Обработать прогрессию игрока.
A6 — Сохранить и завершить забег.

Декомпозиция A1:
A1.1 — Загрузить пользовательский интерфейс.
A1.2 — Применить настройки.
A1.3 — Загрузить сохранённое состояние.
A1.4 — Подготовить главное меню.

АНАЛОГИ ДЛЯ СРАВНЕНИЯ

Используй реальные аналоги:
1. The Binding of Isaac.
2. Enter the Gungeon.
3. Hades.

Сравни их с Dungeon по критериям:
- жанр;
- процедурная генерация;
- боевая система;
- наличие кооператива;
- онлайн/локальный режим;
- движок;
- открытость и возможность модификации;
- стоимость;
- образовательная ценность.

ЧТО НУЖНО В ИТОГЕ

Сгенерируй отчёт, похожий на PDF-пример, но про игру Dungeon.

Обязательно должны быть:
- титульный лист с автором Назаров Тарлан;
- реферат;
- содержание;
- обозначения и сокращения;
- введение;
- описание команды/студии Dungeon Studio;
- описание ролей в команде;
- описание технологии Godot 4.4.1 + GDScript;
- описание сетевого режима ENet/RPC;
- IDEF0-модель;
- анализ аналогов;
- сравнительная таблица;
- обоснование разработки;
- заключение;
- список источников.

Если можешь создать .docx, создай файл Project_Dungeon.docx. Если не можешь создать файл, выдай готовый текст отчёта с заголовками, таблицами и подписями рисунков.

Ниже идут скрипты и конфигурационные файлы проекта. Используй их только как источник фактов.
"""

IMPORTANT_ORDER = [
    "globals/game_constants.gd",
    "globals/save_system.gd",
    "globals/network_manager.gd",
    "globals/player_manager.gd",
    "globals/audio_manager.gd",
    "World/map_manager.gd",
    "World/minimap.gd",
    "World/UI/menu.gd",
    "World/UI/lobby.gd",
    "World/UI/multiplayer_menu.gd",
    "World/UI/settings.gd",
    "World/UI/paused.gd",
    "scene/game_objects/player/player.gd",
    "scene/game_objects/player2/player_2.gd",
    "scene/game_objects/player/backpack.gd",
    "scene/game_objects/player/health.gd",
    "scene/game_objects/player/cooldown.gd",
    "scene/abilities/fireball.gd",
    "scene/ui/inventory_screen.gd",
    "scene/ui/stats_panel.gd",
    "scene/ui/damage_popup.gd",
    "scene/ui/level_up_popup.gd",
    "scene/ui/artefact_popup.gd",
    "scene/pick_up/artefacts/artefact_base.gd",
    "scene/pick_up/artefacts/artefact_pickup.gd",
    "scene/pick_up/artefacts/artefact_pedestal.gd",
    "scene/game_objects/enemy/enemy_base.gd",
    "scene/game_objects/enemy/goblin_axe/enemy(goblin_axe).gd",
    "scene/game_objects/enemy/skeleton_grunt/enemy(skeleton_grunt).gd",
    "scene/game_objects/enemy/skeleton_grunt/skeleton_grunt.gd",
    "scene/game_objects/enemy/goblin_slinger/goblin_slinger.gd",
    "scene/game_objects/enemy/skeleton_bow/skeleton_bow.gd",
    "scene/game_objects/enemy/magican/magican.gd",
    "scene/game_objects/enemy/manStick/man_stick.gd",
    "scene/game_objects/bosses/govlinRaider/goblin_raider.gd",
    "scene/game_objects/bosses/govlinRaider/raider_rock_projectile.gd",
    "scene/game_objects/bosses/goblin/beast_goblin.gd",
    "scene/game_objects/bosses/skeletonSwordman/skeleton_swordman.gd",
    "scene/game_objects/bosses/skeletonSwordman/skeleton_sword_wave.gd",
    "scene/game_objects/bosses/skeleton_king/skeleton_king.gd",
    "scene/effects/big_wave.gd",
    "scene/level/enemys.gd",
    "scene/level/room_shape.gd",
    "scene/room_variants/BaseRoom[0]/base_room_0.gd",
    "scene/room_variants/BaseRoom[0]/door.gd",
    "scene/room_variants/forest/forest_room.gd",
    "globals/game_consts.cfg",
    "project.godot",
]

SKIP_PARTS = {".git", ".godot", ".cursor", "addons"}


def norm_rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def find_file(rel: str) -> Path | None:
    direct = ROOT / rel
    if direct.is_file():
        return direct
    target = rel.replace("\\", "/").lower()
    for cand in ROOT.rglob(Path(rel).name):
        if norm_rel(cand).lower() == target:
            return cand
    return None


def read_text(path: Path) -> str:
    for enc in ("utf-8", "utf-8-sig"):
        try:
            return path.read_text(encoding=enc)
        except UnicodeDecodeError:
            continue
    return path.read_text(encoding="utf-8", errors="replace")


def collect_files() -> list[Path]:
    selected: list[Path] = []
    seen: set[str] = set()

    for rel in IMPORTANT_ORDER:
        p = find_file(rel)
        if p is None:
            continue
        key = str(p.resolve()).lower()
        if key not in seen:
            selected.append(p)
            seen.add(key)

    for p in sorted(ROOT.rglob("*.gd"), key=lambda x: norm_rel(x).lower()):
        if set(p.relative_to(ROOT).parts) & SKIP_PARTS:
            continue
        key = str(p.resolve()).lower()
        if key not in seen:
            selected.append(p)
            seen.add(key)

    for name in ("globals/game_consts.cfg", "project.godot"):
        p = find_file(name)
        if p is None:
            continue
        key = str(p.resolve()).lower()
        if key not in seen:
            selected.append(p)
            seen.add(key)

    return selected


def main() -> None:
    files = collect_files()
    with OUT.open("w", encoding="utf-8-sig", newline="\n") as f:
        f.write(PROMPT)
        f.write("\n\n==================== PROJECT FILES START ====================\n")
        for p in files:
            rel = norm_rel(p)
            text = read_text(p).rstrip()
            fence = "gdscript" if p.suffix == ".gd" else "text"
            f.write(f"\n\n--- FILE: {rel} ---\n")
            f.write(f"```{fence}\n{text}\n```\n")
        f.write("\n==================== PROJECT FILES END ====================\n")

    print(f"created={OUT}")
    print(f"files_included={len(files)}")
    print(f"size_kb={OUT.stat().st_size / 1024:.1f}")


if __name__ == "__main__":
    main()
