extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Electronic Key"
	artefact_description = "Технологии будущего\n+30 к скорости\n+10% скорости атаки\n+5% шанс крита"
	speed_bonus = 30
	attack_speed_bonus = 0.1
	crit_chance_bonus = 0.05
	super._ready()
