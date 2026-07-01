# scripts/game/game.gd
extends Node2D

const RoomGenerator := preload("res://scripts/game/room_generator.gd")
const ENEMY_PROJECTILE_SCENE := preload("res://scenes/game/enemy_projectile.tscn")

@onready var player: CharacterBody2D = $Entities/Player
@onready var background: Sprite2D = $Background

var room_generator := RoomGenerator.new()
var current_meanings: Array = []
var current_chests: Array = []
var current_monsters: Array = []

func _ready():
	player.position = Vector2(GameManager.W / 2, GameManager.H / 2 + 120)
	_start_room()

func _start_room() -> void:
	GameManager.room += 1
	_load_background()
	_clear_entities()
	var result := room_generator.generate_room($Entities, player.position)
	current_meanings = result.meanings
	current_chests = result.chests
	current_monsters = result.monsters
	for monster in current_monsters:
		monster.died.connect(_on_monster_died)
		monster.shot.connect(_on_monster_shot)
	GameManager.message = "第 %d 间：%s" % [GameManager.room, GameManager.get_current_theme().name]

func _clear_entities() -> void:
	for child in $Entities.get_children():
		if child == player:
			continue
		child.queue_free()
	current_meanings.clear()
	current_chests.clear()
	current_monsters.clear()

func _load_background() -> void:
	var theme_index := GameManager.get_theme_index()
	var bg_name := GameManager.background_names[theme_index]
	var tex := load("res://assets/backgrounds/" + bg_name)
	if tex:
		background.texture = tex

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.is_mobile:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE: player.try_dash()
			KEY_E: player.try_interact(current_meanings, current_chests)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var aim := (get_global_mouse_position() - player.position).normalized()
		player.fire_held_meaning(aim)

func _physics_process(delta: float) -> void:
	if GameManager.current_state != GameManager.State.PLAYING:
		return
	_check_monster_collisions()
	_check_enemy_projectile_hits()

func _check_monster_collisions() -> void:
	for monster in current_monsters:
		if not is_instance_valid(monster):
			continue
		var dist := player.position.distance_to(monster.position)
		if dist < monster.radius + player.radius and player.invulnerable <= 0:
			var damage := 12.0 + monster.entry.difficulty * 1.8
			player.take_damage(damage)
			GameManager.collisions += 1
			var push := (player.position - monster.position).normalized()
			if push.length() < 0.001: push = Vector2(1, 0)
			player.position += push * 34

func _check_enemy_projectile_hits() -> void:
	for child in $Entities.get_children():
		if child is Area2D and child.has_method("setup") and child.get("vel") != null:
			var dist := player.position.distance_to(child.position)
			if dist < player.radius + 6 and player.invulnerable <= 0:
				player.take_damage(child.damage)
				child.queue_free()

func _on_monster_died(monster: Node) -> void:
	current_monsters.erase(monster)
	monster.queue_free()
	if current_monsters.is_empty():
		_on_room_cleared()

func _on_monster_shot(data: Dictionary) -> void:
	var bullet := ENEMY_PROJECTILE_SCENE.instantiate()
	bullet.setup(data)
	$Entities.add_child(bullet)

func _on_room_cleared() -> void:
	GameManager.change_state(GameManager.State.ROOM_CLEAR)
	GameManager.message = "房间已清除！"
