# scripts/game/enemy_projectile.gd
extends Area2D

const ITEMS_SHEET := preload("res://assets/sprites/items_projectiles_chests.png")

var is_enemy := true
var vel := Vector2.ZERO
var life := 3.2
var damage := 10.0

func setup(data: Dictionary) -> void:
	position = data.position
	vel = data.velocity
	life = 3.2
	damage = data.damage
	SpriteUtils.set_sprite($Sprite2D, ITEMS_SHEET, 4, 4, 3, 30, 30)

func _physics_process(delta: float) -> void:
	position += vel * delta
	life -= delta
	if life <= 0 or position.x < -30 or position.x > GameManager.W + 30 or position.y < -30 or position.y > GameManager.H + 30:
		queue_free()
