extends Node2D
class_name ArtefactPickup

# Базовая информация
@export var artefact_name: String = "Artefact"
@export var artefact_icon: Texture2D
@export var artefact_description: String = "Описание"

# Эффекты (можно комбинировать)
@export_group("Stat Bonuses")
@export var speed_bonus: int = 0
@export var health_bonus: int = 0
@export var damage_bonus: int = 0
@export var armor_bonus: int = 0
@export var dodge_chance_bonus: float = 0.0  # 0.05 = 5%
@export var crit_chance_bonus: float = 0.0  # 0.1 = 10%
@export var crit_multiplier_bonus: float = 0.0  # 0.5 = +50% к множителю
@export var lifesteal_bonus: float = 0.0  # 0.1 = 10% вампиризм
@export var attack_speed_bonus: float = 0.0  # 0.1 = +10% скорости атаки
@export var health_per_level_bonus: int = 0
@export var speed_per_level_bonus: int = 0
@export var damage_per_level_bonus: int = 0

@export_group("Visual")
@export var pickup_sound: AudioStream
@export var glow_color: Color = Color(1, 1, 0, 0.5)
@export var artefact_particles: PackedScene

const ARTEFACT_POPUP = preload("res://scene/ui/artefact_popup.tscn")

var is_picked_up: bool = false
var stat_changes: Array = []
var _overlap_pickup_check_accum: float = 0.0


## В коопе клиент создаёт временный экземпляр без add_child — у него get_tree() == null.
func _main_scene_tree() -> SceneTree:
	if is_inside_tree():
		return get_tree()
	var ml := Engine.get_main_loop()
	return ml as SceneTree if ml is SceneTree else null


func _ready():
	# Автоматически получаем иконку из Sprite2D
	if not artefact_icon and has_node("Sprite2D"):
		var sprite = get_node("Sprite2D")
		if sprite.texture:
			artefact_icon = sprite.texture
		# Увеличиваем размер спрайта в 4 раза
		sprite.scale = Vector2(3.2, 3.2)

	# Добавляем свечение
	add_glow_effect()
	call_deferred("_try_pickup_overlapping_players")


func _physics_process(delta: float) -> void:
	if is_picked_up:
		return
	_overlap_pickup_check_accum += delta
	if _overlap_pickup_check_accum < 0.1:
		return
	_overlap_pickup_check_accum = 0.0
	_try_pickup_overlapping_players()

func add_glow_effect():
	if has_node("Sprite2D"):
		var sprite = get_node("Sprite2D")
		# Простая анимация покачивания
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(sprite, "position:y", -5, 1.0).set_trans(Tween.TRANS_SINE)
		tween.tween_property(sprite, "position:y", 0, 1.0).set_trans(Tween.TRANS_SINE)

func _on_area_2d_area_entered(area: Area2D) -> void:
	if is_picked_up:
		return

	var player := _player_from_overlap(area)
	if player != null:
		pickup(player)


func _try_pickup_overlapping_players() -> void:
	if is_picked_up or not has_node("Area2D"):
		return
	var pickup_area := get_node("Area2D") as Area2D
	for area in pickup_area.get_overlapping_areas():
		var player := _player_from_overlap(area)
		if player != null:
			pickup(player)
			return
	for body in pickup_area.get_overlapping_bodies():
		var player := _player_from_overlap(body)
		if player != null:
			pickup(player)
			return


func _player_from_overlap(overlap: Node) -> Node:
	if overlap == null:
		return null
	if overlap.is_in_group("player"):
		return overlap
	var parent := overlap.get_parent()
	if parent != null and parent.is_in_group("player"):
		return parent
	return null


func _can_this_machine_pickup_for_player(player: Node) -> bool:
	if player == null:
		return false
	var tree := _main_scene_tree()
	if tree == null:
		return false
	var mp := tree.get_multiplayer()
	if not mp.has_multiplayer_peer():
		return true
	var local_flag: Variant = player.get("is_local_player")
	if local_flag is bool:
		return bool(local_flag)
	if player.has_method("is_multiplayer_authority"):
		return player.is_multiplayer_authority()
	return true


