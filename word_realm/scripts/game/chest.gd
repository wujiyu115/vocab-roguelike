# scripts/game/chest.gd
extends Area2D

var opened := false

func open() -> void:
	opened = true
	modulate = Color(0.5, 0.5, 0.5)
