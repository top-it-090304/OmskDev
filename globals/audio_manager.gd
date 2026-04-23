extends Node

# --- МУЗЫКА ---
# Замените null на load("res://music/музыка_исследования.ogg") когда добавите файлы
const MUSIC_EXPLORE = null  # load("res://music/музыка_исследования.ogg")
const MUSIC_COMBAT  = null  # load("res://music/музыка_боя.ogg")
const MUSIC_BOSS    = null  # load("res://music/музыка_босса.ogg")

# --- SFX ---
const SFX = {
	"игрок_атака":         null,  # load("res://music/sfx/игрок_атака.ogg")
	"игрок_урон":          null,  # load("res://music/sfx/игрок_урон.ogg")
	"игрок_смерть":        null,  # load("res://music/sfx/игрок_смерть.ogg")
	"игрок_левелап":       null,  # load("res://music/sfx/игрок_левелап.ogg")
	"игрок_зелье":         null,  # load("res://music/sfx/игрок_зелье.ogg")
	"игрок_артефакт":      null,  # load("res://music/sfx/игрок_артефакт.ogg")
	"враг_атака_ближний":  null,  # load("res://music/sfx/враг_атака_ближний.ogg")
	"враг_урон":           null,  # load("res://music/sfx/враг_урон.ogg")
	"враг_смерть":         null,  # load("res://music/sfx/враг_смерть.ogg")
	"враг_выстрел_стрела": null,  # load("res://music/sfx/враг_выстрел_стрела.ogg")
	"враг_полет_стрелы":   null,  # load("res://music/sfx/враг_полет_стрелы.ogg")
	"враг_яд_выстрел":     null,  # load("res://music/sfx/враг_яд_выстрел.ogg")
	"враг_яд_попадание":   null,  # load("res://music/sfx/враг_яд_попадание.ogg")
	"босс_атака_укус":     null,  # load("res://music/sfx/босс_атака_укус.ogg")
	"босс_атака_удар":     null,  # load("res://music/sfx/босс_атака_удар.ogg")
	"босс_смерть":         null,  # load("res://music/sfx/босс_смерть.ogg")
	"люк_открытие":        null,  # load("res://music/sfx/люк_открытие.ogg")
	"люк_переход":         null,  # load("res://music/sfx/люк_переход.ogg")
}

var _music_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _current_music: AudioStream = null
var _is_combat: bool = false

func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "SFX"
	add_child(_sfx_player)

	play_explore()

# --- МУЗЫКА ---

func play_explore() -> void:
	if _is_combat == false and _music_player.stream == MUSIC_EXPLORE:
		return
	_is_combat = false
	_crossfade(MUSIC_EXPLORE)

func play_combat() -> void:
	if _is_combat == true and _music_player.stream == MUSIC_COMBAT:
		return
	_is_combat = true
	_crossfade(MUSIC_COMBAT)

func play_boss() -> void:
	if _music_player.stream == MUSIC_BOSS:
		return
	_is_combat = true
	_crossfade(MUSIC_BOSS)

func _crossfade(new_stream: AudioStream) -> void:
	if new_stream == null or _music_player.stream == new_stream:
		return
	var tween = create_tween()
	tween.tween_property(_music_player, "volume_db", -40.0, 1.0)
	await tween.finished
	_music_player.stream = new_stream
	_music_player.play()
	var tween2 = create_tween()
	tween2.tween_property(_music_player, "volume_db", 0.0, 1.0)

# --- SFX ---

func play_sfx(name: String) -> void:
	var stream = SFX.get(name)
	if stream == null:
		return
	_sfx_player.stream = stream
	_sfx_player.play()
