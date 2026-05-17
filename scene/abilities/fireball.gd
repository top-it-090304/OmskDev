extends Area2D

var direction := Vector2.RIGHT
var speed: float = GameConstants.ARROW_SPEED
var lifetime: float = 5.0
var shooter: Node = null

@export var max_distance: float = 432.0
@export var min_scale_ratio: float = 0.05
@export var explosion_radius: float = 46.0
@export var explosion_damage_multiplier: float = 1.0

var _distance_traveled := 0.0
var _base_scale := Vector2.ONE
var _exploded := false

func _ready() -> void:
	if direction.length_squared() > 0.0:
		direction = direction.normalized()
		rotation = direction.angle()
	_base_scale = scale
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		queue_free()

func _process(delta: float) -> void:
	if direction != Vector2.ZERO:
		var frame_distance := speed * delta
		var next_position := global_position + direction * frame_distance
		if not _can_fly_to_position(next_position):
			queue_free()
			return
		if _explode_on_sweep_hit(global_position, next_position):
			return
		global_position = next_position
		_distance_traveled += frame_distance
		_update_distance_scale()
		if _distance_traveled >= max_distance:
			_explode(global_position)


func _can_fly_to_position(world_pos: Vector2) -> bool:
	var tree := get_tree()
	if tree == null:
		return true
	var map_manager := tree.get_first_node_in_group("map_manager")
	if map_manager == null or not map_manager.has_method("is_world_position_in_current_room"):
		return true
	return map_manager.is_world_position_in_current_room(world_pos, 8.0)


func _explode_on_sweep_hit(from_pos: Vector2, to_pos: Vector2) -> bool:
	var excluded: Array[RID] = [get_rid()]
	if shooter is CollisionObject2D:
		excluded.append((shooter as CollisionObject2D).get_rid())

	while true:
		var query := PhysicsRayQueryParameters2D.create(from_pos, to_pos)
		query.collision_mask = collision_mask
		query.collide_with_bodies = true
		query.collide_with_areas = true
		query.exclude = excluded
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return false

		var collider: Object = hit.get("collider")
		var collision_node := collider as Node
		if _should_ignore_collision(collision_node):
			if collider is CollisionObject2D:
				excluded.append((collider as CollisionObject2D).get_rid())
				continue
			return false

		global_position = hit.get("position", to_pos)
		_explode(global_position, _get_damage_target_from_collision(collision_node))
		return true
	return false


func _update_distance_scale() -> void:
	var progress := clampf(_distance_traveled / max_distance, 0.0, 1.0)
	var scale_ratio := maxf(min_scale_ratio, 1.0 - progress)
	scale = _base_scale * scale_ratio

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		return
	_explode(global_position, _get_damage_target_from_node(body))

func _on_area_entered(area: Area2D) -> void:
	var target := _get_damage_target_from_area(area)
	if target != shooter:
		if target == null:
			return
		_explode(global_position, target)

func _should_ignore_collision(node: Node) -> bool:
	if node == null:
		return false
	if node == shooter or node.is_in_group("player"):
		return true
	if node is Area2D:
		return _get_damage_target_from_area(node as Area2D) == null
	return false


func _get_damage_target_from_collision(node: Node) -> Node:
	if node is Area2D:
		return _get_damage_target_from_area(node as Area2D)
	return _get_damage_target_from_node(node)


func _get_damage_target_from_area(area: Area2D) -> Node:
	if area == null or String(area.name).to_lower() != "hitbox":
		return null
	var parent := area.get_parent()
	return _get_damage_target_from_node(parent if parent else area)


