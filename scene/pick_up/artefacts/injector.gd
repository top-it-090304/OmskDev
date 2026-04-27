extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Injector"
	artefact_description = "Боевой стимулятор\n+3 к урону\n+15 к скорости\n+10% скорости атаки\n+5% шанс крита"
	damage_bonus = 3
	speed_bonus = 15
	attack_speed_bonus = 0.1
	crit_chance_bonus = 0.05
	super._ready()
