extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "VHS Cassette"
	artefact_description = "+10 к здоровью, +1 к урону"
	health_bonus = 10
	damage_bonus = 1
	super._ready()
