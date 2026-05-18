"""
Сборка отчёта «Проектная деятельность» по игре Dungeon
по структуре Primer.pdf. Автор: Назаров Тарлан.
"""

from pathlib import Path

from docx import Document
from docx.enum.table import WD_ALIGN_VERTICAL, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_LINE_SPACING
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor


OUT = Path(r"D:\Games\game\Project_Dungeon_final.docx")


# ---------- helpers ----------
def set_font(run, size=14, bold=False):
    run.font.name = "Times New Roman"
    run._element.rPr.rFonts.set(qn("w:eastAsia"), "Times New Roman")
    run.font.size = Pt(size)
    run.bold = bold
    run.font.color.rgb = RGBColor(0, 0, 0)


def add_par(doc, text, *, align=None, bold=False, size=14, first_line=True, space_after=0):
    p = doc.add_paragraph()
    if align is not None:
        p.alignment = align
    fmt = p.paragraph_format
    fmt.line_spacing_rule = WD_LINE_SPACING.ONE_POINT_FIVE
    fmt.space_after = Pt(space_after)
    if first_line:
        fmt.first_line_indent = Cm(1.25)
    r = p.add_run(text)
    set_font(r, size=size, bold=bold)
    return p


def add_heading_1(doc, text):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.LEFT
    fmt = p.paragraph_format
    fmt.line_spacing_rule = WD_LINE_SPACING.ONE_POINT_FIVE
    fmt.space_before = Pt(12)
    fmt.space_after = Pt(6)
    fmt.first_line_indent = Cm(0)
    r = p.add_run(text)
    set_font(r, size=16, bold=True)
    return p


def add_heading_centered(doc, text, size=16):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    fmt = p.paragraph_format
    fmt.space_before = Pt(0)
    fmt.space_after = Pt(12)
    fmt.first_line_indent = Cm(0)
    r = p.add_run(text)
    set_font(r, size=size, bold=True)
    return p


def add_heading_2(doc, text):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.LEFT
    fmt = p.paragraph_format
    fmt.line_spacing_rule = WD_LINE_SPACING.ONE_POINT_FIVE
    fmt.space_before = Pt(8)
    fmt.space_after = Pt(4)
    fmt.first_line_indent = Cm(0)
    r = p.add_run(text)
    set_font(r, size=14, bold=True)
    return p


def add_dash(doc, text):
    p = doc.add_paragraph()
    fmt = p.paragraph_format
    fmt.line_spacing_rule = WD_LINE_SPACING.ONE_POINT_FIVE
    fmt.left_indent = Cm(1.25)
    fmt.first_line_indent = Cm(0)
    r = p.add_run("− " + text)
    set_font(r, size=14)
    return p


def shade(cell, fill):
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:fill"), fill)
    tc_pr.append(shd)


def add_table(doc, headers, rows):
    table = doc.add_table(rows=1, cols=len(headers))
    table.style = "Table Grid"
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    head = table.rows[0].cells
    for i, h in enumerate(headers):
        head[i].text = ""
        head[i].vertical_alignment = WD_ALIGN_VERTICAL.CENTER
        shade(head[i], "D9EAF7")
        p = head[i].paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        r = p.add_run(h)
        set_font(r, size=12, bold=True)
    for row in rows:
        cells = table.add_row().cells
        for i, value in enumerate(row):
            cells[i].text = ""
            cells[i].vertical_alignment = WD_ALIGN_VERTICAL.TOP
            p = cells[i].paragraphs[0]
            p.alignment = WD_ALIGN_PARAGRAPH.LEFT if i > 0 else WD_ALIGN_PARAGRAPH.LEFT
            r = p.add_run(str(value))
            set_font(r, size=12)
    return table


# ---------- document ----------
doc = Document()
sec = doc.sections[0]
sec.top_margin = Cm(2)
sec.bottom_margin = Cm(2)
sec.left_margin = Cm(3)
sec.right_margin = Cm(1.5)

doc.styles["Normal"].font.name = "Times New Roman"
doc.styles["Normal"].font.size = Pt(14)

# ===== Титульный лист =====
add_par(doc, "МИНИСТЕРСТВО НАУКИ И ВЫСШЕГО ОБРАЗОВАНИЯ", align=WD_ALIGN_PARAGRAPH.CENTER, bold=True, first_line=False, size=12)
add_par(doc, "Учебный проект", align=WD_ALIGN_PARAGRAPH.CENTER, bold=True, first_line=False, size=12)
add_par(doc, "", first_line=False)
add_par(doc, "", first_line=False)
add_par(doc, "ПРОЕКТНАЯ ДЕЯТЕЛЬНОСТЬ", align=WD_ALIGN_PARAGRAPH.CENTER, bold=True, first_line=False, size=20)
add_par(doc, "", first_line=False)
add_par(doc, "Тема: «Разработка 2D roguelike-игры «Dungeon» на игровом движке Godot 4.4.1»",
        align=WD_ALIGN_PARAGRAPH.CENTER, bold=True, first_line=False, size=14)
add_par(doc, "", first_line=False)
add_par(doc, "", first_line=False)
add_par(doc, "", first_line=False)
add_par(doc, "Выполнил: Назаров Тарлан", align=WD_ALIGN_PARAGRAPH.RIGHT, first_line=False)
add_par(doc, "Проверил: ______________________", align=WD_ALIGN_PARAGRAPH.RIGHT, first_line=False)
add_par(doc, "", first_line=False)
add_par(doc, "", first_line=False)
add_par(doc, "2026 г.", align=WD_ALIGN_PARAGRAPH.CENTER, first_line=False)
doc.add_page_break()

