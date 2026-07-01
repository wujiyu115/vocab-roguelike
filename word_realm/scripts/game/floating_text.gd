# scripts/game/floating_text.gd
extends Label

func show_text(text: String, pos: Vector2, color: Color) -> void:
	self.text = text
	position = pos
	modulate = color
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 32, 1.35)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 1.35)
	tween.tween_callback(queue_free)
