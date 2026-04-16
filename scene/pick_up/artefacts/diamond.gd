extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Diamond"
	artefact_description = "Острый и твердый\n+5 к урону\n+10% шанс крита\n+0.3x крит множитель"
	damage_bonus = 5
	crit_chance_bonus = 0.1
	crit_multiplier_bonus = 0.3
	super._ready()
