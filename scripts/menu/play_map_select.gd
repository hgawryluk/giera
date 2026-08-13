class_name PlayMapSelect
extends Control

const HOTSEAT_SETUP_SCENE := "res://scenes/menu/hotseat_setup.tscn"
const BATTLE_SCENE := "res://scenes/battle/battle.tscn"

@onready var game_session := get_node("/root/GameSession") as GameSessionState

func _ready() -> void:
	%NightForestButton.pressed.connect(_select_night_forest)
	%SoloTrailButton.pressed.connect(_select_solo_trail)
	%BackButton.pressed.connect(_back)

func _select_night_forest() -> void:
	game_session.selected_map_id = "builtin:forest"
	game_session.auto_start_first_person = false
	get_tree().change_scene_to_file(HOTSEAT_SETUP_SCENE)

func _select_solo_trail() -> void:
	game_session.configure_solo_exploration(&"warrior")
	game_session.selected_map_id = "builtin:solo_fpp"
	get_tree().change_scene_to_file(BATTLE_SCENE)

func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
