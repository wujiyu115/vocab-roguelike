# scripts/game/game.gd（初始版本）
extends Node2D

@onready var player: CharacterBody2D = $Entities/Player
@onready var background: Sprite2D = $Background

func _ready():
	player.position = Vector2(GameManager.W / 2, GameManager.H / 2 + 120)
	_load_background()

func _load_background() -> void:
	GameManager.room = 1
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
			KEY_E: player.try_interact([], [])
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var aim := (get_global_mouse_position() - player.position).normalized()
		player.fire_held_meaning(aim)
