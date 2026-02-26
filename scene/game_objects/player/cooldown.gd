extends CanvasLayer
@onready var timer_label = %Label

var countdown_time=0

var last_attack_time :=0
var cooldown:=1000

func _process(delta):	
	if countdown_time>0:
		countdown_time -= delta
		update_label()
	else:
		timer_label.text =""
	var at= Input.is_action_just_pressed("attack")
	if at:
		if can_attack():
			countdown_time=1.0
			update_label()
	return
func can_attack() -> bool:
	var current_time = Time.get_ticks_msec() 
	if current_time - last_attack_time >= cooldown:
		last_attack_time = current_time
		return true
	return false	

func update_label():
	timer_label.text = str(snapped(countdown_time, 0.1))
