extends Area2D

@export var speed: float = 520.0
@export var lifetime: float = 3.0
@export var damage: int = GameConstants.ENEMY_GOBLIN_RAIDER_ROCK_DAMAGE
@export var knockback: float = 520.0
@export var visual_radius: float = 12.0
@export var splash_radius: float = GameConstants.ENEMY_GOBLIN_RAIDER_ROCK_SPLASH_RADIUS
@export var splash_damage_min: int = GameConstants.ENEMY_GOBLIN_RAIDER_ROCK_SPLASH_DAMAGE_MIN
@export var splash_damage_max: int = GameConstants.ENEMY_GOBLIN_RAIDER_ROCK_SPLASH_DAMAGE_MAX

var direction := Vector2.RIGHT
var _hit := false
var _age := 0.0


func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 100
	_ensure_visible_visuals()
	if direction.length_squared() > 0.0:
		direction = direction.normalized()
		rotation = direction.angle()
	get_tree().create_timer(lifetime).timeout.connect(_on_lifetime_expired)


func _process(delta: float) -> void:
	_age += delta
	if direction == Vector2.ZERO:
		return
	global_position += direction * speed * delta
	rotation += 8.0 * delta


func _on_body_entered(body: Node2D) -> void:
	if _hit or body.is_in_group("enemys"):
		return
	if _age < 0.08 and not body.is_in_group("player"):
		return
	_hit = true
	var direct_target: Node = null
	if body.is_in_group("player"):
		direct_target = body
		NetworkManager.server_apply_damage_to_player_from_enemy(body, damage)
		NetworkManager.server_apply_knockback_to_player_from_enemy(body, global_position, knockback)
	_apply_splash_damage(direct_target)
	call_deferred("queue_free")


func _on_lifetime_expired() -> void:
	if is_instance_valid(self):
		if not _hit:
			_hit = true
			_apply_splash_damage(null)
		queue_free()


func _apply_splash_damage(direct_target: Node) -> void:
	var space := get_world_2d().direct_space_state
	if space == null:
		return
	var shape := CircleShape2D.new()
	shape.radius = splash_radius
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, global_position)
	params.collide_with_bodies = true
	params.collide_with_areas = true
	params.collision_mask = 2
	var damaged_players: Array[Node] = []
	if direct_target != null:
		damaged_players.append(direct_target)
	var min_damage := GameConstants.get_scaled_enemy_stat(splash_damage_min)
	var max_damage := GameConstants.get_scaled_enemy_stat(splash_damage_max)
	if max_damage < min_damage:
		var tmp := min_damage
		min_damage = max_damage
		max_damage = tmp
	for hit in space.intersect_shape(params, 16):
		var collider: Variant = hit.get("collider")
		if collider == null:
			continue
		var target := collider as Node
		if target is Area2D and target.get_parent() != null:
			target = target.get_parent()
		if target == null or not target.is_in_group("player") or damaged_players.has(target):
			continue
		var splash_damage := randi_range(min_damage, max_damage)
		NetworkManager.server_apply_damage_to_player_from_enemy(target, splash_damage)
		NetworkManager.server_apply_knockback_to_player_from_enemy(target, global_position, knockback * 0.65)
		damaged_players.append(target)


func _ensure_visible_visuals() -> void:
	var rock_visual := get_node_or_null("RockVisual") as Node2D
	if rock_visual != null:
		rock_visual.visible = true
		rock_visual.z_index = 2
		rock_visual.scale = Vector2(0.45, 0.45)

	var shadow := get_node_or_null("ShadowVisual") as Polygon2D
	if shadow != null:
		shadow.visible = true
		shadow.z_index = 0

	var fallback := get_node_or_null("FallbackVisual") as Polygon2D
	if fallback != null:
		fallback.visible = true
		fallback.z_index = 3
		fallback.color = Color(0.72, 0.55, 0.35, 1.0)
		fallback.polygon = _make_rock_polygon(visual_radius)

	var outline := get_node_or_null("OutlineVisual") as Polygon2D
	if outline == null:
		outline = Polygon2D.new()
		outline.name = "OutlineVisual"
		add_child(outline)
	outline.z_index = 2
	outline.color = Color(0.12, 0.08, 0.04, 0.9)
	outline.polygon = _make_rock_polygon(visual_radius + 3.0)
	move_child(outline, 0)

	var trail := get_node_or_null("TrailVisual") as Line2D
	if trail == null:
		trail = Line2D.new()
		trail.name = "TrailVisual"
		add_child(trail)
	trail.z_index = -1
	trail.width = 4.0
	trail.default_color = Color(0.35, 0.25, 0.15, 0.55)
	trail.points = PackedVector2Array([Vector2.ZERO, -direction.normalized() * 20.0])


func _make_rock_polygon(radius: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-0.85, -0.45) * radius,
		Vector2(-0.25, -0.95) * radius,
		Vector2(0.65, -0.75) * radius,
		Vector2(1.0, 0.0) * radius,
		Vector2(0.45, 0.85) * radius,
		Vector2(-0.55, 0.75) * radius,
		Vector2(-1.0, 0.15) * radius,
	])
