extends Control

const PLAYER_SCENES = [
	preload("res://scene/game_objects/player/player.tscn"),
	preload("res://scene/game_objects/player2/player_2.tscn")
]

var current_player_index := 0

@onready var character_sprite := $Character
@onready var left_arrow := $TextureButton
@onready var right_arrow := $TextureButton2

func _ready() -> void:
	NetworkManager.reset_menu_navigation_flags()
	_wire_menu_buttons()
	left_arrow.pressed.connect(_on_left_arrow_pressed)
	right_arrow.pressed.connect(_on_right_arrow_pressed)
	current_player_index = SaveSystem.get_selected_player()
	_update_character_display()


func _wire_menu_buttons() -> void:
	for button in find_children("*", "TextureButton", true, false):
		_ignore_button_label_mouse(button as Control)


func _ignore_button_label_mouse(button: Control) -> void:
	if button == null:
		return
	for child in button.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_left_arrow_pressed() -> void:
	current_player_index = (current_player_index - 1) % PLAYER_SCENES.size()
	if current_player_index < 0:
		current_player_index = PLAYER_SCENES.size() - 1
	_update_character_display()
	SaveSystem.set_selected_player(current_player_index)

func _on_right_arrow_pressed() -> void:
	current_player_index = (current_player_index + 1) % PLAYER_SCENES.size()
	_update_character_display()
	SaveSystem.set_selected_player(current_player_index)

func _update_character_display() -> void:
	match current_player_index:
		0:
			character_sprite.animation = "Knight"
		1:
			character_sprite.animation = "Sorceress"

func get_selected_player_scene() -> PackedScene:
	return PLAYER_SCENES[current_player_index]
