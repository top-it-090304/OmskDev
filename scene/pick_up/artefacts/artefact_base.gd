extends Node2D
class_name ArtefactBase

@export var artefact_name: String = "Artefact"
@export var artefact_icon: Texture2D
@export var artefact_description: String = "Описание артефакта"

signal picked_up(artefact: ArtefactBase)

func _ready():
	if has_node("Sprite2D"):
		var sprite := get_node("Sprite2D") as Sprite2D
		sprite.scale = Vector2(0.22, 0.22)
		if not artefact_icon and sprite.texture:
			artefact_icon = sprite.texture

func _on_area_entered(area: Area2D) -> void:
	if area.get_parent().is_in_group("player"):
		pickup(area.get_parent())

func pickup(player: Node) -> void:
	apply_effect(player)
	var backpack = get_tree().get_first_node_in_group("backpack")
	if backpack and backpack.has_method("add_artefact"):
		backpack.add_artefact(self)
	AudioManager.play_sfx("игрок_артефакт")
	mark_room_as_collected()
	queue_free()

func mark_room_as_collected() -> void:
	var map_manager = get_tree().get_first_node_in_group("map_manager")
	if map_manager:
		var room_pos = map_manager.get("current_room_grid_pos")
		if room_pos:
			SaveSystem.mark_treasure_collected(room_pos)

func apply_effect(player: Node) -> void:
	pass
