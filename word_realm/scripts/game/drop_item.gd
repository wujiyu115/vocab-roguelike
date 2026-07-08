# scripts/game/drop_item.gd
class_name DropItem
extends Area2D

const ITEMS_SHEET := preload("res://assets/sprites/items_projectiles_chests.png")

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

const DROP_SPRITE_INDEX := {
	GameManager.DropKind.APPLE: 6,
	GameManager.DropKind.COFFEE: 7,
	GameManager.DropKind.SHIELD_POTION: 8,
	GameManager.DropKind.INK: 9,
	GameManager.DropKind.BOOTS: 10,
	GameManager.DropKind.FEATHER: 11,
	GameManager.DropKind.GLOVES: 12,
}

func setup(drop_kind: int, pos: Vector2) -> void:
	kind = drop_kind
	position = pos
	$Label.text = DROP_NAMES.get(kind, "道具")
	var idx: int = DROP_SPRITE_INDEX.get(kind, 15)
	SpriteUtils.set_sprite($Sprite2D, ITEMS_SHEET, 4, 4, idx, 34, 34)

func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0:
		queue_free()