# ===== РЕФЕРАТ =====
add_heading_centered(doc, "РЕФЕРАТ")
add_par(doc, "Отчет 25 с., 3 рисунка, 1 таблица.")
add_par(doc,
        "GODOT, GDSCRIPT, КОМПЬЮТЕРНАЯ ИГРА, ROGUELIKE, "
        "ПРОЦЕДУРНАЯ ГЕНЕРАЦИЯ, КООПЕРАТИВ, IDEF0-МОДЕЛЬ, "
        "РАЗРАБОТКА ПРОГРАММНОГО ПРОДУКТА, АНАЛИЗ АНАЛОГОВ, "
        "ОБОСНОВАНИЕ РАЗРАБОТКИ.")
add_par(doc,
        "В этой работе была изучена организация процесса разработки в небольшой "
        "инди-студии Dungeon Studio и обоснована разработка собственной 2D "
        "roguelike-игры «Dungeon» на игровом движке Godot 4.4.1 в сравнении "
        "с уже существующими на рынке играми этого жанра.")
add_par(doc,
        "Главная задача работы — разобраться с управлением и организационной "
        "структурой команды Dungeon Studio, составить и проанализировать "
        "IDEF0-модель собственной игры, а также обосновать, для чего нужен данный "
        "программный продукт и в чем состоит его эффект.")
add_par(doc, "По ходу проекта были выполнены следующие задачи:")
add_dash(doc, "проведён анализ команды разработки Dungeon Studio — рассмотрены роли (руководитель проекта, геймдизайнер, программисты, дизайнер уровней, UI/UX-дизайнер, QA);")
add_dash(doc, "построена IDEF0-модель игры с тремя уровнями, на которой показано, как работает запуск игры, генерация подземелья, бой, прогрессия игрока и сохранение результата;")
add_dash(doc, "сравнены похожие игры — The Binding of Isaac, Enter the Gungeon и Hades — по их функциональности, технологическому стеку и поддерживаемым платформам.")
add_par(doc,
        "Результатами работы являются: организационная структура команды Dungeon "
        "Studio с распределёнными ролями и задачами, обоснованный технологический "
        "стек на базе Godot 4.4.1 и GDScript, IDEF0-модель игры «Dungeon», а также "
        "аргументированное сравнением с аналогичными продуктами обоснование "
        "разработки собственной игры.")
doc.add_page_break()

# ===== Содержание =====
add_heading_centered(doc, "Содержание")
toc_items = [
    "Обозначения и сокращения",
    "ВВЕДЕНИЕ",
    "1 СИСТЕМНЫЙ АНАЛИЗ КОМАНДЫ РАЗРАБОТКИ И ОРГАНИЗАЦИОННОЙ СТРУКТУРЫ СТУДИИ DUNGEON STUDIO",
    "    1.1 Студия-исполнитель — история команды Dungeon Studio",
    "    1.2 Организационная структура команды Dungeon Studio",
    "    1.3 Функции и задачи участников команды",
    "2 ОБОСНОВАНИЕ РАЗРАБОТКИ ПРОГРАММНОГО ПРОДУКТА «DUNGEON» НА GODOT 4.4.1",
    "    2.1 Программное обеспечение и технические средства",
    "    2.2 IDEF0-модель системы",
    "    2.3 Анализ аналогичных программных продуктов",
    "    2.4 Сравнительный анализ аналогичных приложений",
    "    2.5 Обоснование разработки собственного решения",
    "ЗАКЛЮЧЕНИЕ",
    "Список использованных источников",
]
for item in toc_items:
    add_par(doc, item, first_line=False)
doc.add_page_break()

# ===== Обозначения и сокращения =====
add_heading_centered(doc, "Обозначения и сокращения:")
abbrs = [
    "API — Application Programming Interface (программный интерфейс приложения);",
    "CI/CD — Continuous Integration / Continuous Delivery (непрерывная интеграция и доставка);",
    "ENet — сетевая библиотека на основе UDP, используемая Godot для мультиплеера;",
    "FPS — Frames Per Second (количество кадров в секунду);",
    "GDScript — встроенный скриптовый язык программирования движка Godot;",
    "IDE — Integrated Development Environment (интегрированная среда разработки);",
    "IDEF0 — Integration Definition for Function Modeling (методология функционального моделирования);",
    "LAN — Local Area Network (локальная вычислительная сеть);",
    "RNG — Random Number Generator (генератор псевдослучайных чисел);",
    "RPC — Remote Procedure Call (удалённый вызов процедуры);",
    "SFX — Sound Effects (звуковые эффекты);",
    "UDP — User Datagram Protocol (протокол передачи дейтаграмм);",
    "UI — User Interface (пользовательский интерфейс);",
    "UX — User Experience (пользовательский опыт);",
    "ИИ — искусственный интеллект;",
    "ИТ — информационные технологии;",
    "ПК — персональный компьютер;",
    "ПО — программное обеспечение;",
    "ТЗ — техническое задание.",
]
for a in abbrs:
    add_par(doc, a, first_line=False)
doc.add_page_break()

