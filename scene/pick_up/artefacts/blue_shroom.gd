extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Blue Shroom"
	artefact_description = "Магический гриб\n+20 к скорости\n+30 к здоровью\n+5% вампиризм"
	speed_bonus = 20
	health_bonus = 30
	lifesteal_bonus = 0.05
	super._ready()
