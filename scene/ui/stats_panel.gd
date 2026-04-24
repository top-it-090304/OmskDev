extends VBoxContainer

const FONT_PATH = "res://Font/PixelRpgFont-Regular.ttf"

# [icon, label_node_name, gc_key, format_func]
const STATS = [
	["❤", "HP",      "PLAYER_MAX_HEALTH",    "int"],
	["⚔", "DMG",     "PLAYER_ATTACK_DAMAGE", "int"],
	["👟", "SPD",     "PLAYER_MAX_SPEED",     "int"],
	["🛡", "ARM",     "PLAYER_ARMOR",         "int"],
	["💨", "DODGE",   "PLAYER_DODGE_CHANCE",  "pct"],
	["🎯", "CRIT",    "PLAYER_CRIT_CHANCE",   "pct"],
	["🩸", "STEAL",   "PLAYER_LIFESTEAL",     "pct"],
	["⚡", "ATK SPD", "PLAYER_ATTACK_SPEED",  "x"],
]

var _labels: Dictionary = {}

func _ready() -> void:
	_build_ui()
	GameConstants.constants_changed.connect(_refresh)
	_refresh()

func _build_ui() -> void:
	var font = load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else null

	# Полупрозрачный фон
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.corner_radius_top_left = 8
	bg.corner_radius_top_right = 8
	bg.corner_radius_bottom_left = 8
	bg.corner_radius_bottom_right = 8
	bg.content_margin_left = 6
	bg.content_margin_right = 6
	bg.content_margin_top = 4
	bg.content_margin_bottom = 4
	add_theme_stylebox_override("panel", bg)

	for entry in STATS:
		var icon_key = entry[0]
		var label_key = entry[1]
		var gc_key = entry[2]

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var icon_lbl = Label.new()
		icon_lbl.text = icon_key
		icon_lbl.add_theme_font_size_override("font_size", 16)
		icon_lbl.custom_minimum_size = Vector2(22, 0)
		row.add_child(icon_lbl)

		var val_lbl = Label.new()
		val_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		val_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
		val_lbl.add_theme_constant_override("shadow_offset_x", 1)
		val_lbl.add_theme_constant_override("shadow_offset_y", 1)
		val_lbl.add_theme_font_size_override("font_size", 13)
		if font:
			val_lbl.add_theme_font_override("font", font)
		row.add_child(val_lbl)

		_labels[gc_key] = {"lbl": val_lbl, "fmt": entry[3]}
		add_child(row)

func _refresh() -> void:
	for gc_key in _labels:
		var entry = _labels[gc_key]
		var val = GameConstants.get(gc_key)
		var fmt: String = entry["fmt"]
		var lbl: Label = entry["lbl"]
		match fmt:
			"int": lbl.text = str(int(val))
			"pct": lbl.text = str(int(val * 100)) + "%"
			"x":   lbl.text = "x" + ("%.1f" % val)
			_:     lbl.text = str(val)
