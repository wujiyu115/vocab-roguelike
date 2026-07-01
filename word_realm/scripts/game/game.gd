# scripts/game/game.gd
extends Node2D

const RoomGenerator := preload("res://scripts/game/room_generator.gd")
const ENEMY_PROJECTILE_SCENE := preload("res://scenes/game/enemy_projectile.tscn")
const PROJECTILE_SCENE := preload("res://scenes/game/projectile.tscn")
const FLOATING_TEXT_SCENE := preload("res://scenes/game/floating_text.tscn")
const MEANING_TOKEN_SCENE := preload("res://scenes/game/meaning_token.tscn")

@onready var player: CharacterBody2D = $Entities/Player
@onready var background: Sprite2D = $Background

var room_generator := RoomGenerator.new()
var current_meanings: Array = []
var current_chests: Array = []
var current_monsters: Array = []

func _ready():
	player.fired.connect(_on_player_fired)
	player.picked_up.connect(_on_player_picked_up)
	player.interacted_chest.connect(_on_chest_opened)
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

# --- Projectile & word-matching core ---

func _on_player_fired(data: Dictionary) -> void:
	var proj := PROJECTILE_SCENE.instantiate()
	proj.setup(data)
	proj.area_entered.connect(_on_projectile_hit.bind(proj))
	$Entities.add_child(proj)

func _on_projectile_hit(area: Area2D, proj: Node) -> void:
	# Check if the area belongs to a monster's HitArea
	var monster := area.get_parent()
	if not monster is CharacterBody2D or not monster.has_method("take_hit"):
		return
	if monster in proj.hit_monsters:
		return
	proj.hit_monsters.append(monster)

	var result := monster.take_hit(proj.meaning, proj.universal)
	if result.correct:
		if result.get("shield_break", false):
			_add_float("破盾" if not proj.universal else "回声破盾", monster.position + Vector2(0, -36), Color(0.478, 0.827, 1.0))
		elif result.get("killed", false):
			_add_float("记住 " + monster.entry.word, monster.position + Vector2(0, -58), Color.WHITE)
			_try_drop(monster)
		else:
			_add_float("正确：" + monster.entry.meaning if not proj.universal else "回声命中", monster.position + Vector2(0, -38), Color(0.596, 0.961, 0.706))

		if GameManager.combo >= 3:
			player.hp = minf(player.max_hp, player.hp + 4)
			_add_float("连击+" + str(GameManager.combo), player.position + Vector2(0, -34), Color(0.580, 1.0, 0.651))

		proj.return_on_miss = false
		if not proj.piercing:
			proj.queue_free()
	else:
		_add_float("错配！%s = %s" % [monster.entry.word, monster.entry.meaning], monster.position + Vector2(0, -38), Color(1.0, 0.824, 0.369))
		if GameManager.streak_wrong == 0:
			_add_float("房间躁动", Vector2(GameManager.W / 2 - 40, 120), Color(1.0, 0.510, 0.510))
		# Return meaning token to the ground
		_return_meaning(proj.meaning)
		proj.queue_free()

func _add_float(text: String, pos: Vector2, color: Color) -> void:
	var ft := FLOATING_TEXT_SCENE.instantiate()
	ft.show_text(text, pos, color)
	$Entities.add_child(ft)

func _return_meaning(meaning: String) -> void:
	if meaning.is_empty() or current_monsters.is_empty():
		return
	var correct := current_monsters.any(func(m): return is_instance_valid(m) and m.entry.meaning == meaning)
	var token := MEANING_TOKEN_SCENE.instantiate()
	token.setup(meaning, correct)
	token.position = room_generator._random_free_position(20, player.position)
	$Entities.add_child(token)
	current_meanings.append(token)

func _on_player_picked_up(meaning: String) -> void:
	_add_float("拾取：" + meaning, player.position + Vector2(0, -30), Color(0.918, 0.937, 0.612))

func _on_chest_opened(_chest: Node) -> void:
	# Chest reward logic will be implemented in Task 7
	pass

func _try_drop(_monster: Node) -> void:
	# Drop logic will be implemented in Task 7
	pass
