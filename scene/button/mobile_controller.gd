extends CanvasLayer

const CFG_PATH = "user://settings.cfg"
const JOYSTICK_LAYOUT_VERSION := 3


func _ready() -> void:
	add_to_group("mobile_controller")
	call_deferred("_load_joystick_settings")


func _default_joystick_positions() -> Dictionary:
	var vps := get_viewport().get_visible_rect().size
	# Чуть выше низа экрана — целиком в кадре; не наезжаем на шкалу опыта справа
	var y := clampf(vps.y * 0.58, 168.0, maxf(160.0, vps.y - 140.0))
	var move := Vector2(maxf(16.0, vps.x * 0.035), y)
	var attack := Vector2(clampf(vps.x * 0.72, move.x + 130.0, vps.x - 20.0), y)
	return {"move": move, "attack": attack}


func _load_joystick_settings() -> void:
	var defs := _default_joystick_positions()
	var def_move: Vector2 = defs["move"]
	var def_attack: Vector2 = defs["attack"]

	var cfg := ConfigFile.new()
	var ok := cfg.load(CFG_PATH) == OK

	if ok and int(cfg.get_value("joystick", "layout_version", 0)) < JOYSTICK_LAYOUT_VERSION:
		var vps := get_viewport().get_visible_rect().size
		var old_my := float(cfg.get_value("joystick", "move_pos_y", def_move.y))
		var old_ay := float(cfg.get_value("joystick", "attack_pos_y", def_attack.y))
		if old_my < 130.0 or old_my > vps.y * 0.65:
			cfg.set_value("joystick", "move_pos_y", def_move.y)
		if old_ay < 160.0 or old_ay > vps.y * 0.65:
			cfg.set_value("joystick", "attack_pos_y", def_attack.y)
		cfg.set_value("joystick", "layout_version", JOYSTICK_LAYOUT_VERSION)
		cfg.save(CFG_PATH)

	var move_joystick := get_node_or_null("VirtualJoystick") as Control
	var attack_joystick := get_node_or_null("VirtualJoystick2") as Control

	if move_joystick:
		var pos_x: float = def_move.x
		var pos_y: float = def_move.y
		var scale_val: float = 0.3
		if ok:
			pos_x = float(cfg.get_value("joystick", "move_pos_x", def_move.x))
			pos_y = float(cfg.get_value("joystick", "move_pos_y", def_move.y))
			scale_val = float(cfg.get_value("joystick", "move_scale", 0.3))
		move_joystick.position = Vector2(pos_x, pos_y)
		move_joystick.scale = Vector2(scale_val, scale_val)

	if attack_joystick:
		var pos_x: float = def_attack.x
		var pos_y: float = def_attack.y
		var scale_val: float = 0.3
		if ok:
			pos_x = float(cfg.get_value("joystick", "attack_pos_x", def_attack.x))
			pos_y = float(cfg.get_value("joystick", "attack_pos_y", def_attack.y))
			scale_val = float(cfg.get_value("joystick", "attack_scale", 0.3))
		attack_joystick.position = Vector2(pos_x, pos_y)
		attack_joystick.scale = Vector2(scale_val, scale_val)
