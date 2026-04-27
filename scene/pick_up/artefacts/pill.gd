extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Pill"
	artefact_description = "+10 к скорости"
	speed_bonus = 10
	super._ready()