# ===== ВВЕДЕНИЕ =====
add_heading_centered(doc, "ВВЕДЕНИЕ")
add_par(doc,
        "В современной индустрии разработки развлекательного программного обеспечения "
        "значительную долю занимают независимые (инди) студии. Они используют "
        "доступные средства разработки и распространения, что позволяет небольшим "
        "командам выпускать законченные игровые продукты в популярных жанрах. "
        "Одним из таких жанров является roguelike — игры с процедурно "
        "генерируемыми уровнями, постоянной смертью персонажа и высокой "
        "реиграбельностью.")
add_par(doc,
        "Для разработки игры «Dungeon» был выбран открытый кроссплатформенный "
        "движок Godot версии 4.4.1 (пользовательская сборка). Godot 4.4.1 — это "
        "поддерживающий релиз, вышедший 26 марта 2025 года, в который вошло около "
        "125 исправлений от 58 разработчиков сообщества, включая обновления "
        "сетевой подсистемы и исправления безопасности библиотеки mbedTLS. Эти "
        "улучшения важны для проектов, использующих мультиплеер, к которым "
        "относится и «Dungeon».")
add_par(doc,
        "Несмотря на наличие на рынке успешных roguelike-игр для ПК (The Binding "
        "of Isaac, Enter the Gungeon, Hades), большинство из них являются "
        "коммерческими, закрытыми по исходному коду и не имеют возможностей для "
        "учебной модификации. Для образовательных и демонстрационных целей "
        "целесообразно иметь собственный открытый проект, в котором можно "
        "изучать архитектуру игр, процедурную генерацию, боевую систему и "
        "сетевой кооператив.")
add_par(doc,
        "Цель данной работы — провести системный анализ организационной "
        "структуры студии-исполнителя и процессов разработки, а также обосновать "
        "необходимость создания собственной 2D roguelike-игры «Dungeon» на движке "
        "Godot 4.4.1. Также необходимо определить требования к архитектуре "
        "системы, функциональным компонентам игры и технологическому стеку, "
        "который будет использоваться при разработке. В ходе работы будут "
        "исследованы существующие аналогичные программные продукты, выявлены "
        "их сильные и слабые стороны, а также определены конкурентные "
        "преимущества решения собственного продукта.")
doc.add_page_break()

# ===== 1. Раздел =====
add_heading_1(doc, "1 СИСТЕМНЫЙ АНАЛИЗ КОМАНДЫ РАЗРАБОТКИ И ОРГАНИЗАЦИОННОЙ СТРУКТУРЫ СТУДИИ DUNGEON STUDIO")

add_heading_2(doc, "1.1 Студия-исполнитель — история команды Dungeon Studio")
add_par(doc,
        "Dungeon Studio — небольшая инди-команда разработчиков, специализирующаяся "
        "на создании игр в жанрах roguelike и action-adventure. Команда работает "
        "по принципам гибкой методологии разработки и применяет инженерный "
        "подход к решению игровых задач.")
add_par(doc,
        "За время своей деятельности команда реализовала несколько прототипов и "
        "учебных проектов, среди которых «Dungeon» является основным продуктом. "
        "В команде состоят разработчики, геймдизайнеры, специалисты по интерфейсу "
        "и тестировщики. Часть работ выполняется распределённо.")
add_par(doc, "Ключевые направления деятельности команды:")
add_dash(doc, "разработка 2D-игр на движке Godot 4.4.1;")
add_dash(doc, "проектирование процедурной генерации уровней;")
add_dash(doc, "реализация сетевого кооператива на основе ENetMultiplayerPeer;")
add_dash(doc, "разработка инструментов баланса и систем сохранений;")
add_dash(doc, "обеспечение качества (QA) и тестирование игровых билдов.")

add_heading_2(doc, "1.2 Организационная структура команды Dungeon Studio")
add_par(doc,
        "Организационная структура Dungeon Studio соответствует типичной "
        "структуре небольшой инди-команды и включает следующие роли:")
add_par(doc, "Уровень руководства:", first_line=False)
add_dash(doc, "Руководитель проекта (Project Manager) — Назаров Тарлан;")
add_dash(doc, "Ведущий программист (Tech Lead) — Назаров Тарлан;")
add_dash(doc, "Ведущий геймдизайнер (Lead Game Designer) — Назаров Тарлан.")
add_par(doc, "Основные направления:", first_line=False)
add_par(doc, "Отдел программирования:", first_line=False)
add_dash(doc, "программист игровой логики (GDScript);")
add_dash(doc, "программист сетевой части (RPC, ENet);")
add_dash(doc, "программист UI и систем сохранений.")
add_par(doc, "Отдел геймдизайна:", first_line=False)
add_dash(doc, "ведущий геймдизайнер (механики, баланс, прогрессия);")
add_dash(doc, "дизайнер уровней (комнаты, коридоры, расстановка препятствий);")
add_dash(doc, "дизайнер врагов и боссов (поведение, атаки, награды).")
add_par(doc, "Отдел графики и звука:", first_line=False)
add_dash(doc, "художник 2D-спрайтов;")
add_dash(doc, "UI/UX-дизайнер;")
add_dash(doc, "звукорежиссёр и композитор.")
add_par(doc, "Отдел качества и тестирования:", first_line=False)
add_dash(doc, "QA-инженер по функциональному тестированию;")
add_dash(doc, "тестировщик баланса и сетевого режима.")

