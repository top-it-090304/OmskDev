extends Control

var mobile_controller: CanvasLayer = null
var move_joystick: Control = null
var attack_joystick: Control = null
var selected_joystick: Control = null
var drag_offset: Vector2 = Vector2.ZERO

const MIN_JOYSTICK_SCALE = 0.2
const MAX_JOYSTICK_SCALE = 1.0
const MARGIN_FROM_EDGE = 30.0
const CFG_PATH = "user://settings.cfg"

# Откуда был заход в настройки
var came_from_scene: String = ""

func _ready() -> void:
	for button in $ButtonContainer.find_children("*", "TextureButton", true, false):
		_ignore_button_label_mouse(button as Control)
	# Ждём немного чтобы сцена загрузилась
	await get_tree().create_timer(0.1).timeout
	_find_joysticks()
	_load_joystick_settings()
	_load_came_from()

func _ignore_button_label_mouse(button: Control) -> void:
	if button == null:
		return
	for child in button.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func _find_joysticks() -> void:
	# Ищем в текущей сцене
	mobile_controller = get_tree().get_first_node_in_group("mobile_controller")
	
	if not mobile_controller:
		mobile_controller = get_tree().current_scene.find_child("MobileController", true, false)
	
	if mobile_controller:
		move_joystick = mobile_controller.get_node_or_null("VirtualJoystick")
		attack_joystick = mobile_controller.get_node_or_null("VirtualJoystick2")

func _input(event: InputEvent) -> void:
	# Обработка тач-событий
	if event is InputEventScreenTouch:
		if event.pressed:
			_handle_touch_press(event.position)
		else:
			selected_joystick = null
	
	elif event is InputEventScreenDrag:
		if selected_joystick:
			_drag_joystick(event.position)
	
	elif event is InputEventMagnifyGesture:
		# Изменение размера жестом зума
		if selected_joystick:
			_resize_joystick(event.factor)
	
	# Обработка мыши для редактора
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_handle_touch_press(event.position)
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			selected_joystick = null
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Увеличение размера колесом
			_resize_selected_joystick(1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Уменьшение размера колесом
			_resize_selected_joystick(0.9)
	
	elif event is InputEventMouseMotion:
		if selected_joystick and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_drag_joystick(event.position)

func _handle_touch_press(pos: Vector2) -> void:
	selected_joystick = null
	
	if _is_point_in_joystick(pos, move_joystick):
		selected_joystick = move_joystick
		drag_offset = pos - move_joystick.position
	elif _is_point_in_joystick(pos, attack_joystick):
		selected_joystick = attack_joystick
		drag_offset = pos - attack_joystick.position

func _is_point_in_joystick(pos: Vector2, joystick: Control) -> bool:
	if not joystick:
		return false
	var rect = joystick.get_global_rect()
	return rect.has_point(pos)

func _drag_joystick(pos: Vector2) -> void:
	if not selected_joystick:
		return
	
	var new_pos = pos - drag_offset
	
	# Ограничения по краям экрана
	var viewport_size = get_viewport().get_visible_rect().size
	var joystick_size = selected_joystick.size * selected_joystick.scale
	
	# Ограничение: только нижние 2/3 экрана по высоте
	var min_y = viewport_size.y / 3.0  # Верхняя граница - 1/3 от верха
	
	new_pos.x = clamp(new_pos.x, MARGIN_FROM_EDGE, viewport_size.x - joystick_size.x - MARGIN_FROM_EDGE)
	new_pos.y = clamp(new_pos.y, min_y, viewport_size.y - joystick_size.y - MARGIN_FROM_EDGE)
	
	selected_joystick.position = new_pos

func _resize_joystick(factor: float) -> void:
	if not selected_joystick:
		return
	
	var new_scale = selected_joystick.scale.x * factor
	new_scale = clamp(new_scale, MIN_JOYSTICK_SCALE, MAX_JOYSTICK_SCALE)
	
	selected_joystick.scale = Vector2(new_scale, new_scale)

func _resize_selected_joystick(factor: float) -> void:
	if not selected_joystick:
		return
	
	var new_scale = selected_joystick.scale.x * factor
	new_scale = clamp(new_scale, MIN_JOYSTICK_SCALE, MAX_JOYSTICK_SCALE)
	
	selected_joystick.scale = Vector2(new_scale, new_scale)

func _on_save_pressed() -> void:
	_save_joystick_settings()
	_return_to_previous_scene()

func _on_cancel_pressed() -> void:
	# Выходим без сохранения
	_return_to_previous_scene()

func _return_to_previous_scene() -> void:
	if came_from_scene != "":
		get_tree().change_scene_to_file(came_from_scene)
	else:
		# По умолчанию возвращаемся в игру
		get_tree().change_scene_to_file(GameConstants.get_current_floor_scene_path())

func _save_joystick_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)
	
	if move_joystick:
		cfg.set_value("joystick", "move_pos_x", move_joystick.position.x)
		cfg.set_value("joystick", "move_pos_y", move_joystick.position.y)
		cfg.set_value("joystick", "move_scale", move_joystick.scale.x)
	
	if attack_joystick:
		cfg.set_value("joystick", "attack_pos_x", attack_joystick.position.x)
		cfg.set_value("joystick", "attack_pos_y", attack_joystick.position.y)
		cfg.set_value("joystick", "attack_scale", attack_joystick.scale.x)

	cfg.set_value("joystick", "layout_version", 5)
	cfg.save(CFG_PATH)
	print("Joystick settings saved!")

func _load_joystick_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return

	var vps := get_viewport().get_visible_rect().size
	var def_y := clampf(vps.y * 0.46, 130.0, maxf(140.0, vps.y - 200.0))
	var def_move := Vector2(maxf(16.0, vps.x * 0.035), def_y)
	var def_attack := Vector2(clampf(vps.x * 0.72, def_move.x + 130.0, vps.x - 20.0), def_y)

	if move_joystick:
		var pos_x = float(cfg.get_value("joystick", "move_pos_x", def_move.x))
		var pos_y = float(cfg.get_value("joystick", "move_pos_y", def_move.y))
		var scale_val = float(cfg.get_value("joystick", "move_scale", 0.3))
		move_joystick.position = Vector2(pos_x, pos_y)
		move_joystick.scale = Vector2(scale_val, scale_val)

	if attack_joystick:
		var pos_x = float(cfg.get_value("joystick", "attack_pos_x", def_attack.x))
		var pos_y = float(cfg.get_value("joystick", "attack_pos_y", def_attack.y))
		var scale_val = float(cfg.get_value("joystick", "attack_scale", 0.3))
		attack_joystick.position = Vector2(pos_x, pos_y)
		attack_joystick.scale = Vector2(scale_val, scale_val)

func _load_came_from() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) == OK:
		came_from_scene = str(cfg.get_value("joystick_edit", "came_from_scene", ""))
