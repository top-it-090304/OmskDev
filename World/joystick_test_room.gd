extends Node2D

const CFG_PATH = "user://settings.cfg"

func _ready() -> void:
	# Загружаем сохранённые настройки джойстиков
	_load_joystick_settings()
	
	# Подсвечиваем джойстики
	call_deferred("_highlight_joysticks", true)

func _highlight_joysticks(highlight: bool) -> void:
	var mobile_controller = get_node_or_null("MobileController")
	if not mobile_controller:
		return
	
	var move_joystick = mobile_controller.get_node_or_null("VirtualJoystick")
	var attack_joystick = mobile_controller.get_node_or_null("VirtualJoystick2")
	
	if move_joystick:
		var base = move_joystick.get_node_or_null("Base")
		if base:
			if highlight:
				base.modulate = Color(1.0, 0.8, 0.3, 0.9)
			else:
				base.modulate = Color(0.678, 0.514, 0.341, 0.784)
	
	if attack_joystick:
		var base = attack_joystick.get_node_or_null("Base")
		if base:
			if highlight:
				base.modulate = Color(1.0, 0.8, 0.3, 0.9)
			else:
				base.modulate = Color(0.678, 0.514, 0.341, 0.784)

func _load_joystick_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return
	
	var mobile_controller = get_node_or_null("MobileController")
	if not mobile_controller:
		return
	
	var move_joystick = mobile_controller.get_node_or_null("VirtualJoystick")
	var attack_joystick = mobile_controller.get_node_or_null("VirtualJoystick2")
	
	if move_joystick:
		var pos_x = float(cfg.get_value("joystick", "move_pos_x", 16.0))
		var pos_y = float(cfg.get_value("joystick", "move_pos_y", 84.0))
		var scale_val = float(cfg.get_value("joystick", "move_scale", 0.3))
		move_joystick.position = Vector2(pos_x, pos_y)
		move_joystick.scale = Vector2(scale_val, scale_val)
	
	if attack_joystick:
		var pos_x = float(cfg.get_value("joystick", "attack_pos_x", 427.0))
		var pos_y = float(cfg.get_value("joystick", "attack_pos_y", 84.0))
		var scale_val = float(cfg.get_value("joystick", "attack_scale", 0.3))
		attack_joystick.position = Vector2(pos_x, pos_y)
		attack_joystick.scale = Vector2(scale_val, scale_val)
