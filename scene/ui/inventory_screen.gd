extends CanvasLayer

const STATS = [
	{"key": "PLAYER_MAX_HEALTH",     "icon": "❤️",  "label": "Здоровье"},
	{"key": "PLAYER_MAX_SPEED",      "icon": "👟", "label": "Скорость"},
	{"key": "PLAYER_ATTACK_DAMAGE",  "icon": "⚔️",  "label": "Урон"},
	{"key": "PLAYER_ATTACK_SPEED",   "icon": "⚡",  "label": "Скор. атаки"},
	{"key": "PLAYER_ARMOR",          "icon": "🛡️",  "label": "Броня"},
	{"key": "PLAYER_DODGE_CHANCE",   "icon": "💨",  "label": "Уклонение"},
	{"key": "PLAYER_CRIT_CHANCE",    "icon": "🎯",  "label": "Крит шанс"},
	{"key": "PLAYER_CRIT_MULTIPLIER","icon": "💥",  "label": "Крит урон"},
	{"key": "PLAYER_LIFESTEAL",      "icon": "🩸",  "label": "Вампиризм"},
	{"key": "PLAYER_LEVEL",          "icon": "⭐",  "label": "Уровень"},
]

var _visible := false
var _panel: PanelContainer
var _grid: GridContainer
var _stats_container: VBoxContainer
var _desc_label: Label
var _artefacts: Array = []
var _stats_popup: Control

func _ready() -> void:
	add_to_group("inventory_screen")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	hide_inventory()
	# НЕ загружаем артефакты здесь - это делает backpack.gd и синхронизирует с нами

func _build_ui() -> void:
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.08, 0.07, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	root.add_child(margin)

	_panel = PanelContainer.new()
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.15, 0.13, 0.98)
	style.border_color = Color(0.45, 0.35, 0.25, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", style)
	margin.add_child(_panel)

	var outer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	_panel.add_child(outer)

	# Заголовок + крестик
	var title_row = HBoxContainer.new()
	outer.add_child(title_row)

	var title_lbl = Label.new()
	title_lbl.text = "  ИНВЕНТАРЬ"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.82, 0.7))
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_row.add_child(title_lbl)

	var stats_btn = Button.new()
	stats_btn.text = "📊"
	stats_btn.custom_minimum_size = Vector2(44, 32)
	stats_btn.flat = true
	stats_btn.add_theme_font_size_override("font_size", 20)
	stats_btn.pressed.connect(_show_stats_popup)
	title_row.add_child(stats_btn)

	var close_btn = Button.new()
	close_btn.text = " ✕ "
	close_btn.custom_minimum_size = Vector2(44, 32)
	close_btn.flat = true
	close_btn.add_theme_color_override("font_color", Color(0.9, 0.45, 0.35))
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(hide_inventory)
	title_row.add_child(close_btn)

	var sep0 = HSeparator.new()
	outer.add_child(sep0)

	# Один ScrollContainer на весь контент
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)

	# --- АРТЕФАКТЫ ---
	var art_title = Label.new()
	art_title.text = "АРТЕФАКТЫ"
	art_title.add_theme_color_override("font_color", Color(0.75, 0.65, 0.5))
	art_title.add_theme_font_size_override("font_size", 14)
	content.add_child(art_title)

	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	content.add_child(_grid)

	var sep2 = HSeparator.new()
	content.add_child(sep2)

	# Описание артефакта
	_desc_label = Label.new()
	_desc_label.text = "Нажми на артефакт чтобы увидеть описание"
	_desc_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.58))
	_desc_label.add_theme_font_size_override("font_size", 13)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_desc_label)

func show_inventory() -> void:
	_visible = true
	show()
	get_tree().paused = true
	# После смены сцены/этажа deferred-синк мог ещё не успеть — подтягиваем из рюкзака.
	var bp: Node = get_tree().get_first_node_in_group("backpack")
	if bp == null:
		bp = get_tree().root.find_child("Backpack", true, false)
	if bp != null and _grid != null and _artefacts.is_empty():
		var arr: Variant = bp.get("collected_artefacts")
		if arr is Array and (arr as Array).size() > 0:
			clear_and_sync(arr as Array)
	_refresh_artefacts()

func hide_inventory() -> void:
	_visible = false
	hide()
	get_tree().paused = false

func toggle() -> void:
	if _visible:
		hide_inventory()
	else:
		show_inventory()

func _input(event: InputEvent) -> void:
	pass

