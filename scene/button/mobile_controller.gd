extends CanvasLayer

const CFG_PATH = "user://settings.cfg"

func _ready() -> void:
	add_to_group("mobile_controller")
	call_deferred("_load_joystick_settings")

func _load_joystick_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return
	
	var move_joystick = get_node_or_null("VirtualJoystick")
	var attack_joystick = get_node_or_null("VirtualJoystick2")
	
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
