# scripts/game/chest.gd
extends Area2D

var opened := false

func _ready() -> void:
	add_to_group("chests")

func open() -> void:
	opened = true
	modulate = Color(0.5, 0.5, 0.5)
