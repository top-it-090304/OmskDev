extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Golden Cup"
	artefact_description = "+2 ко всем характеристикам за уровень\n+20% к получаемому опыту"
	health_per_level_bonus = 2
	speed_per_level_bonus = 2
	damage_per_level_bonus = 1
	super._ready()

func custom_effect() -> void:
	# Увеличиваем множитель опыта
	if not "PLAYER_EXP_MULTIPLIER_BONUS" in GameConstants:
		GameConstants.PLAYER_EXP_MULTIPLIER_BONUS = 1.0

	var current_multiplier = GameConstants.PLAYER_EXP_MULTIPLIER_BONUS
	var new_multiplier = current_multiplier * 1.2
	GameConstants.PLAYER_EXP_MULTIPLIER_BONUS = new_multiplier

	# Добавляем в popup
	stat_changes.append({"text": "Множитель опыта: x%.1f" % new_multiplier, "color": Color(0.7, 0.7, 1.0)})
	print("  Множитель опыта: x", new_multiplier)