add_heading_2(doc, "1.3 Функции и задачи участников команды")
add_par(doc, "Руководитель проекта (Project Manager):")
add_dash(doc, "формирование общего плана и сроков разработки;")
add_dash(doc, "распределение задач между участниками команды;")
add_dash(doc, "контроль качества и приёмка результатов работы;")
add_dash(doc, "представление продукта на демонстрациях и защите.")
add_par(doc, "Ведущий программист (Tech Lead):")
add_dash(doc, "выбор технологического стека и архитектуры проекта;")
add_dash(doc, "проектирование автозагрузок GameConstants, SaveSystem, NetworkManager;")
add_dash(doc, "проведение ревью кода (Code Review) и поддержание стандартов GDScript;")
add_dash(doc, "решение наиболее сложных технических задач.")
add_par(doc, "Программисты игровой логики:")
add_dash(doc, "разработка игрока, врагов, боссов и их поведения на GDScript;")
add_dash(doc, "реализация боевой системы, способностей и снарядов;")
add_dash(doc, "написание сцен Godot и сигналов между ними;")
add_dash(doc, "написание модульных проверок и отладочных скриптов.")
add_par(doc, "Программист сетевой части:")
add_dash(doc, "настройка ENetMultiplayerPeer и синхронизация сессии;")
add_dash(doc, "реализация авторитетной модели «host — clients»;")
add_dash(doc, "проектирование RPC-функций для урона, артефактов и зачистки комнат;")
add_dash(doc, "оптимизация сетевого трафика и снижение задержек.")
add_par(doc, "Программист UI и сохранений:")
add_dash(doc, "разработка интерфейса здоровья, опыта, инвентаря и миникарты;")
add_dash(doc, "реализация системы сохранений в user://-файлах;")
add_dash(doc, "поддержка экрана характеристик и просмотра артефактов;")
add_dash(doc, "обеспечение читаемости и удобства управления.")
add_par(doc, "Геймдизайнер:")
add_dash(doc, "проектирование игрового цикла «комната → бой → награда → этаж»;")
add_dash(doc, "проработка характеристик игрока, врагов и боссов;")
add_dash(doc, "разработка системы артефактов и редкостей;")
add_dash(doc, "настройка баланса этажей и сложности противников.")
add_par(doc, "Дизайнер уровней и врагов:")
add_dash(doc, "создание шаблонов комнат и коридоров;")
add_dash(doc, "расстановка препятствий и точек интереса;")
add_dash(doc, "проектирование поведения и атак врагов и боссов;")
add_dash(doc, "тестирование читаемости пространства комнаты.")
add_par(doc, "Художник 2D и UI/UX-дизайнер:")
add_dash(doc, "подготовка спрайтов персонажей, врагов, окружения и артефактов;")
add_dash(doc, "анимация и работа со SpriteFrames;")
add_dash(doc, "оформление меню, окон инвентаря, миникарты и подсказок;")
add_dash(doc, "обеспечение единого визуального стиля игры.")
add_par(doc, "QA-инженер:")
add_dash(doc, "проведение функционального и регрессионного тестирования;")
add_dash(doc, "разработка тест-планов для игрового цикла и сетевых сценариев;")
add_dash(doc, "регистрация и сопровождение ошибок;")
add_dash(doc, "проверка стабильности сборок и сохранений.")
doc.add_page_break()

# ===== 2. Раздел =====
add_heading_1(doc, "2 ОБОСНОВАНИЕ РАЗРАБОТКИ ПРОГРАММНОГО ПРОДУКТА «DUNGEON» НА GODOT 4.4.1")

add_heading_2(doc, "2.1 Программное обеспечение и технические средства")
add_par(doc,
        "Технологический стек проекта «Dungeon» подобран с учётом скорости "
        "прототипирования, наличия встроенных игровых систем, поддержки "
        "мультиплеера и возможности экспорта на разные платформы.")
add_par(doc, "Игровой движок и язык:", first_line=False)
add_dash(doc, "движок: Godot Engine 4.4.1 (пользовательская сборка от 23.06.2025);")
add_dash(doc, "язык программирования: GDScript;")
add_dash(doc, "архитектура: сцены Godot и автозагрузки (singleton);")
add_dash(doc, "редактор: Godot Editor, Cursor IDE;")
add_dash(doc, "система контроля версий: Git.")
add_par(doc, "Графика и звук:", first_line=False)
add_dash(doc, "формат графики: 2D-спрайты, AnimatedSprite2D;")
add_dash(doc, "интерфейс: Control-узлы Godot, CanvasLayer;")
add_dash(doc, "звук: AudioStreamPlayer, отдельные шины Music и SFX;")
add_dash(doc, "плагины: AS2P (генерация коллизий из анимации).")
add_par(doc, "Сетевая часть:", first_line=False)
add_dash(doc, "транспорт: ENetMultiplayerPeer (UDP);")
add_dash(doc, "модель: авторитетный хост и клиенты;")
add_dash(doc, "вызовы: аннотации @rpc, including @rpc(any_peer) и @rpc(call_local);")
add_dash(doc, "идентификация: multiplayer.get_remote_sender_id().")
add_par(doc, "Хранение данных и баланс:", first_line=False)
add_dash(doc, "save_game.dat — прогресс игрока и собранные артефакты;")
add_dash(doc, "dungeon_state.dat — состояние процедурного подземелья;")
add_dash(doc, "game_consts.cfg — конфигурируемый баланс с горячей перезагрузкой;")
add_dash(doc, "settings.cfg — пользовательские настройки звука и графики.")
add_par(doc, "Целевые платформы:", first_line=False)
add_dash(doc, "основная: ПК на Windows, Linux, macOS;")
add_dash(doc, "потенциальная: мобильные устройства (адаптированное управление);")
add_dash(doc, "тестирование: запуск из редактора и собранный билд Godot.")

