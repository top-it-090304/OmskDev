extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Coffee Mug"
	artefact_description = "+30 к скорости"
	speed_bonus = 30
	super._ready()
