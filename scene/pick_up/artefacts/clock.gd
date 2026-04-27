extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Clock"
	artefact_description = "Время - сила\n+15% скорости атаки\n+1 урона за уровень"
	attack_speed_bonus = 0.15
	damage_per_level_bonus = 1
	super._ready()