func _show_stats_popup() -> void:
	if _stats_popup and is_instance_valid(_stats_popup):
		_stats_popup.queue_free()
		return

	_stats_popup = Control.new()
	_stats_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_stats_popup)

	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.08, 0.07, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stats_popup.add_child(bg)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	_stats_popup.add_child(margin)

	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.15, 0.13, 0.98)
	style.border_color = Color(0.45, 0.35, 0.25, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var title_row = HBoxContainer.new()
	vbox.add_child(title_row)

	var title_lbl = Label.new()
	title_lbl.text = "  ХАРАКТЕРИСТИКИ"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.82, 0.7))
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_row.add_child(title_lbl)

	var close_btn = Button.new()
	close_btn.text = " ✕ "
	close_btn.custom_minimum_size = Vector2(44, 32)
	close_btn.flat = true
	close_btn.add_theme_color_override("font_color", Color(0.9, 0.45, 0.35))
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(_stats_popup.queue_free)
	title_row.add_child(close_btn)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_stats_container = VBoxContainer.new()
	_stats_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_container.add_theme_constant_override("separation", 6)
	scroll.add_child(_stats_container)
	_refresh_stats()

func _refresh_stats() -> void:
	for child in _stats_container.get_children():
		child.queue_free()
	for stat in STATS:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_stats_container.add_child(row)

		var icon = Label.new()
		icon.text = stat["icon"]
		icon.custom_minimum_size = Vector2(22, 0)
		icon.add_theme_font_size_override("font_size", 13)
		row.add_child(icon)

		var name_l = Label.new()
		name_l.text = stat["label"]
		name_l.custom_minimum_size = Vector2(100, 0)
		name_l.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		name_l.add_theme_font_size_override("font_size", 13)
		row.add_child(name_l)

		var val_l = Label.new()
		val_l.add_theme_font_size_override("font_size", 13)
		var val = GameConstants.get(stat["key"])
		if stat["key"] in ["PLAYER_DODGE_CHANCE", "PLAYER_CRIT_CHANCE", "PLAYER_LIFESTEAL"]:
			val_l.text = "%d%%" % int(val * 100)
		elif val is float:
			val_l.text = "%.1f" % val
		else:
			val_l.text = str(val)
		val_l.add_theme_color_override("font_color", Color(1, 1, 0.6))
		row.add_child(val_l)

func _refresh_artefacts() -> void:
	for child in _grid.get_children():
		child.queue_free()
	for art in _artefacts:
		_add_artefact_icon(art)

func add_artefact(artefact_info) -> void:
	# Принимаем как Dictionary так и ArtefactBase объект
	var info: Dictionary
	if artefact_info is Dictionary:
		info = artefact_info
	else:
		info = {
			"name": artefact_info.get("artefact_name") if "artefact_name" in artefact_info else "?",
			"icon": artefact_info.get("artefact_icon") if "artefact_icon" in artefact_info else null,
			"icon_path": artefact_info.artefact_icon.resource_path if ("artefact_icon" in artefact_info and artefact_info.artefact_icon) else "",
			"description": artefact_info.get("artefact_description") if "artefact_description" in artefact_info else ""
		}
	
	# Проверяем на дубликаты
	var artefact_name = info.get("name", "")
	for existing in _artefacts:
		if existing.get("name", "") == artefact_name:
			print("Артефакт уже есть в inventory_screen, пропускаем: ", artefact_name)
			return
	
	_artefacts.append(info)
	_add_artefact_icon(info)

func clear_and_sync(artefacts_list: Array) -> void:
	# Полная синхронизация - очищаем и пересоздаём
	_artefacts.clear()
	for child in _grid.get_children():
		child.queue_free()
	
	for info in artefacts_list:
		_artefacts.append(info)
		_add_artefact_icon(info)
	
	print("inventory_screen синхронизирован, артефактов: ", _artefacts.size())

func _add_artefact_icon(art: Dictionary) -> void:
	var btn = TextureButton.new()
	btn.custom_minimum_size = Vector2(56, 56)
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	if art.get("icon"):
		btn.texture_normal = art["icon"]
	btn.pressed.connect(func():
		if is_instance_valid(_desc_label):
			_desc_label.text = "[%s]\n%s" % [art.get("name","?"), art.get("description","")]
	)
	_grid.add_child(btn)


func get_collected_artefact_names() -> Array:
	var result = []
	for art in _artefacts:
		result.append({
			"name": art.get("name", ""),
			"icon_path": art.get("icon_path", ""),
			"description": art.get("description", "")
		})
	return result