add_heading_2(doc, "2.2 IDEF0-модель системы")
add_par(doc, "Рисунок 1 — А0: «Dungeon»", align=WD_ALIGN_PARAGRAPH.CENTER, first_line=False)
add_par(doc, "А0: «Dungeon»", first_line=False, bold=True)
add_par(doc,
        "Назначение: обеспечить пользователю возможность проходить процедурное "
        "подземелье как в одиночном режиме, так и в сетевом кооперативе с другим "
        "игроком, с получением артефактов, ростом характеристик и сохранением "
        "прогресса.")
add_par(doc, "Входы:", first_line=False)
add_dash(doc, "команды пользователя (управление, выбор пунктов меню);")
add_dash(doc, "сигнал на запуск;")
add_dash(doc, "ранее сохранённые данные.")
add_par(doc, "Выходы:", first_line=False)
add_dash(doc, "состояние персонажа и подземелья на момент выхода;")
add_dash(doc, "сохранённый прогресс с результатами забега;")
add_dash(doc, "статистика и собранные артефакты.")
add_par(doc, "Механизмы (ресурсы):", first_line=False)
add_dash(doc, "игра на движке Godot 4.4.1;")
add_dash(doc, "GDScript-скрипты игровых сцен;")
add_dash(doc, "автозагрузки GameConstants, SaveSystem, NetworkManager, PlayerManager;")
add_dash(doc, "сетевой компонент ENetMultiplayerPeer.")
add_par(doc, "Управление (ограничения):", first_line=False)
add_dash(doc, "правила игрового цикла и баланс;")
add_dash(doc, "конфигурации приложения и параметры запуска;")
add_dash(doc, "требования удобства использования (UX);")
add_dash(doc, "ограничения сетевого режима (хост — клиенты).")

add_par(doc, "Декомпозиция A0: основные процессы системы", bold=True, first_line=False)
add_par(doc,
        "Система разбивается на шесть основных функций A1–A6. Функции A1–A3 "
        "представлены на следующем рисунке:")
add_par(doc, "Рисунок 2 — Декомпозиция A0, функции A1–A3", align=WD_ALIGN_PARAGRAPH.CENTER, first_line=False)

add_par(doc, "A1: Инициализировать игру и интерфейс", bold=True, first_line=False)
add_dash(doc, "Входы: сигнал на запуск.")
add_dash(doc, "Выходы: инициализированное состояние приложения и главное меню.")
add_dash(doc, "Механизмы: Godot Editor runtime, UI на Control-узлах, локальное хранилище настроек.")
add_dash(doc, "Управление: правила навигации, темы, языки, UX-требования.")

add_par(doc, "A2: Выбирать режим игры", bold=True, first_line=False)
add_dash(doc, "Входы: инициализированное состояние приложения, команды пользователя.")
add_dash(doc, "Выходы: режим Singleplayer или режим Multiplayer.")
add_dash(doc, "Механизмы: меню Godot, лобби-сцена.")
add_dash(doc, "Управление: доступные режимы, состояние сохранения.")

add_par(doc, "A3: Генерировать этаж подземелья", bold=True, first_line=False)
add_dash(doc, "Входы: выбранный режим, текущий номер этажа.")
add_dash(doc, "Выходы: процедурно созданная карта комнат и коридоров.")
add_dash(doc, "Механизмы: MapManager, RNG, шаблоны комнат, баланс этажа.")
add_dash(doc, "Управление: размер сетки комнат, количество сокровищниц, правила размещения босса.")

add_par(doc, "Рисунок 3 — Декомпозиция A0, функции A4–A6", align=WD_ALIGN_PARAGRAPH.CENTER, first_line=False)

add_par(doc, "A4: Выполнять игровой цикл комнаты", bold=True, first_line=False)
add_dash(doc, "Входы: процедурная карта, текущая комната, действия игрока.")
add_dash(doc, "Выходы: состояние боя, награды, очищенная комната.")
add_dash(doc, "Механизмы: сцены врагов и боссов, боевая система, NetworkManager в кооперативе.")
add_dash(doc, "Управление: правила боя, характеристики игрока, баланс врагов.")

add_par(doc, "A5: Обработать прогрессию игрока", bold=True, first_line=False)
add_dash(doc, "Входы: полученный опыт, найденные артефакты.")
add_dash(doc, "Выходы: новый уровень, обновлённые характеристики, обновлённый инвентарь.")
add_dash(doc, "Механизмы: GameConstants, инвентарь, экран характеристик.")
add_dash(doc, "Управление: правила прогрессии, формулы опыта.")

add_par(doc, "A6: Сохранять и завершать забег", bold=True, first_line=False)
add_dash(doc, "Входы: результаты этажа, действия игрока.")
add_dash(doc, "Выходы: сохранённый прогресс, экран завершения, переход на новый этаж.")
add_dash(doc, "Механизмы: SaveSystem, файлы user://save_game.dat и user://dungeon_state.dat.")
add_dash(doc, "Управление: правила сохранений, условия завершения забега.")

