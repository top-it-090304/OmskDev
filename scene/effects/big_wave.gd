extends Area2D

@export var speed: float = 420.0
@export var max_distance: float = 480.0
@export var damage: int = 35

var direction := Vector2.RIGHT
var _distance_traveled := 0.0
var _hit_bodies: Array[Node] = []

@onready var anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer


func _ready() -> void:
	if direction.length_squared() > 0.0:
		direction = direction.normalized()
	else:
		direction = Vector2.RIGHT
	if anim != null:
		anim.animation_finished.connect(_on_animation_finished)
	if anim_player != null:
		anim_player.animation_finished.connect(_on_animation_player_finished)
	_play_direction_animation()


func _process(delta: float) -> void:
	if direction == Vector2.ZERO:
		return
	var step := speed * delta
	global_position += direction * step
	_distance_traveled += step
	if _distance_traveled >= max_distance:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if body in _hit_bodies:
		return
	_hit_bodies.append(body)
	if body.has_method("take_damage"):
		NetworkManager.server_apply_damage_to_player_from_enemy(body, damage)


func _on_animation_finished() -> void:
	queue_free()


func _on_animation_player_finished(_anim_name: StringName) -> void:
	queue_free()


func _play_direction_animation() -> void:
	var anim_name := "right"
	if abs(direction.x) > abs(direction.y):
		anim_name = "right" if direction.x >= 0.0 else "left"
	else:
		anim_name = "down" if direction.y >= 0.0 else "up"
	if anim_player != null and anim_player.has_animation(anim_name):
		anim_player.play(anim_name)
		return
	if anim != null and anim.sprite_frames != null and anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)
