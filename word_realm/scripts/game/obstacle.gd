# scripts/game/obstacle.gd
extends StaticBody2D

const OBSTACLES_SHEET := preload("res://assets/sprites/theme_obstacles.png")

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

	var spr: Sprite2D = $Sprite2D
	var tex := SpriteUtils.atlas_cell(OBSTACLES_SHEET, 4, 2, sprite_index)
	spr.texture = tex
	var min_side := minf(rect.size.x, rect.size.y)
	var scale_factor := minf(2.85, maxf(1.45, 112.0 / min_side))
	if kind == "花草":
		scale_factor = minf(2.7, maxf(1.7, 92.0 / min_side))
	elif kind == "树木":
		scale_factor = minf(2.7, maxf(1.55, 104.0 / min_side))
	var slot_w := rect.size.x * scale_factor
	var slot_h := rect.size.y * scale_factor
	spr.scale = Vector2(slot_w / tex.get_width(), slot_h / tex.get_height())
	spr.position.y = -(slot_h - rect.size.y) * 0.4