add_par(doc, "Декомпозиция функции A1 на A1.1–A1.4", bold=True, first_line=False)
add_par(doc, "Рисунок 4 — Декомпозиция функции A1 на A1.1–A1.4", align=WD_ALIGN_PARAGRAPH.CENTER, first_line=False)

add_par(doc, "A1.1: Загружать пользовательский интерфейс", bold=True, first_line=False)
add_dash(doc, "Вход: сигнал на запуск.")
add_dash(doc, "Выходы: загруженный интерфейс приложения, настройки приложения.")
add_dash(doc, "Механизмы: Control-узлы Godot, локальное хранилище настроек.")
add_dash(doc, "Управление: правила загрузки, навигации, UX-гайдлайн проекта.")

add_par(doc, "A1.2: Применять настройки графики и звука", bold=True, first_line=False)
add_dash(doc, "Входы: загруженный интерфейс, настройки приложения.")
add_dash(doc, "Выходы: оформленный интерфейс с применёнными настройками.")
add_dash(doc, "Механизмы: AudioServer, UI Godot, файл settings.cfg.")
add_dash(doc, "Управление: правила оформления, ограничения по громкости.")

add_par(doc, "A1.3: Загружать сохранённое состояние", bold=True, first_line=False)
add_dash(doc, "Входы: оформленный интерфейс.")
add_dash(doc, "Выходы: подготовленный экран продолжения или новой игры.")
add_dash(doc, "Механизмы: SaveSystem, JSON-парсер.")
add_dash(doc, "Управление: формат файлов user://save_game.dat и user://dungeon_state.dat.")

add_par(doc, "A1.4: Готовить главное меню", bold=True, first_line=False)
add_dash(doc, "Входы: подготовленные данные сохранений.")
add_dash(doc, "Выходы: инициализированное состояние приложения, активное главное меню.")
add_dash(doc, "Механизмы: сцена главного меню, GameConstants.")
add_dash(doc, "Управление: правила навигации между экранами.")

add_heading_2(doc, "2.3 Анализ аналогичных программных продуктов")
add_par(doc,
        "На современном рынке существует несколько популярных игр, реализующих "
        "жанр roguelike с процедурной генерацией и боевой системой. Ниже "
        "рассмотрены основные аналоги.")

add_par(doc, "The Binding of Isaac — классический представитель жанра", bold=True, first_line=False)
add_par(doc,
        "The Binding of Isaac — одна из наиболее влиятельных roguelike-игр, "
        "положивших начало современному формату «комната за комнатой». В игре "
        "присутствует процедурно собранное подземелье, большое количество "
        "предметов, постоянная смерть персонажа и высокая реиграбельность.")
add_par(doc, "Основные функции:", first_line=False)
add_dash(doc, "процедурная генерация этажей и комнат;")
add_dash(doc, "большое количество предметов с синергиями;")
add_dash(doc, "разнообразные боссы и враги;")
add_dash(doc, "несколько режимов сложности и режимов игры;")
add_dash(doc, "одиночный режим без кооператива (в базовой версии).")
add_par(doc, "Технологический стек:", first_line=False)
add_dash(doc, "движок: Flash (исходная версия), позже собственный движок;")
add_dash(doc, "язык: ActionScript и C++;")
add_dash(doc, "распространение: Steam, консоли.")
add_par(doc, "Платформы поддержки: PC, PlayStation, Xbox, Nintendo Switch, мобильные платформы.", first_line=False)

add_par(doc, "Enter the Gungeon — bullet-hell roguelike", bold=True, first_line=False)
add_par(doc,
        "Enter the Gungeon — динамичный roguelike с упором на стрельбу, "
        "уклонение от снарядов и сочетания оружия. Игра реализована как "
        "twin-stick шутер с видом сверху.")
add_par(doc, "Основные функции:", first_line=False)
add_dash(doc, "процедурная генерация подземелья с фиксированными элементами;")
add_dash(doc, "большое количество видов оружия и предметов;")
add_dash(doc, "сложная боевая система с уклонением (dodge roll);")
add_dash(doc, "локальный кооператив для двух игроков;")
add_dash(doc, "ярко выраженный визуальный стиль pixel art.")
add_par(doc, "Технологический стек:", first_line=False)
add_dash(doc, "движок: Unity;")
add_dash(doc, "язык: C#;")
add_dash(doc, "распространение: Steam, GOG, консоли.")
add_par(doc, "Платформы поддержки: PC, PlayStation, Xbox, Nintendo Switch.", first_line=False)

add_par(doc, "Hades — action-roguelike с сильным нарративом", bold=True, first_line=False)
add_par(doc,
        "Hades — action-roguelite, разработанный студией Supergiant Games. Игра "
        "отличается тщательно проработанной боевой системой, фокусом на "
        "повествовании и системой «постоянных смертей» как части сюжета.")
add_par(doc, "Основные функции:", first_line=False)
add_dash(doc, "ближний бой с разными типами оружия;")
add_dash(doc, "сюжетная прогрессия после каждой смерти;")
add_dash(doc, "благословения богов и мета-прогрессия;")
add_dash(doc, "проработанные диалоги и озвучивание персонажей;")
add_dash(doc, "одиночный режим без кооператива.")
add_par(doc, "Технологический стек:", first_line=False)
add_dash(doc, "движок: собственный движок Supergiant Engine;")
add_dash(doc, "язык: C++ и Lua;")
add_dash(doc, "распространение: Epic Games, Steam, консоли.")
add_par(doc, "Платформы поддержки: PC, PlayStation, Xbox, Nintendo Switch.", first_line=False)

