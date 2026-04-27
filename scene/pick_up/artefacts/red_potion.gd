extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Red Potion"
	artefact_description = "+50 здоровья, +2 урона"
	health_bonus = 50
	damage_bonus = 2
	super._ready()
