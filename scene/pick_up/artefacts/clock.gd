extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Clock"
	artefact_description = "+1 урона за уровень"
	damage_per_level_bonus = 1
	super._ready()
