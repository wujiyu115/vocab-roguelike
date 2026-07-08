# scripts/game/chest.gd
extends Area2D

const ITEMS_SHEET := preload("res://assets/sprites/items_projectiles_chests.png")

var opened := false

func _ready() -> void:
	add_to_group("chests")
	SpriteUtils.set_sprite($Sprite2D, ITEMS_SHEET, 4, 4, 4, 58, 50)

func open() -> void:
	opened = true
	modulate = Color(0.5, 0.5, 0.5)
