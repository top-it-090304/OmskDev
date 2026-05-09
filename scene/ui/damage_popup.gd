extends Control

# Типы попапов
enum Type { DAMAGE, HEAL, DODGE, CRIT }

@onready var label = $Label

var popup_type: Type = Type.DAMAGE
var value: int = 0

const DAMAGE_COLOR = Color(1, 0.2, 0.2, 1)      # Красный
const HEAL_COLOR = Color(0.2, 1, 0.3, 1)        # Зелёный  
const DODGE_COLOR = Color(0.5, 0.8, 1, 1)       # Голубой
const CRIT_COLOR = Color(1, 0.8, 0, 1)          # Жёлтый

func setup(type: Type, val: int = 0) -> void:
	popup_type = type
	value = val
	
	match popup_type:
		Type.DAMAGE:
			label.text = "-" + str(value)
			label.add_theme_color_override("font_color", DAMAGE_COLOR)
		Type.HEAL:
			label.text = "+" + str(value)
			label.add_theme_color_override("font_color", HEAL_COLOR)
		Type.DODGE:
			label.text = "DODGE"
			label.add_theme_color_override("font_color", DODGE_COLOR)
		Type.CRIT:
			label.text = str(value) + "!"
			label.add_theme_color_override("font_color", CRIT_COLOR)
			label.add_theme_font_size_override("font_size", 24)

func _ready():
	# Анимация
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Движение вверх
	tween.tween_property(self, "position:y", position.y - 60, 1.0)
	
	# Fade out
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	
	# Небольшое масштабирование
	tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.3)
	
	await tween.finished
	queue_free()
