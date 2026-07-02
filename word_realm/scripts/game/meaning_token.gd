# scripts/game/meaning_token.gd
extends Area2D

var meaning := ""
var correct_for_room := false
var glow_timer := 0.0

@onready var label: Label = $Label

func _ready() -> void:
	add_to_group("meaning_tokens")

func setup(text: String, correct: bool) -> void:
	meaning = text
	correct_for_room = correct
	$Label.text = text

func _process(delta: float) -> void:
	glow_timer += delta
	var pulse := 0.8 + sin(glow_timer * 3.0) * 0.2
	modulate.a = pulse
