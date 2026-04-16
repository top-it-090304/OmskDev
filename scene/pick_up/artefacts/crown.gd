extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Crown"
	artefact_description = "+3 здоровья за уровень"
	health_per_level_bonus = 3
	super._ready()