func _collect_explosion_targets(pos: Vector2) -> Array:
	var out: Array = []
	var space := get_world_2d().direct_space_state
	if space == null:
		return out
	var circle := CircleShape2D.new()
	circle.radius = explosion_radius
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = circle
	params.transform = Transform2D(0, pos)
	params.collide_with_bodies = true
	params.collide_with_areas = true
	params.collision_mask = collision_mask
	for hit in space.intersect_shape(params, 48):
		var collider: Variant = hit.get("collider")
		if collider == null:
			continue
		var target: Node = null
		if collider is Area2D:
			target = _get_damage_target_from_area(collider as Area2D)
		else:
			target = _get_damage_target_from_node(collider as Node)
		if target != null and not out.has(target):
			out.append(target)
	return out


func _get_damage_target_from_node(node: Node) -> Node:
	if node == null or node == shooter or node.is_in_group("player"):
		return null
	if node.has_method("take_damage") and (
		node.is_in_group("enemys") or node.is_in_group("enemies") or node.is_in_group("boss")
	):
		return node
	return null


func _explode(pos: Vector2, direct_target: Node = null) -> void:
	if _exploded:
		return
	_exploded = true
	direction = Vector2.ZERO
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	visible = false
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)

	var dmg = GameConstants.PLAYER_ATTACK_DAMAGE
	var is_crit = false
	if is_instance_valid(shooter) and shooter.has_method("roll_attack_damage"):
		var roll: Dictionary = shooter.roll_attack_damage()
		dmg = int(roll.get("damage", dmg))
		is_crit = bool(roll.get("is_crit", false))
	elif randf() < GameConstants.PLAYER_CRIT_CHANCE:
		dmg = int(dmg * GameConstants.PLAYER_CRIT_MULTIPLIER)
		is_crit = true
	dmg = maxi(1, int(dmg * explosion_damage_multiplier))

	_show_explosion_visual(pos)

	var damaged_targets: Array[Node] = []
	for target in _collect_explosion_targets(pos):
		if not is_instance_valid(target) or not target.has_method("take_damage"):
			continue
		NetworkManager.apply_melee_damage_to_enemy_from_player(target, dmg)
		damaged_targets.append(target)
		if GameConstants.SHOW_DAMAGE_NUMBERS and is_instance_valid(shooter) and shooter.has_method("_show_popup_at") and target is Node2D:
			var popup_type := "crit" if is_crit else "damage"
			shooter._show_popup_at(popup_type, dmg, (target as Node2D).global_position)

	if is_instance_valid(direct_target) and not damaged_targets.has(direct_target) and direct_target.has_method("take_damage"):
		NetworkManager.apply_melee_damage_to_enemy_from_player(direct_target, dmg)
		if GameConstants.SHOW_DAMAGE_NUMBERS and is_instance_valid(shooter) and shooter.has_method("_show_popup_at") and direct_target is Node2D:
			var popup_type := "crit" if is_crit else "damage"
			shooter._show_popup_at(popup_type, dmg, (direct_target as Node2D).global_position)

	if is_instance_valid(shooter) and shooter.get("hit_particles"):
		var particles_scene: PackedScene = shooter.hit_particles
		if particles_scene != null:
			var particles = particles_scene.instantiate()
			particles.global_position = pos
			var world := shooter.get_tree().current_scene
			if world:
				world.add_child(particles)

	if GameConstants.PLAYER_LIFESTEAL > 0.0 and is_instance_valid(shooter) and shooter.has_method("heal"):
		var steal := int(dmg * GameConstants.PLAYER_LIFESTEAL)
		if steal > 0:
			shooter.heal(steal)

	call_deferred("queue_free")


func _show_explosion_visual(pos: Vector2) -> void:
	var circle := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(24):
		var angle := TAU * float(i) / 24.0
		points.append(Vector2(cos(angle), sin(angle)) * explosion_radius)
	circle.polygon = points
	circle.color = Color(1.0, 0.45, 0.1, 0.55)
	circle.z_index = 20
	circle.global_position = pos
	var parent := get_parent()
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		return
	parent.add_child(circle)
	var tween := circle.create_tween()
	tween.tween_property(circle, "color:a", 0.0, 0.12)
	tween.tween_callback(circle.queue_free)
