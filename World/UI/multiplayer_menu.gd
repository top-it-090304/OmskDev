extends Control

@onready var ip_panel: VBoxContainer = $Panel/VBoxContainer/IPPanel
@onready var ip_input: LineEdit = $Panel/VBoxContainer/IPPanel/IPInput

func _ready() -> void:
	ip_panel.hide()

func _on_host_pressed() -> void:
	NetworkManager.host_game()
	get_tree().change_scene_to_file("res://World/UI/lobby.tscn")

func _on_join_pressed() -> void:
	ip_panel.visible = not ip_panel.visible

func _on_connect_pressed() -> void:
	var address = ip_input.text.strip_edges()
	if address == "":
		address = "127.0.0.1"
	NetworkManager.join_game(address)
	get_tree().change_scene_to_file("res://World/UI/lobby.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://World/UI/menu.tscn")
