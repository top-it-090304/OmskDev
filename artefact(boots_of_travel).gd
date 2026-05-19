extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

## Та же сеть/сумка, что у остальных артефактов (раньше был отдельный скрипт без кооп-RPC).


func _ready() -> void:
	artefact_name = "Boots of Travel"
	artefact_description = "+70 к скорости"
	speed_bonus = 70
	super._ready()
