extends Control

@onready var level_label = $LevelLabel

func _ready() -> void:
	update_level_display()
	# Подключаемся к сигналу изменения констант
	if not GameConstants.constants_changed.is_connected(_on_constants_changed):
		GameConstants.constants_changed.connect(_on_constants_changed)

func _process(_delta: float) -> void:
	# Обновляем каждый кадр для гарантии актуальности
	update_level_display()

func update_level_display() -> void:
	if level_label:
		level_label.text = "%d" % GameConstants.ENEMY_LEVEL

func _on_constants_changed() -> void:
	update_level_display()
