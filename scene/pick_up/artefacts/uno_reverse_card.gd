extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Uno Reverse Card"
	artefact_description = "x1.5 ко всем характеристикам\n+50% к опыту\n+10% уклонения"
	super._ready()

func custom_effect() -> void:
	# Увеличиваем все текущие характеристики в 1.5 раза
	var health_increase = int(GameConstants.PLAYER_MAX_HEALTH * 0.5)
	var speed_increase = int(GameConstants.PLAYER_MAX_SPEED * 0.5)
	var damage_increase = int(GameConstants.PLAYER_ATTACK_DAMAGE * 0.5)

	GameConstants.PLAYER_MAX_HEALTH += health_increase
	GameConstants.PLAYER_MAX_SPEED += speed_increase
	GameConstants.PLAYER_ATTACK_DAMAGE += damage_increase

	stat_changes.append({"text": "+%d к здоровью (x1.5)" % health_increase, "color": Color(1, 0.5, 0.5)})
	stat_changes.append({"text": "+%d к скорости (x1.5)" % speed_increase, "color": Color(0.5, 1, 0.5)})
	stat_changes.append({"text": "+%d к урону (x1.5)" % damage_increase, "color": Color(1, 0.7, 0.3)})

	# Уклонение
	GameConstants.PLAYER_DODGE_CHANCE += 0.1
	stat_changes.append({"text": "+10% уклонения", "color": Color(0.5, 0.8, 1)})

	# Увеличиваем множитель опыта
	if not "PLAYER_EXP_MULTIPLIER_BONUS" in GameConstants:
		GameConstants.PLAYER_EXP_MULTIPLIER_BONUS = 1.0

	var current_multiplier = GameConstants.PLAYER_EXP_MULTIPLIER_BONUS
	var new_multiplier = current_multiplier * 1.5
	GameConstants.PLAYER_EXP_MULTIPLIER_BONUS = new_multiplier

	stat_changes.append({"text": "Множитель опыта: x%.1f" % new_multiplier, "color": Color(1, 0.84, 0)})

	print("  +", health_increase, " к здоровью (x1.5)")
	print("  +", speed_increase, " к скорости (x1.5)")
	print("  +", damage_increase, " к урону (x1.5)")
	print("  +10% уклонения")
	print("  Множитель опыта: x", new_multiplier)
