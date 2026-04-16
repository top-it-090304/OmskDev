extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Diamond"
	artefact_description = "+5 к урону"
	damage_bonus = 5
	super._ready()
