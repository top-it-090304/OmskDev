extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Lime Juice"
	artefact_description = "+12 к скорости"
	speed_bonus = 12
	super._ready()
