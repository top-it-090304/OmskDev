extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Snow Ball"
	artefact_description = "Холодная защита\n+10 к здоровью\n+5 к скорости\n+2 к броне"
	health_bonus = 10
	speed_bonus = 5
	armor_bonus = 2
	super._ready()
