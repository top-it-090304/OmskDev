extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Disco Ball"
	artefact_description = "Ослепляет врагов\n+15% уклонения\n+20 к скорости\n+10% скорости атаки"
	dodge_chance_bonus = 0.15
	speed_bonus = 20
	attack_speed_bonus = 0.1
	super._ready()