add_heading_2(doc, "2.4 Сравнительный анализ аналогичных приложений")
add_par(doc, "Таблица 1 — Сравнение функциональных возможностей roguelike-игр", first_line=False)
add_table(
    doc,
    ["Критерий", "The Binding of Isaac", "Enter the Gungeon", "Hades", "Dungeon"],
    [
        ["Процедурная генерация", "Да", "Да", "Частично", "Да"],
        ["Боевая система", "Дальний бой", "Bullet-hell", "Ближний и дальний", "Ближний и дальний"],
        ["Сетевой кооператив", "Нет", "Локальный", "Нет", "Онлайн (ENet)"],
        ["Открытый исходный код", "Нет", "Нет", "Нет", "Да (учебный проект)"],
        ["Движок", "Собственный", "Unity", "Supergiant Engine", "Godot 4.4.1"],
        ["Стоимость", "Платная", "Платная", "Платная", "Бесплатный учебный продукт"],
        ["Возможность модификации", "Ограничена", "Ограничена", "Закрыта", "Полная"],
    ],
)
add_par(doc, "Примечание — источник: официальные сайты и документация перечисленных продуктов.", first_line=False)

add_par(doc, "2.4.1 Анализ функциональности и критические недостатки аналогов", bold=True, first_line=False)

add_par(doc, "The Binding of Isaac — критический анализ", bold=True, first_line=False)
add_par(doc, "Преимущества:", first_line=False)
add_dash(doc, "огромная база предметов и синергий между ними;")
add_dash(doc, "высокая реиграбельность за счёт случайности;")
add_dash(doc, "узнаваемый стиль и большое сообщество.")
add_par(doc, "Недостатки:", first_line=False)
add_dash(doc, "отсутствует онлайн-кооператив;")
add_dash(doc, "закрытый исходный код, что ограничивает учебное использование;")
add_dash(doc, "управление и баланс рассчитаны на опытных игроков.")
add_par(doc,
        "Заключение: The Binding of Isaac — эталонный коммерческий roguelike, "
        "но не подходит как пример для изучения архитектуры и сетевой "
        "разработки.")

add_par(doc, "Enter the Gungeon — критический анализ", bold=True, first_line=False)
add_par(doc, "Преимущества:", first_line=False)
add_dash(doc, "качественная боевая система с уклонениями;")
add_dash(doc, "большое количество оружия и врагов;")
add_dash(doc, "локальный кооператив.")
add_par(doc, "Недостатки:", first_line=False)
add_dash(doc, "отсутствует онлайн-режим;")
add_dash(doc, "коммерческое распространение, закрытый код;")
add_dash(doc, "высокая сложность для начинающих игроков.")
add_par(doc,
        "Заключение: Enter the Gungeon — пример продвинутого жанра, но не "
        "подходит для бесплатной учебной разработки.")

add_par(doc, "Hades — критический анализ", bold=True, first_line=False)
add_par(doc, "Преимущества:", first_line=False)
add_dash(doc, "проработанный сюжет и атмосфера;")
add_dash(doc, "плавная и динамичная боевая система;")
add_dash(doc, "качественное озвучивание и анимация.")
add_par(doc, "Недостатки:", first_line=False)
add_dash(doc, "отсутствует кооператив;")
add_dash(doc, "коммерческий продукт с закрытым исходным кодом;")
add_dash(doc, "требует значительных ресурсов команды (Supergiant Games — более 20 разработчиков).")
add_par(doc,
        "Заключение: Hades — высокобюджетный продукт, реализация которого "
        "недоступна для небольшой команды и не позволяет учебной модификации.")

add_par(doc, "2.4.2 Ключевой вывод", bold=True, first_line=False)
add_par(doc,
        "Ни одно из анализируемых приложений не предоставляет одновременно "
        "открытого исходного кода, онлайн-кооператива и возможности "
        "учебной модификации. Это создаёт нишу для собственной игры "
        "«Dungeon», которая закрывает данные потребности.")

add_heading_2(doc, "2.5 Обоснование разработки собственного решения")

add_par(doc, "2.5.1 Проблема и актуальность", bold=True, first_line=False)
add_par(doc,
        "Жанр roguelike остаётся одним из самых популярных в инди-сегменте "
        "игровой индустрии. Однако существующие проекты являются коммерческими "
        "и закрытыми, что не позволяет использовать их для учебных и "
        "демонстрационных целей. Дополнительно лишь немногие из них "
        "поддерживают полноценный онлайн-кооператив.")
add_par(doc,
        "Критическая проблема: на рынке отсутствует открытая 2D roguelike-игра "
        "на движке Godot 4.4.1 с онлайн-кооперативом, артефактами, боссами и "
        "учебной архитектурой, пригодной для расширения.")

