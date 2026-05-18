extends ColorRect

@export_range(0.0, 1.0, 0.01) var inner_radius: float = 0.24
@export_range(0.0, 1.5, 0.01) var outer_radius: float = 0.72
@export_range(0.0, 1.0, 0.01) var fog_strength: float = 0.34
@export var fog_color: Color = Color(0.03, 0.035, 0.055, 1.0)

var _shader_material: ShaderMaterial


func _ready() -> void:
	visible = false
	set_process(false)
	return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	_fit_to_viewport()
	_shader_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec2 center = vec2(0.5, 0.5);
uniform float inner_radius = 0.30;
uniform float outer_radius = 0.88;
uniform float fog_strength = 0.24;
uniform vec4 fog_color = vec4(0.03, 0.035, 0.055, 1.0);

void fragment() {
	float dist = distance(UV, center);
	float fog = smoothstep(inner_radius, outer_radius, dist) * fog_strength;
	COLOR = vec4(fog_color.rgb, fog);
}
"""
	_shader_material.shader = shader
	material = _shader_material
	_update_shader_params()


func _process(_delta: float) -> void:
	_fit_to_viewport()
	_update_shader_params()


func _update_shader_params() -> void:
	if _shader_material == null:
		return
	_shader_material.set_shader_parameter("center", _get_player_screen_center())
	_shader_material.set_shader_parameter("inner_radius", inner_radius)
	_shader_material.set_shader_parameter("outer_radius", outer_radius)
	_shader_material.set_shader_parameter("fog_strength", fog_strength)
	_shader_material.set_shader_parameter("fog_color", fog_color)


func _fit_to_viewport() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	position = Vector2.ZERO
	size = viewport.get_visible_rect().size


func _get_player_screen_center() -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return Vector2(0.5, 0.5)
	var viewport_size := viewport.get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector2(0.5, 0.5)
	var player := get_tree().get_first_node_in_group("local_player") as Node2D
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D
	var camera := viewport.get_camera_2d()
	if player == null or camera == null:
		return Vector2(0.5, 0.5)
	var screen_pos := (player.global_position - camera.get_screen_center_position()) * camera.zoom + viewport_size * 0.5
	return Vector2(
		clampf(screen_pos.x / viewport_size.x, 0.0, 1.0),
		clampf(screen_pos.y / viewport_size.y, 0.0, 1.0)
	)
