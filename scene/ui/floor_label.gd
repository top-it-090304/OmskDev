extends Label

func _ready():
	text = "Floor %d" % GameConstants.CURRENT_FLOOR
	modulate.a = 0.0
	_animate()

func _animate():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.4)
	tween.tween_interval(2.0)
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.tween_property(self, "position:y", position.y - 60.0, 0.6)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
