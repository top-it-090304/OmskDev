extends Area2D

var direction := Vector2.RIGHT
var speed: float = GameConstants.ARROW_SPEED
var lifetime: float = 5.0
var shooter: Node = null

@export var max_distance: float = 432.0
@export var min_scale_ratio: float = 0.05

var _distance_traveled := 0.0
var _base_scale := Vector2.ONE

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
		global_position += direction * frame_distance
		_distance_traveled += frame_distance
		_update_distance_scale()
		if _distance_traveled >= max_distance:
			queue_free()


func _update_distance_scale() -> void:
	var progress := clampf(_distance_traveled / max_distance, 0.0, 1.0)
	var scale_ratio := maxf(min_scale_ratio, 1.0 - progress)
	scale = _base_scale * scale_ratio

func _on_body_entered(body: Node2D) -> void:
	_apply_hit(body)

func _on_area_entered(area: Area2D) -> void:
	var enemy: Node = area.get_parent() if area.get_parent() else area
	_apply_hit(enemy)

func _apply_hit(target: Node) -> void:
	if target == null or not target.is_in_group("enemys"):
		return
	if not target.has_method("take_damage"):
		return

	var dmg = GameConstants.PLAYER_ATTACK_DAMAGE
	var is_crit = false
	if is_instance_valid(shooter) and shooter.has_method("roll_attack_damage"):
		var roll: Dictionary = shooter.roll_attack_damage()
		dmg = int(roll.get("damage", dmg))
		is_crit = bool(roll.get("is_crit", false))
	elif randf() < GameConstants.PLAYER_CRIT_CHANCE:
		dmg = int(dmg * GameConstants.PLAYER_CRIT_MULTIPLIER)
		is_crit = true

	NetworkManager.apply_melee_damage_to_enemy_from_player(target, dmg)

	if GameConstants.SHOW_DAMAGE_NUMBERS and is_instance_valid(shooter) and shooter.has_method("_show_popup_at"):
		var popup_type := "crit" if is_crit else "damage"
		shooter._show_popup_at(popup_type, dmg, target.global_position)

	if is_instance_valid(shooter) and shooter.get("hit_particles"):
		var particles = shooter.hit_particles.instantiate()
		particles.global_position = target.global_position
		var world := shooter.get_tree().current_scene
		if world:
			world.add_child(particles)

	if GameConstants.PLAYER_LIFESTEAL > 0.0 and is_instance_valid(shooter) and shooter.has_method("heal"):
		var steal := int(dmg * GameConstants.PLAYER_LIFESTEAL)
		if steal > 0:
			shooter.heal(steal)

	queue_free()
