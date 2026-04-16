extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Old Book"
	artefact_description = "+1 скорости за уровень"
	speed_per_level_bonus = 1
	super._ready()
