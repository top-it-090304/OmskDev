extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Golden Ball"
	artefact_description = "Тяжелый мощный удар\n+10 к урону\n+15% шанс крита\n+0.5x крит множитель"
	damage_bonus = 10
	crit_chance_bonus = 0.15
	crit_multiplier_bonus = 0.5
	super._ready()
