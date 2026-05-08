extends Node2D

func _draw() -> void:
	# Base ellipse (shadow/ground)
	var pts_base := PackedVector2Array()
	for i in 32:
		var a := i * TAU / 32
		pts_base.append(Vector2(cos(a) * 18, sin(a) * 7 + 8))
	draw_colored_polygon(pts_base, Color(0.1, 0.05, 0.15, 0.7))

	# Pedestal body (trapezoid)
	var body := PackedVector2Array([
		Vector2(-10, 6),
		Vector2(10, 6),
		Vector2(7, -4),
		Vector2(-7, -4),
	])
	draw_colored_polygon(body, Color(0.35, 0.22, 0.5, 1.0))

	# Top platform
	var top := PackedVector2Array()
	for i in 32:
		var a := i * TAU / 32
		top.append(Vector2(cos(a) * 9, sin(a) * 3.5 - 4))
	draw_colored_polygon(top, Color(0.5, 0.32, 0.7, 1.0))

	# Highlight on top
	var hi := PackedVector2Array()
	for i in 32:
		var a := i * TAU / 32
		hi.append(Vector2(cos(a) * 6, sin(a) * 2 - 5))
	draw_colored_polygon(hi, Color(0.7, 0.55, 0.9, 0.5))