func pickup(_player: Node) -> void:
	if is_picked_up:
		return
	var tree := _main_scene_tree()
	if tree == null:
		return
	var mp := tree.get_multiplayer()
	if mp.has_multiplayer_peer():
		# В коопе на хосте есть все игроки: чужой персонаж не должен триггерить подбор.
		if not _can_this_machine_pickup_for_player(_player):
			return
		var rid := _get_treasure_room_grid()
		var artefact_id := str(get_meta(&"_net_world_artefact_id", ""))
		if mp.is_server():
			server_run_pickup_effects(false)
			NetworkManager.rpc_client_mirror_artefact_pickup.rpc(scene_file_path, rid.x, rid.y, mp.get_unique_id(), artefact_id)
		else:
			is_picked_up = true
			visible = false
			if has_node("Area2D"):
				var area := get_node("Area2D") as Area2D
				area.set_deferred("monitoring", false)
			NetworkManager.rpc_request_artefact_pickup_from_client.rpc_id(
				NetworkManager.SERVER_ID,
				scene_file_path,
				rid.x,
				rid.y,
				mp.get_unique_id(),
				artefact_id
			)
		return
	server_run_pickup_effects(false)


func _get_treasure_room_grid() -> Vector2i:
	if has_meta("_treasure_room_grid"):
		return get_meta("_treasure_room_grid")
	var room = get_parent()
	if room != null and "grid_x" in room:
		return Vector2i(room.grid_x, room.grid_y)
	return Vector2i(-1, -1)


## Только мир: подбор клиентом обрабатывается на хосте без бонусов на машине хоста
func server_consume_world_only_for_remote_client_pickup() -> void:
	if is_picked_up:
		return
	is_picked_up = true
	if not scene_file_path.is_empty():
		GameConstants.remember_artefact_scene_path(scene_file_path)
	mark_room_as_collected()
	queue_free()


## quiet: без попапа/частиц (когда подбор обрабатывает хост по запросу клиента)
func server_run_pickup_effects(quiet: bool) -> void:
	if is_picked_up:
		return
	is_picked_up = true
	var picked_path := scene_file_path
	if not picked_path.is_empty():
		GameConstants.remember_artefact_scene_path(picked_path)
	stat_changes.clear()
	apply_effects()
	if not quiet and artefact_particles:
		var particles = artefact_particles.instantiate()
		particles.global_position = global_position
		var st := _main_scene_tree()
		if st != null and st.current_scene != null:
			st.current_scene.add_child(particles)
	if not quiet:
		show_stat_popup()
	add_to_backpack()
	mark_room_as_collected()
	if quiet:
		queue_free()
	else:
		play_pickup_animation()
	print("Подобран артефакт: ", artefact_name)

