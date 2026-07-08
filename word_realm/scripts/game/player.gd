# scripts/game/player.gd
extends CharacterBody2D

signal fired(data: Dictionary)
signal picked_up(meaning: String)
signal interacted_chest(chest: Node)

const HERO_SHEET := preload("res://assets/sprites/hero_gun_actions.png")
const SHEET_COLS := 8
const SHEET_ROWS := 4
const DRAW_SIZE := 90.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var pickup_area: Area2D = $PickupArea
@onready var shield_sprite: Sprite2D = $ShieldSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var hp := 100.0
var max_hp := 100.0
var speed := 245.0
var dash_cooldown := 1.2
var dash_timer := 0.0
var throw_speed := 610.0
var pickup_range := 84.0
var defense := 0.0
var luck := 0.0
var invulnerable := 0.0
var speed_boost := 0.0
var shield_time := 0.0
var piercing_ink := false
var echo_scroll := false
var held_meaning := ""

var radius := 18.0
var facing := 0  # 0=down, 1=left, 2=right, 3=up
var last_move_dir := Vector2(0, 1)
var walk_anim_time := 0.0
var dash_anim_time := 0.0
var fire_anim_time := 0.0

# 移动端寻路目标
var move_target := Vector2.ZERO
var has_move_target := false

func _ready() -> void:
	add_to_group("player")
	_build_sprite_frames()

func _build_sprite_frames() -> void:
	var frames := SpriteFrames.new()
	var cw := HERO_SHEET.get_width() / SHEET_COLS
	var ch := HERO_SHEET.get_height() / SHEET_ROWS
	var dir_names := ["down", "left", "right", "up"]

	# frame layout per direction row: 0=idle, 1-4=walk, 5=dash, 6=fire, 7=hurt
	for dir_idx in range(4):
		var row := dir_idx
		var dir_name: String = dir_names[dir_idx]

		var idle_anim := "idle_" + dir_name
		frames.add_animation(idle_anim)
		frames.set_animation_loop(idle_anim, false)
		frames.add_frame(idle_anim, _atlas_frame(cw, ch, row, 0))

		var walk_anim := "walk_" + dir_name
		frames.add_animation(walk_anim)
		frames.set_animation_loop(walk_anim, true)
		frames.set_animation_speed(walk_anim, 8.0)
		for col in range(1, 5):
			frames.add_frame(walk_anim, _atlas_frame(cw, ch, row, col))

		var dash_anim := "dash_" + dir_name
		frames.add_animation(dash_anim)
		frames.set_animation_loop(dash_anim, false)
		frames.add_frame(dash_anim, _atlas_frame(cw, ch, row, 5))

		var fire_anim := "fire_" + dir_name
		frames.add_animation(fire_anim)
		frames.set_animation_loop(fire_anim, false)
		frames.add_frame(fire_anim, _atlas_frame(cw, ch, row, 6))

	# remove default animation if it exists
	if frames.has_animation("default"):
		frames.remove_animation("default")

	animated_sprite.sprite_frames = frames
	animated_sprite.scale = Vector2(DRAW_SIZE / cw, DRAW_SIZE / ch)
	animated_sprite.position.y = -14

func _atlas_frame(cw: int, ch: int, row: int, col: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = HERO_SHEET
	atlas.region = Rect2(col * cw, row * ch, cw, ch)
	return atlas

func _physics_process(delta: float) -> void:
	_update_timers(delta)
	var input := _get_move_input()
	if input.length() > 0.05:
		last_move_dir = input
		walk_anim_time += delta
		_update_facing_from_direction(input)
	else:
		walk_anim_time = 0.0
	var current_speed := speed
	if speed_boost > 0:
		current_speed *= 1.35
	velocity = input * current_speed
	move_and_slide()
	position = position.clamp(Vector2(48, 78), Vector2(GameManager.W - 48, GameManager.H - 48))
	_update_animation()
	shield_sprite.visible = false
	queue_redraw()

func _update_timers(delta: float) -> void:
	if dash_timer > 0: dash_timer -= delta
	if invulnerable > 0: invulnerable -= delta
	if speed_boost > 0: speed_boost -= delta
	if shield_time > 0: shield_time -= delta
	if dash_anim_time > 0: dash_anim_time -= delta
	if fire_anim_time > 0: fire_anim_time -= delta

func _get_move_input() -> Vector2:
	if GameManager.is_mobile:
		return _get_mobile_move_input()
	var input := Vector2.ZERO
	if Input.is_action_pressed("move_up"): input.y -= 1
	if Input.is_action_pressed("move_down"): input.y += 1
	if Input.is_action_pressed("move_left"): input.x -= 1
	if Input.is_action_pressed("move_right"): input.x += 1
	return input.normalized()

func _get_mobile_move_input() -> Vector2:
	if not has_move_target:
		return Vector2.ZERO
	var to_target := move_target - position
	if to_target.length() < 8.0:
		has_move_target = false
		return Vector2.ZERO
	return to_target.normalized()

func set_move_target(target: Vector2) -> void:
	move_target = target
	has_move_target = true

func _update_facing_from_direction(dir: Vector2) -> void:
	if absf(dir.x) > absf(dir.y):
		facing = 1 if dir.x < 0 else 2
	else:
		facing = 3 if dir.y < 0 else 0

func _update_animation() -> void:
	var anim_name := "idle_down"
	var dir_names := ["down", "left", "right", "up"]
	if walk_anim_time > 0:
		anim_name = "walk_" + dir_names[facing]
	else:
		anim_name = "idle_" + dir_names[facing]
	if fire_anim_time > 0:
		anim_name = "fire_" + dir_names[facing]
	elif dash_anim_time > 0:
		anim_name = "dash_" + dir_names[facing]
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)

