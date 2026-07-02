# scripts/game/projectile.gd
extends Area2D

signal expired(meaning: String)

const ITEMS_SHEET := preload("res://assets/sprites/items_projectiles_chests.png")

var meaning := ""
var vel := Vector2.ZERO
var life := 1.55
var piercing := false
var universal := false
var return_on_miss := true
var hit_monsters: Array[Node] = []

func setup(data: Dictionary) -> void:
	meaning = data.meaning
	position = data.position
	vel = data.velocity
	piercing = data.get("piercing", false)
	universal = data.get("universal", false)
	life = 1.55
	return_on_miss = not universal
	$Label.text = meaning if not universal else "回声"
	var idx := 2 if universal else 1
	SpriteUtils.set_sprite($Sprite2D, ITEMS_SHEET, 4, 4, idx, 34, 34)

func _physics_process(delta: float) -> void:
	position += vel * delta
	life -= delta
	if life <= 0 or position.x < -40 or position.x > GameManager.W + 40 or position.y < -40 or position.y > GameManager.H + 40:
		_on_expired()
		queue_free()

func _on_expired() -> void:
	if return_on_miss and meaning.length() > 0:
		expired.emit(meaning)
