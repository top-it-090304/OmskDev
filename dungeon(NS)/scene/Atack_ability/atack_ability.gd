extends Node2D
func animation():
	var animated_sprite=$AnimatedSprite2D
	if animated_sprite.has_signal("animation_finished"):
		queue_free()
