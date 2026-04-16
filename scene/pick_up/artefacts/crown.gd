extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Crown"
	artefact_description = "Королевская власть\n+3 здоровья за уровень\n+50 к здоровью"
	health_per_level_bonus = 3
	health_bonus = 50
	super._ready()
