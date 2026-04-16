extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Coffee Mug"
	artefact_description = "Кофеиновый буст\n+30 к скорости\n+10% скорости атаки"
	speed_bonus = 30
	attack_speed_bonus = 0.1
	super._ready()
