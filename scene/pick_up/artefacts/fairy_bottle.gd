extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Fairy Bottle"
	artefact_description = "Магическая защита\n+50 к здоровью\n+10% вампиризм\n+5 к броне"
	health_bonus = 50
	lifesteal_bonus = 0.1
	armor_bonus = 5
	super._ready()
