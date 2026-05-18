extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Top Hat"
	artefact_description = "Элегантность джентльмена\n+10% уклонения\n+2 здоровья за уровень\n+1 скорости за уровень"
	dodge_chance_bonus = 0.1
	health_per_level_bonus = 2
	speed_per_level_bonus = 1
	super._ready()
