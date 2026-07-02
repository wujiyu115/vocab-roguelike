# scripts/game/drop_item.gd
class_name DropItem
extends Area2D

var kind: int = GameManager.DropKind.APPLE
var life := 16.0

@onready var label: Label = $Label

const DROP_NAMES := {
	GameManager.DropKind.APPLE: "苹果",
	GameManager.DropKind.COFFEE: "咖啡",
	GameManager.DropKind.SHIELD_POTION: "护盾",
	GameManager.DropKind.INK: "穿透墨水",
	GameManager.DropKind.BOOTS: "风之靴",
	GameManager.DropKind.FEATHER: "轻羽",
	GameManager.DropKind.GLOVES: "磁力手套",
}

func setup(drop_kind: int, pos: Vector2) -> void:
	kind = drop_kind
	position = pos
	$Label.text = DROP_NAMES.get(kind, "道具")

func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0:
		queue_free()
