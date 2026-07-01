# scripts/ui/pause_menu.gd
extends Control

signal resumed
signal quit_to_menu

func _ready():
	visible = false
	$VBoxContainer/ResumeButton.pressed.connect(func(): resumed.emit(); visible = false)
	$VBoxContainer/QuitButton.pressed.connect(func(): quit_to_menu.emit())
