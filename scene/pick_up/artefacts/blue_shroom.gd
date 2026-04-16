extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Blue Shroom"
	artefact_description = "+20 скорости, +30 здоровья"
	speed_bonus = 20
	health_bonus = 30
	super._ready()
