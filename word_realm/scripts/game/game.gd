# scripts/game/game.gd
extends Node2D

const RoomGenerator := preload("res://scripts/game/room_generator.gd")

@onready var player: CharacterBody2D = $Entities/Player
@onready var background: Sprite2D = $Background

var room_generator := RoomGenerator.new()
var current_meanings: Array = []
var current_chests: Array = []

func _ready():
	player.position = Vector2(GameManager.W / 2, GameManager.H / 2 + 120)
	_start_room()

func _start_room() -> void:
	GameManager.room += 1
	_load_background()
	_clear_entities()
	var result := room_generator.generate_room($Entities, player.position)
	current_meanings = result.meanings
	current_chests = result.chests
	GameManager.message = "第 %d 间：%s" % [GameManager.room, GameManager.get_current_theme().name]

func _clear_entities() -> void:
	for child in $Entities.get_children():
		if child == player:
			continue
		child.queue_free()
	current_meanings.clear()
	current_chests.clear()

func _load_background() -> void:
	var theme_index := GameManager.get_theme_index()
	var bg_name := GameManager.background_names[theme_index]
	var tex := load("res://assets/backgrounds/" + bg_name)
	if tex:
		background.texture = tex

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.is_mobile:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE: player.try_dash()
			KEY_E: player.try_interact(current_meanings, current_chests)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var aim := (get_global_mouse_position() - player.position).normalized()
		player.fire_held_meaning(aim)
