extends SceneTree

func _init() -> void:
	var player_ps := load("res://scene/game_objects/player/player.tscn") as PackedScene
	var art_ps := load("res://scene/pick_up/artefacts/clock.tscn") as PackedScene
	var player := player_ps.instantiate()
	var art := art_ps.instantiate()
	var root := Node2D.new()
	root.add_child(player)
	root.add_child(art)
	player.global_position = Vector2.ZERO
	art.global_position = Vector2.ZERO
	var hitbox := player.get_node("hitbox") as Area2D
	var area := art.get_node("Area2D") as Area2D
	var body := player as CharacterBody2D
	print("hitbox layer=", hitbox.collision_layer, " mask=", hitbox.collision_mask)
	print("artefact area layer=", area.collision_layer, " mask=", area.collision_mask)
	print("player body layer=", body.collision_layer)
	print("area sees hitbox: ", (area.collision_mask & hitbox.collision_layer) != 0)
	print("area sees body: ", (area.collision_mask & body.collision_layer) != 0)
	print("hitbox monitorable=", hitbox.monitorable, " area monitoring=", area.monitoring)
	var fired_area := false
	var fired_body := false
	area.area_entered.connect(func(_a): fired_area = true)
	area.body_entered.connect(func(_b): fired_body = true)
	root.add_child.call_deferred(root)
	# Can't easily add to tree in _init without main loop - quit with layer math only
	quit()
