extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Bongo"
	artefact_description = "Ритм битвы\n+8 к скорости\n+8 к здоровью\n+5% скорости атаки"
	speed_bonus = 8
	health_bonus = 8
	attack_speed_bonus = 0.05
	super._ready()
