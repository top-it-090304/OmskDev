class_name CheatPanel
extends CanvasLayer
## Панель читов для демо (встроена в сцены layer*.tscn).

const FONT := preload("res://Font/PixelRpgFont-Regular.ttf")

const _STAT_KEYS: Array[String] = [
	"PLAYER_MAX_SPEED",
	"PLAYER_MAX_HEALTH",
	"PLAYER_ATTACK_DAMAGE",
	"PLAYER_ATTACK_SPEED",
	"PLAYER_ARMOR",
	"PLAYER_DODGE_CHANCE",
	"PLAYER_CRIT_CHANCE",
	"PLAYER_CRIT_MULTIPLIER",
	"PLAYER_LIFESTEAL",
	"PLAYER2_MAX_HEALTH",
	"PLAYER2_ATTACK_DAMAGE",
]

var god_mode: bool = false
var demo_mode: bool = false

var _toggle_btn: Button
var _menu_panel: PanelContainer
var _demo_btn: Button
var _god_btn: Button
var _saved: Dictionary = {}


func _ready() -> void:
	add_to_group("cheat_panel")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F9:
			_toggle_menu()
			get_viewport().set_input_as_handled()


static func is_god_mode_active() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var panel := tree.get_first_node_in_group("cheat_panel")
	return panel != null and panel.get("god_mode") == true


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_toggle_btn = _make_button("Читы", Vector2(8, 8), Vector2(76, 30))
	_toggle_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_toggle_btn.pressed.connect(_toggle_menu)
	root.add_child(_toggle_btn)

	_menu_panel = PanelContainer.new()
	_menu_panel.position = Vector2(8, 42)
	_menu_panel.custom_minimum_size = Vector2(204, 0)
	_menu_panel.visible = false
	_menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_menu_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.12, 0.92)
	style.border_color = Color(0.55, 0.35, 0.9, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	_menu_panel.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_menu_panel.add_child(box)

	var title := Label.new()
	title.text = "Демо / читы"
	_apply_font(title, 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_demo_btn = _add_row_button(box, "★ Демо-режим")
	_demo_btn.pressed.connect(_on_demo_pressed)
	_god_btn = _add_row_button(box, "Бессмертие")
	_god_btn.pressed.connect(_on_god_pressed)
	_add_row_button(box, "+100 всё").pressed.connect(_on_boost_all)
	_add_row_button(box, "+200 урон").pressed.connect(func() -> void: add_damage(200))
	_add_row_button(box, "+150 скорость").pressed.connect(func() -> void: add_speed(150))
	_add_row_button(box, "Полное HP").pressed.connect(heal_local_players)
	_add_row_button(box, "+3 уровня").pressed.connect(func() -> void: add_levels(3))
	_add_row_button(box, "Убить врагов").pressed.connect(clear_current_room_enemies)


func _toggle_menu() -> void:
	_menu_panel.visible = not _menu_panel.visible


func _on_demo_pressed() -> void:
	demo_mode = not demo_mode
	if demo_mode:
		_apply_demo_mode()
	else:
		_restore_saved_stats()
	_demo_btn.text = "★ Демо ВКЛ" if demo_mode else "★ Демо-режим"
	_god_btn.text = "Бессмертие ВКЛ" if god_mode else "Бессмертие"


func _on_god_pressed() -> void:
	god_mode = not god_mode
	heal_local_players()
	_god_btn.text = "Бессмертие ВКЛ" if god_mode else "Бессмертие"


func _on_boost_all() -> void:
	boost_all_stats()


func add_damage(amount: int = 200) -> void:
	GameConstants.PLAYER_ATTACK_DAMAGE = mini(GameConstants.PLAYER_ATTACK_DAMAGE + amount, 999)
	GameConstants.PLAYER2_ATTACK_DAMAGE = mini(GameConstants.PLAYER2_ATTACK_DAMAGE + amount, 999)
	GameConstants.constants_changed.emit()


func add_speed(amount: int = 150) -> void:
	GameConstants.PLAYER_MAX_SPEED = mini(GameConstants.PLAYER_MAX_SPEED + amount, 600)
	GameConstants.constants_changed.emit()


func boost_all_stats() -> void:
	add_damage(100)
	add_speed(80)
	GameConstants.PLAYER_ATTACK_SPEED = mini(GameConstants.PLAYER_ATTACK_SPEED + 1.5, 8.0)
	GameConstants.PLAYER_ARMOR += 25
	GameConstants.PLAYER_CRIT_CHANCE = mini(GameConstants.PLAYER_CRIT_CHANCE + 0.25, 0.95)
	GameConstants.PLAYER_CRIT_MULTIPLIER = mini(GameConstants.PLAYER_CRIT_MULTIPLIER + 1.0, 6.0)
	GameConstants.PLAYER_LIFESTEAL = mini(GameConstants.PLAYER_LIFESTEAL + 0.2, 0.9)
	GameConstants.PLAYER_DODGE_CHANCE = mini(GameConstants.PLAYER_DODGE_CHANCE + 0.2, 0.75)
	GameConstants.PLAYER_MAX_HEALTH = mini(GameConstants.PLAYER_MAX_HEALTH + 300, 9999)
	GameConstants.PLAYER2_MAX_HEALTH = mini(GameConstants.PLAYER2_MAX_HEALTH + 300, 9999)
	GameConstants.constants_changed.emit()
	heal_local_players()


func add_levels(count: int = 3) -> void:
	for _i in count:
		GameConstants.PLAYER_LEVEL += 1
		GameConstants._apply_coop_shared_level_up_grant()
	GameConstants.constants_changed.emit()
	heal_local_players()


func heal_local_players() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for n in tree.get_nodes_in_group("local_player"):
		if not is_instance_valid(n):
			continue
		var max_h: int = GameConstants.PLAYER_MAX_HEALTH
		if n.has_method("_get_max_health"):
			max_h = int(n.call("_get_max_health"))
		if n.get("health_int") != null:
			n.set("health_int", max_h)
		if n.has_signal("health_changed"):
			n.emit_signal("health_changed", max_h, max_h)


func clear_current_room_enemies() -> void:
	var mm := get_tree().get_first_node_in_group("map_manager")
	if mm == null:
		return
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() and not mp.is_server():
		return
	for room_data in mm.spawned_rooms:
		if room_data["grid_pos"] != mm.current_room_grid_pos:
			continue
		var room_node: Node = room_data["node"]
		var enode := room_node.find_child("Enemys", true, false)
		if enode == null:
			return
		for child in enode.get_children():
			if not is_instance_valid(child):
				continue
			if child.is_in_group("boss"):
				continue
			if child.get("hp") != null:
				child.set("hp", 0)
			if child.get("is_dead") != null:
				child.set("is_dead", true)
			child.queue_free()
		return


func _apply_demo_mode() -> void:
	_save_stats()
	GameConstants.PLAYER_ATTACK_DAMAGE = 400
	GameConstants.PLAYER2_ATTACK_DAMAGE = 400
	GameConstants.PLAYER_MAX_SPEED = 500
	GameConstants.PLAYER_ATTACK_SPEED = 5.0
	GameConstants.PLAYER_MAX_HEALTH = 5000
	GameConstants.PLAYER2_MAX_HEALTH = 5000
	GameConstants.PLAYER_ARMOR = 80
	GameConstants.PLAYER_DODGE_CHANCE = 0.35
	GameConstants.PLAYER_CRIT_CHANCE = 0.45
	GameConstants.PLAYER_CRIT_MULTIPLIER = 4.0
	GameConstants.PLAYER_LIFESTEAL = 0.35
	god_mode = true
	GameConstants.constants_changed.emit()
	heal_local_players()


func _save_stats() -> void:
	_saved.clear()
	for key in _STAT_KEYS:
		if GameConstants._is_script_var_property(key):
			_saved[key] = GameConstants.get(key)


func _restore_saved_stats() -> void:
	if _saved.is_empty():
		return
	for key in _saved.keys():
		if GameConstants._is_script_var_property(str(key)):
			GameConstants.set(key, _saved[key])
	_saved.clear()
	god_mode = false
	GameConstants.constants_changed.emit()
	heal_local_players()


func _add_row_button(parent: VBoxContainer, label: String) -> Button:
	var btn := _make_button(label, Vector2.ZERO, Vector2(192, 28))
	parent.add_child(btn)
	return btn


func _make_button(text: String, pos: Vector2, size: Vector2) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.position = pos
	btn.custom_minimum_size = size
	_apply_font(btn, 12)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.18, 0.14, 0.28, 0.95)
	normal.border_color = Color(0.45, 0.3, 0.7, 1.0)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.28, 0.2, 0.42, 1.0)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", Color(1, 0.95, 1, 1))
	return btn


func _apply_font(control: Control, size: int) -> void:
	if FONT:
		control.add_theme_font_override("font", FONT)
		control.add_theme_font_size_override("font_size", size)
