# scripts/game/obstacle.gd
extends StaticBody2D

var obstacle_kind := ""
var sprite_index := 0
var bounds := Rect2()

func setup(kind: String, idx: int, rect: Rect2) -> void:
	obstacle_kind = kind
	sprite_index = idx
	bounds = rect
	position = rect.position + rect.size / 2
	var shape := RectangleShape2D.new()
	var inset := Vector2(minf(6.0, rect.size.x * 0.05), minf(6.0, rect.size.y * 0.05))
	shape.size = rect.size - inset * 2
	$CollisionShape2D.shape = shape
