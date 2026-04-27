extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Button"
	artefact_description = "+1 к урону"
	damage_bonus = 1
	super._ready()