func try_dash() -> void:
	if dash_timer > 0:
		return
	var dir := _get_move_input()
	if dir.length() < 0.001:
		dir = last_move_dir
	if dir.length() < 0.001:
		dir = _facing_vector()
	position += dir * 128
	position = position.clamp(Vector2(48, 78), Vector2(GameManager.W - 48, GameManager.H - 48))
	dash_timer = dash_cooldown
	invulnerable = 0.28
	dash_anim_time = 0.22

func _facing_vector() -> Vector2:
	match facing:
		1: return Vector2(-1, 0)
		2: return Vector2(1, 0)
		3: return Vector2(0, -1)
		_: return Vector2(0, 1)

func try_interact(meanings: Array, chests: Array) -> void:
	var best: Node = null
	var best_dist := pickup_range
	for token in meanings:
		if not is_instance_valid(token):
			continue
		var d := position.distance_to(token.position)
		if d < best_dist:
			best = token
			best_dist = d
	if best != null:
		if held_meaning.length() > 0:
			drop_held_meaning(meanings)
		held_meaning = best.meaning
		picked_up.emit(held_meaning)
		best.queue_free()
		return
	for chest in chests:
		if not is_instance_valid(chest):
			continue
		if not chest.opened and position.distance_to(chest.position) < 70:
			chest.opened = true
			interacted_chest.emit(chest)
			return

func drop_held_meaning(_meanings: Array) -> void:
	if held_meaning.is_empty():
		return
	held_meaning = ""

func fire_held_meaning(aim_dir: Vector2, echo: bool = false) -> void:
	if held_meaning.is_empty() or aim_dir.length() < 0.001:
		return
	_update_facing_from_direction(aim_dir)
	var data := {
		"meaning": held_meaning,
		"position": position + aim_dir * 42 + Vector2(0, -8),
		"velocity": aim_dir * throw_speed,
		"piercing": piercing_ink,
		"universal": false,
	}
	fired.emit(data)
	fire_anim_time = 0.16
	if echo_scroll and not echo:
		var side := Vector2(-aim_dir.y, aim_dir.x)
		var echo_data := {
			"meaning": "回声",
			"position": position + aim_dir * 42 + Vector2(0, -8) + side * 11,
			"velocity": (aim_dir * 0.94 + side * 0.15).normalized() * (throw_speed * 0.95),
			"piercing": piercing_ink,
			"universal": true,
		}
		fired.emit(echo_data)
	held_meaning = ""

func take_damage(amount: float) -> void:
	if invulnerable > 0:
		return
	var actual := amount * (1.0 - defense)
	if shield_time > 0:
		actual *= 0.55
	hp -= actual
	invulnerable = 0.55

func get_player_data() -> Dictionary:
	return {
		"hp": hp, "max_hp": max_hp, "speed": speed,
		"dash_cooldown": dash_cooldown, "throw_speed": throw_speed,
		"pickup_range": pickup_range, "defense": defense, "luck": luck,
	}

func _draw() -> void:
	if shield_time > 0:
		draw_arc(Vector2.ZERO, radius + 10, 0, TAU, 32, Color(0.3, 0.6, 1.0, 0.45), 4.0)

func load_continue_state(data: Dictionary) -> void:
	hp = data.get("hp", 100.0)
	max_hp = data.get("max_hp", 100.0)
	speed = data.get("speed", 245.0)
	dash_cooldown = data.get("dash_cooldown", 1.2)
	throw_speed = data.get("throw_speed", 610.0)
	pickup_range = data.get("pickup_range", 84.0)
	defense = data.get("defense", 0.0)
	luck = data.get("luck", 0.0)
