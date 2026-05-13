extends Label

const HOLD_SEC := 2.0
const FADE_IN_SEC := 0.35
const FADE_OUT_SEC := 0.55
const FLOAT_UP_PX := 48.0

func _ready() -> void:
	add_to_group("floor_label")
	if GameConstants.has_signal("constants_changed"):
		GameConstants.constants_changed.connect(_on_constants_changed)
	_update_text()
	_play_intro_sequence()

func _on_constants_changed() -> void:
	_update_text()

func _update_text() -> void:
	text = "Floor %d" % GameConstants.CURRENT_FLOOR

func _play_intro_sequence() -> void:
	visible = true
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, FADE_IN_SEC)
	await tw.finished
	await get_tree().create_timer(HOLD_SEC).timeout
	tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, FADE_OUT_SEC)
	tw.tween_property(self, "position:y", position.y - FLOAT_UP_PX, FADE_OUT_SEC)
	await tw.finished
	visible = false
