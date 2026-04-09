extends Control

@onready var base = $Base # Укажи сюда свой TextureRect базы
@onready var knob = $Base/Tip # Укажи сюда свой стик

var radius: float = 50.0 
var is_active: bool = false
var vector: Vector2 = Vector2.ZERO
var touch_index: int = -1 

func _ready() -> void:
	# Защищаем от случайных нажатий мимо
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Ставим стик ровно по центру
	_center_knob()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and touch_index == -1:
			if _is_point_in_joystick_area(event.position):
				touch_index = event.index
				is_active = true
				_update_joystick(event.position)
				
		elif not event.pressed and event.index == touch_index:
			_reset_joystick()
			
	elif event is InputEventScreenDrag and is_active and event.index == touch_index:
		_update_joystick(event.position)

func _is_point_in_joystick_area(point: Vector2) -> bool:
	var rect = base.get_global_rect()
	rect = rect.grow(20) 
	return rect.has_point(point)

func _update_joystick(touch_pos: Vector2) -> void:
	# Берем реальный центр базы на экране
	var base_center = base.get_global_rect().get_center()
	var dir = (touch_pos - base_center).normalized()
	var dist = clampf((touch_pos - base_center).length(), 0, radius)
	
	# Идеальная точка для центра стика
	var target_point = base_center + dir * dist
	
	# Узнаем, на сколько пикселей реальный центр стика отбит от его левого верхнего угла
	var knob_center_offset = knob.get_global_rect().get_center() - knob.global_position
	
	# Сдвигаем левый верхний угол стика так, чтобы его центр попал в цель
	knob.global_position = target_point - knob_center_offset
	vector = dir

func _center_knob() -> void:
	var base_center = base.get_global_rect().get_center()
	var knob_center_offset = knob.get_global_rect().get_center() - knob.global_position
	knob.global_position = base_center - knob_center_offset

func _reset_joystick() -> void:
	touch_index = -1
	is_active = false
	vector = Vector2.ZERO
	_center_knob()
