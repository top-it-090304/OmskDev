extends Node

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 3.0  # Интервал между спавнами в секундах
@export var max_enemies: int = 10  # Максимальное количество врагов на сцене
@export var spawn_distance: float = 500.0  # Расстояние от игрока для спавна

var spawn_timer: float = 0.0

func _ready():
	add_to_group("level")
	# Загружаем сцену врага, если не задана
	if enemy_scene == null:
		enemy_scene = load("res://scene/enemys/simple_enemy/enemy.tscn")

func _process(delta):
	spawn_timer += delta
	
	# Проверяем количество врагов на сцене
	var current_enemies = get_tree().get_nodes_in_group("enemy").size()
	
	# Если врагов меньше максимума и прошло достаточно времени, спавним нового
	if current_enemies < max_enemies and spawn_timer >= spawn_interval:
		spawn_enemy()
		spawn_timer = 0.0

func spawn_enemy():
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null or enemy_scene == null:
		return
	
	# Создаем экземпляр врага
	var enemy = enemy_scene.instantiate()
	add_child(enemy)
	
	# Генерируем случайную позицию вокруг игрока
	var angle = randf() * TAU  # Случайный угол от 0 до 2π
	var offset = Vector2(cos(angle), sin(angle)) * spawn_distance
	enemy.global_position = player.global_position + offset
