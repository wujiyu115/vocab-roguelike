# scripts/game/monster.gd
extends CharacterBody2D

signal died(monster: Node)
signal shot(data: Dictionary)

@onready var sprite: Sprite2D = $Sprite2D
@onready var word_label: Label = $WordLabel
@onready var hp_bar: ProgressBar = $HpBar
@onready var shield_sprite: Sprite2D = $ShieldSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var entry: Dictionary = {}
var kind: int = GameManager.MonsterKind.WANDERER
var hp := 1.0
var max_hp := 1.0
var radius := 31.0
var think_timer := 0.0
var rage_timer := 0.0
var dash_windup := 0.0
var shoot_timer := 2.0
var shield_up := false
var from_mistake := false
var move_dir := Vector2.ZERO

func setup(word_entry: Dictionary, monster_kind: int, pos: Vector2) -> void:
	entry = word_entry
	kind = monster_kind
	position = pos
	radius = 31 + entry.difficulty * 1.8
	max_hp = 2.0 if (GameManager.room > 4 or entry.difficulty >= 4) else 1.0
	hp = max_hp
	shield_up = (kind == GameManager.MonsterKind.SHIELD)
	from_mistake = entry.wrong_count > entry.correct_count and randf() < 0.35
	if from_mistake:
		kind = GameManager.MonsterKind.GHOST

	var shape := CircleShape2D.new()
	shape.radius = radius
	collision_shape.shape = shape
	$HitArea/CollisionShape2D.shape = shape.duplicate()

	word_label.text = entry.word
	think_timer = randf() * 1.2
	shoot_timer = 1.4 + randf() * 2.3
	hp_bar.visible = max_hp >= 2

func _physics_process(delta: float) -> void:
	if rage_timer > 0:
		rage_timer -= delta
	var player := _get_player()
	if player == null:
		return
	var speed := 55.0 + GameManager.room * 3 + entry.difficulty * 8.0
	if kind == GameManager.MonsterKind.CHASER: speed += 28
	if kind == GameManager.MonsterKind.GHOST: speed += 38
	if rage_timer > 0: speed *= 1.8
	if GameManager.room_difficulty_scale < 0.95: speed *= 0.85
	if GameManager.room_difficulty_scale > 1.1: speed *= 1.12

	var to_player := (player.position - position).normalized()

	match kind:
		GameManager.MonsterKind.WANDERER, GameManager.MonsterKind.SHIELD:
			think_timer -= delta
			if think_timer <= 0:
				var angle := randf() * TAU
				move_dir = Vector2(cos(angle), sin(angle))
				think_timer = 0.8 + randf() * 1.4
			if position.distance_to(player.position) < 180:
				move_dir = (move_dir * 0.75 + to_player * 0.25).normalized()
		GameManager.MonsterKind.CHASER, GameManager.MonsterKind.GHOST:
			move_dir = (move_dir * 0.82 + to_player * 0.18).normalized()
		GameManager.MonsterKind.DASHER:
			if dash_windup > 0:
				dash_windup -= delta
				if dash_windup <= 0:
					move_dir = to_player * 4.2
			else:
				think_timer -= delta
				move_dir *= 0.94
				if think_timer <= 0 and position.distance_to(player.position) < 360:
					dash_windup = 0.55
					think_timer = 2.2
				elif move_dir.length() < 0.1:
					move_dir = to_player * 0.45

	velocity = move_dir * speed
	move_and_slide()
	sprite.flip_h = velocity.x < -0.05
	position = position.clamp(Vector2(48, 82), Vector2(GameManager.W - 48, GameManager.H - 52))

	# Collision damage is checked by game.gd in _physics_process
	# Elite shooting
	_update_shooting(delta, player)
	# Update visuals
	_update_visuals()

func _update_shooting(delta: float, player: Node2D) -> void:
	if not _is_elite():
		return
	shoot_timer -= delta
	var dist := position.distance_to(player.position)
	if shoot_timer > 0 or dist > 520 or dist < 70:
		return
	var dir := (player.position - position).normalized()
	var bullet_speed := 210.0 + GameManager.room * 8 + entry.difficulty * 12.0
	var data := {
		"position": position + dir * (radius + 12),
		"velocity": dir * bullet_speed,
		"damage": 9.0 + entry.difficulty * 1.6,
	}
	shot.emit(data)
	shoot_timer = maxf(1.25, 3.3 - GameManager.room * 0.08 - entry.difficulty * 0.08)

func _is_elite() -> bool:
	return max_hp >= 2 or kind == GameManager.MonsterKind.SHIELD or entry.difficulty >= 5

func take_hit(meaning: String, universal: bool) -> Dictionary:
	# Ref: WordRogue.cs:1866-1919 ResolveHit
	var correct := universal or meaning == entry.meaning
	if correct:
		GameManager.correct_hits += 1
		SaveManager.save_data.total_correct += 1
		if not universal:
			entry.correct_count += 1
			entry.mastery = mini(10, entry.mastery + 1)
		GameManager.combo += 1
		GameManager.streak_wrong = 0

		if shield_up:
			shield_up = false
			rage_timer = 0.6
			return {"hit": true, "killed": false, "correct": true, "shield_break": true}

		var damage := max_hp if max_hp < 2 else 1.0
		if GameManager.combo >= 3:
			damage += 1
		hp -= damage
		var killed := hp <= 0
		if killed:
			died.emit(self)
		return {"hit": true, "killed": killed, "correct": true, "shield_break": false, "damage": damage}
	else:
		GameManager.wrong_hits += 1
		SaveManager.save_data.total_wrong += 1
		entry.wrong_count += 1
		entry.mastery = maxi(0, entry.mastery - 1)
		GameManager.combo = 0
		GameManager.streak_wrong += 1
		rage_timer = 3.0
		hp -= 0.15
		if GameManager.streak_wrong >= 2:
			GameManager.room_difficulty_scale += 0.08
			GameManager.streak_wrong = 0
		return {"hit": true, "killed": false, "correct": false}

func _update_visuals() -> void:
	shield_sprite.visible = shield_up
	if max_hp >= 2:
		hp_bar.value = hp / max_hp
	if rage_timer > 0:
		modulate = Color(1.5, 0.6, 0.6) if fmod(rage_timer, 0.3) < 0.15 else Color.WHITE
	else:
		modulate = Color.WHITE

func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if not players.is_empty() else null