func apply_effects() -> void:
	# Базовые бонусы
	if speed_bonus != 0:
		GameConstants.PLAYER_MAX_SPEED += speed_bonus
		stat_changes.append({"text": "+%d к скорости" % speed_bonus, "color": Color(0.5, 1, 0.5)})
		print("  +", speed_bonus, " к скорости")

	if health_bonus != 0:
		GameConstants.PLAYER_MAX_HEALTH += health_bonus
		stat_changes.append({"text": "+%d к здоровью" % health_bonus, "color": Color(1, 0.5, 0.5)})
		print("  +", health_bonus, " к здоровью")

	if damage_bonus != 0:
		GameConstants.PLAYER_ATTACK_DAMAGE += damage_bonus
		stat_changes.append({"text": "+%d к урону" % damage_bonus, "color": Color(1, 0.7, 0.3)})
		print("  +", damage_bonus, " к урону")

	if armor_bonus != 0:
		GameConstants.PLAYER_ARMOR += armor_bonus
		stat_changes.append({"text": "+%d к броне" % armor_bonus, "color": Color(0.7, 0.7, 0.7)})
		print("  +", armor_bonus, " к броне")

	if dodge_chance_bonus != 0.0:
		GameConstants.PLAYER_DODGE_CHANCE += dodge_chance_bonus
		var percent = int(dodge_chance_bonus * 100)
		stat_changes.append({"text": "+%d%% шанс уклонения" % percent, "color": Color(0.5, 0.8, 1)})
		print("  +", percent, "% шанс уклонения")

	if crit_chance_bonus != 0.0:
		GameConstants.PLAYER_CRIT_CHANCE += crit_chance_bonus
		var percent = int(crit_chance_bonus * 100)
		stat_changes.append({"text": "+%d%% шанс крита" % percent, "color": Color(1, 1, 0.3)})
		print("  +", percent, "% шанс крита")

	if crit_multiplier_bonus != 0.0:
		GameConstants.PLAYER_CRIT_MULTIPLIER += crit_multiplier_bonus
		stat_changes.append({"text": "+%.1fx к криту" % crit_multiplier_bonus, "color": Color(1, 1, 0.3)})
		print("  +", crit_multiplier_bonus, "x к криту")

	if lifesteal_bonus != 0.0:
		GameConstants.PLAYER_LIFESTEAL += lifesteal_bonus
		var percent = int(lifesteal_bonus * 100)
		stat_changes.append({"text": "+%d%% вампиризм" % percent, "color": Color(0.8, 0.2, 0.2)})
		print("  +", percent, "% вампиризм")

	if attack_speed_bonus != 0.0:
		GameConstants.PLAYER_ATTACK_SPEED += attack_speed_bonus
		var percent = int(attack_speed_bonus * 100)
		stat_changes.append({"text": "+%d%% скорости атаки" % percent, "color": Color(1, 0.5, 0)})
		print("  +", percent, "% скорости атаки")

	# Бонусы за уровень
	if health_per_level_bonus != 0:
		GameConstants.PLAYER_HEALTH_PER_LEVEL += health_per_level_bonus
		stat_changes.append({"text": "+%d здоровья за уровень" % health_per_level_bonus, "color": Color(1, 0.5, 0.5)})
		print("  +", health_per_level_bonus, " здоровья за уровень")

	if speed_per_level_bonus != 0:
		GameConstants.PLAYER_SPEED_PER_LEVEL += speed_per_level_bonus
		stat_changes.append({"text": "+%d скорости за уровень" % speed_per_level_bonus, "color": Color(0.5, 1, 0.5)})
		print("  +", speed_per_level_bonus, " скорости за уровень")

	if damage_per_level_bonus != 0:
		GameConstants.PLAYER_DAMAGE_PER_LEVEL += damage_per_level_bonus
		stat_changes.append({"text": "+%d урона за уровень" % damage_per_level_bonus, "color": Color(1, 0.7, 0.3)})
		print("  +", damage_per_level_bonus, " урона за уровень")

	# Вызываем кастомный эффект
	custom_effect()

# Переопределяется в наследниках для уникальных эффектов
func custom_effect() -> void:
	pass

func add_to_backpack() -> void:
	var st := _main_scene_tree()
	if st == null:
		return
	var backpack = st.get_first_node_in_group("backpack")
	if not backpack and st.current_scene != null:
		var root = st.current_scene
		backpack = root.find_child("Backpack", true, false)

	if backpack and backpack.has_method("add_artefact"):
		backpack.add_artefact(self)

func play_pickup_animation() -> void:
	# Анимация подбора: увеличение и исчезновение
	var tween = create_tween()
	tween.set_parallel(true)

	if has_node("Sprite2D"):
		var sprite = get_node("Sprite2D")
		tween.tween_property(sprite, "scale", Vector2(2, 2), 0.3)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.3)

	tween.tween_property(self, "modulate:a", 0.0, 0.3)

	await tween.finished
	queue_free()

func show_stat_popup() -> void:
	if stat_changes.is_empty():
		print("ВНИМАНИЕ: stat_changes пуст, popup не будет показан")
		return

	print("Создаем popup для артефакта: ", artefact_name)
	var popup = ARTEFACT_POPUP.instantiate()

	var st := _main_scene_tree()
	if st == null:
		popup.queue_free()
		return

	# Ищем UI слой (CanvasLayer)
	var ui_layer = st.get_first_node_in_group("ui_layer")
	if not ui_layer and st.current_scene != null:
		ui_layer = st.current_scene.find_child("UI", true, false)

	if ui_layer:
		print("Добавляем popup в UI слой")
		ui_layer.add_child(popup)
	else:
		print("UI слой не найден, добавляем в root")
		st.root.add_child(popup)

	# Устанавливаем название артефакта
	popup.set_artefact_info(artefact_name, artefact_description)

	# Добавляем все изменения характеристик
	for change in stat_changes:
		popup.add_stat_line(change["text"], change["color"])
		print("  Добавлена строка в popup: ", change["text"])

func mark_room_as_collected() -> void:
	# Находим комнату, в которой находится артефакт
	var room = get_parent()
	if room and "grid_x" in room and "grid_y" in room:
		var room_pos = Vector2i(room.grid_x, room.grid_y)
		SaveSystem.mark_treasure_collected(room_pos)
		print("Комната ", room_pos, " отмечена как собранная")