add_par(doc, "2.5.2 Уникальность и преимущества разработки", bold=True, first_line=False)
add_par(doc, "Открытая архитектура на Godot 4.4.1:", first_line=False)
add_dash(doc, "использование сцен и автозагрузок Godot для прозрачной структуры проекта;")
add_dash(doc, "лёгкость добавления новых комнат, врагов, боссов и артефактов;")
add_dash(doc, "поддержка горячей перезагрузки баланса через user://game_consts.cfg.")
add_par(doc, "Полноценный онлайн-кооператив:", first_line=False)
add_dash(doc, "транспорт ENetMultiplayerPeer на базе UDP;")
add_dash(doc, "авторитетная модель хоста, защищающая забег от рассинхронизации;")
add_dash(doc, "RPC через аннотации @rpc, что делает сетевой код читаемым.")
add_par(doc, "Учебная ценность:", first_line=False)
add_dash(doc, "наглядная демонстрация возможностей Godot и GDScript;")
add_dash(doc, "применение лучших практик разработки на инди-уровне;")
add_dash(doc, "возможность использовать проект как материал для занятий и хакатонов.")
add_par(doc, "Расширяемость:", first_line=False)
add_dash(doc, "поддержка пользовательских билдов Godot;")
add_dash(doc, "разделение баланса и кода через GameConstants;")
add_dash(doc, "система артефактов с пулом и анти-повторами выбора.")

add_par(doc, "2.5.3 Стратегическое значение проекта", bold=True, first_line=False)
add_par(doc, "Для студии Dungeon Studio:", first_line=False)
add_dash(doc, "формирование портфолио инди-разработки;")
add_dash(doc, "отработка взаимодействия команды на полноценном проекте;")
add_dash(doc, "получение готовой кодовой базы для будущих игр.")
add_par(doc, "Для игрового сообщества:", first_line=False)
add_dash(doc, "появление открытой эталонной игры на Godot 4.4.1;")
add_dash(doc, "пример реализации сетевого кооператива на ENet;")
add_dash(doc, "учебный материал для начинающих разработчиков.")
add_par(doc, "Для образовательного процесса:", first_line=False)
add_dash(doc, "пример проектного подхода с IDEF0-моделью;")
add_dash(doc, "демонстрация полного цикла разработки от идеи до билда;")
add_dash(doc, "практическая база для курсов по геймдеву и архитектуре ПО.")
doc.add_page_break()

# ===== ЗАКЛЮЧЕНИЕ =====
add_heading_centered(doc, "ЗАКЛЮЧЕНИЕ")
add_par(doc,
        "В работе был проведён системный анализ организационной структуры "
        "студии-исполнителя Dungeon Studio и обоснована актуальность и "
        "целесообразность разработки программного продукта — 2D roguelike-игры "
        "«Dungeon» на игровом движке Godot 4.4.1 (пользовательская сборка). "
        "Определены основные функциональные требования, выявлены конкурентные "
        "преимущества и описана архитектура системы с использованием "
        "методологии IDEF0.")
add_par(doc,
        "Проект направлен на заполнение ниши открытых учебных roguelike-игр "
        "на Godot и демонстрирует практическое применение современных "
        "технологий: GDScript, сцен и автозагрузок Godot, ENetMultiplayerPeer "
        "для онлайн-кооператива, JSON-сохранений и системы артефактов.")
add_par(doc, "Разработка игры «Dungeon» является инновационным проектом, который сочетает:")
add_par(doc, "1. актуальность (закрывает нишу учебных roguelike-игр с кооперативом);", first_line=False)
add_par(doc, "2. технологичность (современный движок Godot 4.4.1 и язык GDScript);", first_line=False)
add_par(doc, "3. практическую ценность (готовый прототип с боями, артефактами и боссами);", first_line=False)
add_par(doc, "4. образовательную ценность (открытая архитектура и подробная документация).", first_line=False)
doc.add_page_break()

# ===== Список источников =====
add_heading_centered(doc, "Список использованных источников")
sources = [
    "1. Godot Engine — Release candidate: Godot 4.4.1 RC 1 [Электронный ресурс] / Godot Engine. — Режим доступа: https://godotengine.org/article/release-candidate-godot-4-4-1-rc-1/ (дата обращения: 18.05.2026).",
    "2. Godot Engine — Download Godot 4.4.1 (stable) [Электронный ресурс] / Godot Engine. — Режим доступа: https://godotengine.org/download/archive/4.4.1-stable/ (дата обращения: 18.05.2026).",
    "3. Godot Engine — High-level multiplayer documentation [Электронный ресурс] / Godot Engine. — Режим доступа: https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html (дата обращения: 18.05.2026).",
    "4. Godot Engine — ENetMultiplayerPeer class reference [Электронный ресурс] / Godot Engine. — Режим доступа: https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html (дата обращения: 18.05.2026).",
    "5. Гребенюк, Г. Г. Системный анализ и принятие решений : учебник / Г. Г. Гребенюк, С. В. Никитин. — Москва : Юрайт, 2023. — 315 с.",
    "6. Марка, Д. А. Методология структурного анализа и проектирования SADT / Д. А. Марка, К. МакГоуэн ; пер. с англ. — Москва : МетаТехнология, 1993. — 240 с.",
    "7. РД IDEF0–2000. Методология функционального моделирования IDEF0 : руководящий документ / Госстандарт России. — Москва : ИПК Издательство стандартов, 2000. — 75 с.",
    "8. Федотова, Е. Л. Проектирование информационных систем и технологий : учебник / Е. Л. Федотова. — Москва : ИД «ФОРУМ» : ИНФРА-М, 2022. — 368 с.",
    "9. Цыганенко, В. Н. Проектная деятельность. Руководство к курсовому проектированию : практикум / В. Н. Цыганенко, А. Г. Белик. — Омск : ОмГТУ, 2023. — 154 с. — ISBN 978-5-8149-3656-1.",
]
for s in sources:
    add_par(doc, s, first_line=False)

doc.save(OUT)
print(str(OUT))
