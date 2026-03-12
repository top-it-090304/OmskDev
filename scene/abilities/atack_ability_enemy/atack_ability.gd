class_name AttackAbility
extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func place_player():
	var player = get_tree().get_first_node_in_group("player") as Node2D
	match player.current_dir:
		player.Dir.UP: ability.get_node("Top").get_node("CollisionShape2D").disabled = false
		player.Dir.DOWN:ability.get_node("Bot").get_node("CollisionShape2D").disabled = false
		player.Dir.LEFT: ability.get_node("Left").get_node("CollisionShape2D").disabled = false
		player.Dir.RIGHT: ability.get_node("Right").get_node("CollisionShape2D").disabled = false
		
