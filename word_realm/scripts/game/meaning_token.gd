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
	_style_label()

func _style_label() -> void:
	var style := StyleBoxFlat.new()
	if correct_for_room:
		style.bg_color = Color(0.92, 0.88, 0.78, 0.9)
	else:
		style.bg_color = Color(0.75, 0.72, 0.68, 0.82)
	style.set_corner_radius_all(5)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	$Label.add_theme_stylebox_override("normal", style)
	$Label.add_theme_color_override("font_color", Color(0.15, 0.12, 0.08))
	$Label.add_theme_font_size_override("font_size", 12)

func _process(delta: float) -> void:
	glow_timer += delta
	var pulse := 0.85 + sin(glow_timer * 3.0) * 0.15
	modulate.a = pulse
