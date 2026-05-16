extends TextureProgressBar


func _ready():
	# Когда враг появляется с полным здоровьем, полоску не видно
	visible = true

func update_hp(current_hp: int, max_hp: int):
	max_value = max_hp
	value = current_hp
	
	# Показываем полоску, если здоровье упало, и прячем, если полное
	if current_hp < max_hp:
		visible = true
	else:
		visible = false
