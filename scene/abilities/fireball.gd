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
		if _explode_on_sweep_hit(global_position, next_position):
			return
		global_position = next_position
		_distance_traveled += frame_distance
		_update_distance_scale()
		if _distance_traveled >= max_distance:
			_explode(global_position)


func _explode_on_sweep_hit(from_pos: Vector2, to_pos: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from_pos, to_pos)
	query.collision_mask = collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.exclude = [get_rid()]
	if shooter is CollisionObject2D:
		query.exclude.append((shooter as CollisionObject2D).get_rid())
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider: Object = hit.get("collider")
	if collider != null:
		var node := collider as Node
		if node != null and node.is_in_group("player"):
			return false
	global_position = hit.get("position", to_pos)
	_explode(global_position)
	return true


func _update_distance_scale() -> void:
	var progress := clampf(_distance_traveled / max_distance, 0.0, 1.0)
	var scale_ratio := maxf(min_scale_ratio, 1.0 - progress)
	scale = _base_scale * scale_ratio

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		return
	_explode(global_position)

func _on_area_entered(area: Area2D) -> void:
	var target: Node = area.get_parent() if area.get_parent() else area
	if target != shooter:
		_explode(global_position)

func _explode(pos: Vector2) -> void:
	if _exploded:
		return
	_exploded = true
	direction = Vector2.ZERO
	monitoring = false
	monitorable = false
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

	for target in get_tree().get_nodes_in_group("enemys"):
		if not is_instance_valid(target) or not (target is Node2D):
			continue
		if not target.has_method("take_damage"):
			continue
		if (target as Node2D).global_position.distance_squared_to(pos) > explosion_radius * explosion_radius:
			continue
		NetworkManager.apply_melee_damage_to_enemy_from_player(target, dmg)
		if GameConstants.SHOW_DAMAGE_NUMBERS and is_instance_valid(shooter) and shooter.has_method("_show_popup_at"):
			var popup_type := "crit" if is_crit else "damage"
			shooter._show_popup_at(popup_type, dmg, (target as Node2D).global_position)

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

	queue_free()


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
	tween.tween_property(circle, "scale", Vector2(1.25, 1.25), 0.12)
	tween.parallel().tween_property(circle, "color:a", 0.0, 0.12)
	tween.tween_callback(circle.queue_free)
