# scripts/game/game.gd
extends Node2D

const RoomGenerator := preload("res://scripts/game/room_generator.gd")
const ENEMY_PROJECTILE_SCENE := preload("res://scenes/game/enemy_projectile.tscn")
const PROJECTILE_SCENE := preload("res://scenes/game/projectile.tscn")
const FLOATING_TEXT_SCENE := preload("res://scenes/game/floating_text.tscn")
const MEANING_TOKEN_SCENE := preload("res://scenes/game/meaning_token.tscn")
const DROP_ITEM_SCENE := preload("res://scenes/game/drop_item.tscn")
const MEMORY_BOOK_SCENE := preload("res://scenes/ui/memory_book.tscn")
const TILES_SHEET := preload("res://assets/sprites/theme_tiles_walls.png")

@onready var player: CharacterBody2D = $Entities/Player
@onready var background: Sprite2D = $Background
@onready var reward_panel: Control = $HUD/RewardPanel
@onready var hud: CanvasLayer = $HUD
@onready var pause_menu: Control = $UILayer/PauseMenu
@onready var game_over_screen: Control = $UILayer/GameOverScreen
@onready var touch_controls: CanvasLayer = $TouchControls

var room_generator := RoomGenerator.new()
var current_meanings: Array = []
var current_chests: Array = []
var current_monsters: Array = []
var memory_book: Control = null

func _ready():
	player.fired.connect(_on_player_fired)
	player.picked_up.connect(_on_player_picked_up)
	player.interacted_chest.connect(_on_chest_opened)
	reward_panel.reward_chosen.connect(_on_reward_chosen)
	player.position = Vector2(GameManager.W / 2, GameManager.H / 2 + 120)

	# HUD setup
	hud.setup(player)

	# Pause menu signals
	pause_menu.resumed.connect(_on_pause_resumed)
	pause_menu.quit_to_menu.connect(_quit_to_menu)

	# Game over screen signals
	game_over_screen.return_to_menu.connect(_quit_to_menu)

	# Memory book (instanced at runtime, added to UILayer)
	memory_book = MEMORY_BOOK_SCENE.instantiate()
	$UILayer.add_child(memory_book)

	# Touch controls setup (mobile)
	if GameManager.is_mobile:
		touch_controls.setup(player)
		touch_controls.move_to.connect(func(pos): player.set_move_target(pos))
		touch_controls.fire_drag.connect(func(dir): player.fire_held_meaning(dir))
		touch_controls.dash_pressed.connect(func(): player.try_dash())
		touch_controls.interact_pressed.connect(func(): player.try_interact(current_meanings, current_chests))
		touch_controls.pause_pressed.connect(func(): _toggle_pause())

	# Restore continue state if available
	var cs := SaveManager.get_continue_state()
	if not cs.is_empty() and SaveManager.has_continue():
		player.load_continue_state(cs)
		GameManager.piercing_ink_rooms = cs.get("piercing_ink_rooms", 0)
		GameManager.echo_scroll_rooms = cs.get("echo_scroll_rooms", 0)
		GameManager.speed_boost_rooms = cs.get("speed_boost_rooms", 0)
		GameManager.throw_boost_rooms = cs.get("throw_boost_rooms", 0)
		GameManager.dash_boost_rooms = cs.get("dash_boost_rooms", 0)
		GameManager.pickup_boost_rooms = cs.get("pickup_boost_rooms", 0)
		GameManager.temp_speed_bonus = cs.get("temp_speed_bonus", 0.0)
		GameManager.temp_throw_bonus = cs.get("temp_throw_bonus", 0.0)
		GameManager.temp_dash_bonus = cs.get("temp_dash_bonus", 0.0)
		GameManager.temp_pickup_bonus = cs.get("temp_pickup_bonus", 0.0)
		player.piercing_ink = GameManager.piercing_ink_rooms > 0
		player.echo_scroll = GameManager.echo_scroll_rooms > 0

	_start_room()

func _start_room() -> void:
	GameManager.room += 1
	# 进入新房间必须回到 PLAYING：清房时状态被切到 ROOM_CLEAR，
	# 否则第 2 间起 _physics_process / _unhandled_input 的守卫会挡掉
	# 碰撞掉血、拾取、开火等全部玩法逻辑。
	GameManager.change_state(GameManager.State.PLAYING)
	_advance_room_powerups()
	_load_background()
	_clear_entities()
	GameManager.room_time = 0.0
	GameManager.correct_hits = 0
	GameManager.wrong_hits = 0
	GameManager.collisions = 0
	var result := room_generator.generate_room($Entities, player.position)
	for entry in result.word_entries:
		GameManager.run_words.append(entry)
	current_meanings = result.meanings
	current_chests = result.chests
	current_monsters = result.monsters
	for monster in current_monsters:
		monster.died.connect(_on_monster_died)
		monster.shot.connect(_on_monster_shot)
	GameManager.message = "第 %d 间：%s" % [GameManager.room, GameManager.get_current_theme().name]
	SaveManager.save_continue_state(player.get_player_data())

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
	var bg_name: String = GameManager.background_names[theme_index]
	var tex := load("res://assets/backgrounds/" + bg_name)
	if tex:
		background.texture = tex
	_build_walls(theme_index)

func _build_walls(theme_index: int) -> void:
	var walls_node: Node2D = $Walls
	for child in walls_node.get_children():
		child.queue_free()

	var wall_tex := SpriteUtils.atlas_cell(TILES_SHEET, 4, 4, 8 + theme_index)
	var tw := wall_tex.get_width()
	var th := wall_tex.get_height()

	# top wall strip (height 58)
	var top_h := 58
	var x := 0
	while x < GameManager.W:
		var spr := Sprite2D.new()
		spr.texture = wall_tex
		spr.centered = false
		spr.position = Vector2(x, 0)
		spr.scale = Vector2(minf(1.0, float(GameManager.W - x) / tw), float(top_h) / th)
		walls_node.add_child(spr)
		x += tw

	# bottom wall strip (height 30)
	var bot_y := GameManager.H - 30
	x = 0
	while x < GameManager.W:
		var spr := Sprite2D.new()
		spr.texture = wall_tex
		spr.centered = false
		spr.position = Vector2(x, bot_y)
		spr.scale = Vector2(minf(1.0, float(GameManager.W - x) / tw), 30.0 / th)
		walls_node.add_child(spr)
		x += tw

	# left wall strip (width 28)
	var y := top_h
	while y < bot_y:
		var spr := Sprite2D.new()
		spr.texture = wall_tex
		spr.centered = false
		spr.position = Vector2(0, y)
		spr.scale = Vector2(28.0 / tw, minf(1.0, float(bot_y - y) / th))
		walls_node.add_child(spr)
		y += th

	# right wall strip (width 28)
	y = top_h
	while y < bot_y:
		var spr := Sprite2D.new()
		spr.texture = wall_tex
		spr.centered = false
		spr.position = Vector2(GameManager.W - 28, y)
		spr.scale = Vector2(28.0 / tw, minf(1.0, float(bot_y - y) / th))
		walls_node.add_child(spr)
		y += th

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE: _toggle_pause()

	if GameManager.is_mobile:
		return
	if GameManager.current_state != GameManager.State.PLAYING:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_TAB: _toggle_memory_book()
			KEY_SPACE: player.try_dash()
			KEY_E: player.try_interact(current_meanings, current_chests)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var aim := (get_global_mouse_position() - player.position).normalized()
		player.fire_held_meaning(aim)

func _physics_process(delta: float) -> void:
	if GameManager.current_state != GameManager.State.PLAYING:
		return
	GameManager.room_time += delta
	# Check player death
	if player and is_instance_valid(player) and player.hp <= 0:
		_on_player_died()
		return
	_check_monster_collisions()
	_check_enemy_projectile_hits()

# --- Pause system ---

func _toggle_pause() -> void:
	if GameManager.current_state == GameManager.State.PLAYING:
		GameManager.change_state(GameManager.State.PAUSED)
		get_tree().paused = true
		pause_menu.visible = true
	elif GameManager.current_state == GameManager.State.PAUSED:
		_on_pause_resumed()

func _on_pause_resumed() -> void:
	GameManager.change_state(GameManager.State.PLAYING)
	get_tree().paused = false
	pause_menu.visible = false

func _toggle_memory_book() -> void:
	if memory_book:
		memory_book.toggle()

# --- Window / platform notifications ---

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if GameManager.current_state in [GameManager.State.PLAYING, GameManager.State.ROOM_CLEAR, GameManager.State.PAUSED]:
			SaveManager.save_continue_state(player.get_player_data())
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_toggle_pause()

# --- Game over / win ---

func _on_player_died() -> void:
	for monster in current_monsters:
		if is_instance_valid(monster):
			monster.entry.death_count += 1
	GameManager.change_state(GameManager.State.GAME_OVER)
	SaveManager.save_data.best_room = maxi(SaveManager.save_data.best_room, GameManager.room)
	SaveManager.clear_continue()
	SaveManager.save_game()
	var msg := "你在第 %d 间倒下了。共学习 %d 个单词。" % [GameManager.room, GameManager.run_words.size()]
	game_over_screen.show_screen("游戏结束", msg, GameManager.run_words)

func _on_game_won() -> void:
	GameManager.change_state(GameManager.State.WIN)
	SaveManager.save_data.best_room = maxi(SaveManager.save_data.best_room, GameManager.room)
	SaveManager.clear_continue()
	SaveManager.save_game()
	var msg := "恭喜通关！你掌握了所有 %d 个单词！" % [GameManager.run_words.size()]
	game_over_screen.show_screen("通关", msg, GameManager.run_words)

func _quit_to_menu() -> void:
	get_tree().paused = false
	if GameManager.current_state in [GameManager.State.PLAYING, GameManager.State.PAUSED, GameManager.State.ROOM_CLEAR]:
		SaveManager.save_continue_state(player.get_player_data())
	GameManager.change_state(GameManager.State.MENU)
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")

# --- Monster collision & projectile checks ---

func _check_monster_collisions() -> void:
	for monster in current_monsters:
		if not is_instance_valid(monster):
			continue
		var dist := player.position.distance_to(monster.position)
		if dist < monster.radius + player.radius and player.invulnerable <= 0:
			var damage: float = 12.0 + monster.entry.difficulty * 1.8
			player.take_damage(damage)
			GameManager.collisions += 1
			var push: Vector2 = (player.position - monster.position).normalized()
			if push.length() < 0.001: push = Vector2(1, 0)
			player.position += push * 34

func _check_enemy_projectile_hits() -> void:
	for child in $Entities.get_children():
		if child is Area2D and child.get("is_enemy") == true:
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

# --- Drop item system ---

func _try_drop(monster: Node) -> void:
	if randf() < 0.16 + player.luck:
		var kind := randi_range(0, 6) as GameManager.DropKind
		if current_monsters.size() <= 1:
			_apply_drop(kind)
			_add_float("自动拾取：" + DropItem.DROP_NAMES.get(kind, "道具"), monster.position + Vector2(-26, -30), Color(1.0, 0.886, 0.459))
		else:
			var drop := DROP_ITEM_SCENE.instantiate()
			drop.setup(kind, monster.position)
			drop.body_entered.connect(_on_drop_collected.bind(drop))
			$Entities.add_child(drop)

func _on_drop_collected(body: Node, drop: Node) -> void:
	if body == player:
		_apply_drop(drop.kind)
		drop.queue_free()

func _apply_drop(kind: int) -> void:
	match kind:
		GameManager.DropKind.APPLE:
			player.hp = minf(player.max_hp, player.hp + player.max_hp * 0.3)
			_add_float("苹果 +HP", player.position + Vector2(0, -30), Color(0.627, 1.0, 0.682))
		GameManager.DropKind.COFFEE:
			player.speed_boost = 7.0
			_add_float("咖啡 加速", player.position + Vector2(0, -30), Color(0.918, 0.753, 0.494))
		GameManager.DropKind.SHIELD_POTION:
			player.shield_time = 10.0
			_add_float("护盾 10s", player.position + Vector2(0, -30), Color(0.486, 0.804, 1.0))
		GameManager.DropKind.INK:
			player.piercing_ink = true
			GameManager.piercing_ink_rooms = 3
			_add_float("穿透墨水 3间", player.position + Vector2(-30, -42), Color(0.737, 0.694, 1.0))
		GameManager.DropKind.BOOTS:
			_grant_speed_bonus(18.0, "风之靴 3间")
		GameManager.DropKind.FEATHER:
			_grant_dash_bonus(0.12, "轻羽 3间")
		GameManager.DropKind.GLOVES:
			_grant_pickup_bonus(18.0, "磁力手套 3间")

# --- Grant bonus helpers ---

func _grant_speed_bonus(amount: float, label: String) -> void:
	if GameManager.temp_speed_bonus <= 0:
		player.speed += amount
		GameManager.temp_speed_bonus = amount
	elif amount > GameManager.temp_speed_bonus:
		player.speed += amount - GameManager.temp_speed_bonus
		GameManager.temp_speed_bonus = amount
	GameManager.speed_boost_rooms = 3
	_add_float(label, player.position + Vector2(-30, -42), Color(0.624, 0.882, 1.0))

func _grant_throw_bonus(amount: float, label: String) -> void:
	if GameManager.temp_throw_bonus <= 0:
		player.throw_speed += amount
		GameManager.temp_throw_bonus = amount
	elif amount > GameManager.temp_throw_bonus:
		player.throw_speed += amount - GameManager.temp_throw_bonus
		GameManager.temp_throw_bonus = amount
	GameManager.throw_boost_rooms = 3
	_add_float(label, player.position + Vector2(-30, -42), Color(1.0, 0.886, 0.459))

func _grant_dash_bonus(amount: float, label: String) -> void:
	if GameManager.temp_dash_bonus <= 0:
		player.dash_cooldown = maxf(0.55, player.dash_cooldown - amount)
		GameManager.temp_dash_bonus = amount
	elif amount > GameManager.temp_dash_bonus:
		player.dash_cooldown = maxf(0.55, player.dash_cooldown - (amount - GameManager.temp_dash_bonus))
		GameManager.temp_dash_bonus = amount
	GameManager.dash_boost_rooms = 3
	_add_float(label, player.position + Vector2(-30, -42), Color(0.961, 0.961, 0.824))

func _grant_pickup_bonus(amount: float, label: String) -> void:
	if GameManager.temp_pickup_bonus <= 0:
		player.pickup_range += amount
		GameManager.temp_pickup_bonus = amount
	elif amount > GameManager.temp_pickup_bonus:
		player.pickup_range += amount - GameManager.temp_pickup_bonus
		GameManager.temp_pickup_bonus = amount
	GameManager.pickup_boost_rooms = 3
	_add_float(label, player.position + Vector2(-30, -42), Color(1.0, 0.780, 0.471))

# --- Chest system ---

func _on_chest_opened(_chest: Node) -> void:
	var choice := randi_range(0, 2)
	match choice:
		0: _grant_speed_bonus(22.0, "宝箱：移速 3间")
		1: _grant_throw_bonus(90.0, "宝箱：弹速 3间")
		2:
			player.echo_scroll = true
			GameManager.echo_scroll_rooms = 3
			_add_float("宝箱：回声卷轴 3间", player.position + Vector2(-30, -42), Color(1.0, 0.886, 0.459))

# --- Reward card system ---

func _on_reward_chosen(card: Dictionary) -> void:
	_apply_reward(card)
	GameManager.change_state(GameManager.State.PLAYING)

func _apply_reward(card: Dictionary) -> void:
	match card.kind:
		GameManager.RewardKind.SURVIVAL:
			var gain: float = player.max_hp * card.value
			player.max_hp += gain
			player.hp = minf(player.max_hp, player.hp + gain)
		GameManager.RewardKind.MOVE_SPEED:
			player.speed += card.value
		GameManager.RewardKind.SHIELD:
			player.defense = minf(0.35, player.defense + card.value)
			player.shield_time = maxf(player.shield_time, 12.0)
		GameManager.RewardKind.CHEST_SPEED:
			_grant_speed_bonus(card.value, "奖励：移速 3间")
		GameManager.RewardKind.CHEST_THROW:
			_grant_throw_bonus(card.value, "奖励：弹速 3间")
		GameManager.RewardKind.CHEST_ECHO:
			player.echo_scroll = true
			GameManager.echo_scroll_rooms = 3

# --- Limited-time powerup decay (all 6 types) ---

func _advance_room_powerups() -> void:
	if GameManager.room <= 1:
		return

	# Speed boost
	if GameManager.speed_boost_rooms > 0:
		GameManager.speed_boost_rooms -= 1
		if GameManager.speed_boost_rooms == 0 and GameManager.temp_speed_bonus > 0:
			player.speed = maxf(120, player.speed - GameManager.temp_speed_bonus)
			GameManager.temp_speed_bonus = 0
			_add_float("速度道具失效", player.position + Vector2(-30, -36), Color(0.863, 0.863, 0.863))

	# Throw speed boost
	if GameManager.throw_boost_rooms > 0:
		GameManager.throw_boost_rooms -= 1
		if GameManager.throw_boost_rooms == 0 and GameManager.temp_throw_bonus > 0:
			player.throw_speed = maxf(400, player.throw_speed - GameManager.temp_throw_bonus)
			GameManager.temp_throw_bonus = 0
			_add_float("弹速道具失效", player.position + Vector2(-30, -36), Color(0.863, 0.863, 0.863))

	# Dash cooldown boost
	if GameManager.dash_boost_rooms > 0:
		GameManager.dash_boost_rooms -= 1
		if GameManager.dash_boost_rooms == 0 and GameManager.temp_dash_bonus > 0:
			player.dash_cooldown += GameManager.temp_dash_bonus
			GameManager.temp_dash_bonus = 0
			_add_float("冲刺道具失效", player.position + Vector2(-30, -36), Color(0.863, 0.863, 0.863))

	# Pickup range boost
	if GameManager.pickup_boost_rooms > 0:
		GameManager.pickup_boost_rooms -= 1
		if GameManager.pickup_boost_rooms == 0 and GameManager.temp_pickup_bonus > 0:
			player.pickup_range = maxf(50, player.pickup_range - GameManager.temp_pickup_bonus)
			GameManager.temp_pickup_bonus = 0
			_add_float("拾取道具失效", player.position + Vector2(-30, -36), Color(0.863, 0.863, 0.863))

	# Piercing ink
	if GameManager.piercing_ink_rooms > 0:
		GameManager.piercing_ink_rooms -= 1
		if GameManager.piercing_ink_rooms == 0:
			player.piercing_ink = false
			_add_float("穿透墨水失效", player.position + Vector2(-30, -36), Color(0.863, 0.863, 0.863))

	# Echo scroll
	if GameManager.echo_scroll_rooms > 0:
		GameManager.echo_scroll_rooms -= 1
		if GameManager.echo_scroll_rooms == 0:
			player.echo_scroll = false
			_add_float("回声卷轴失效", player.position + Vector2(-30, -36), Color(0.863, 0.863, 0.863))

# --- Room cleared & progression ---

func _on_room_cleared() -> void:
	var accuracy := 1.0 if (GameManager.correct_hits + GameManager.wrong_hits) == 0 else float(GameManager.correct_hits) / (GameManager.correct_hits + GameManager.wrong_hits)
	if accuracy >= 0.8 and GameManager.collisions <= 1 and GameManager.room_time < 80:
		GameManager.room_difficulty_scale = minf(1.35, GameManager.room_difficulty_scale + 0.08)
		GameManager.message = "清房漂亮：下一间更有挑战"
	elif accuracy < 0.5 or GameManager.collisions >= 4 or GameManager.room_time > 100:
		GameManager.room_difficulty_scale = maxf(0.74, GameManager.room_difficulty_scale - 0.12)
		player.hp = minf(player.max_hp, player.hp + 18)
		GameManager.message = "系统降压：下间减少压迫"
	else:
		GameManager.message = "房间清空。"

	var unique_count := 0
	var seen := {}
	for w in GameManager.run_words:
		if w.word not in seen:
			seen[w.word] = true
			unique_count += 1
	if unique_count >= WordBank.bank_words.size():
		_on_game_won()
		return

	GameManager.change_state(GameManager.State.ROOM_CLEAR)
	SaveManager.save_data.best_room = maxi(SaveManager.save_data.best_room, GameManager.room)
	SaveManager.save_game()

	# Show reward panel if monster count was > 3 (room >= 4)
	if GameManager.room >= 4:
		GameManager.change_state(GameManager.State.REWARD_CHOICE)
		reward_panel.show_rewards()
		await reward_panel.reward_chosen
		GameManager.change_state(GameManager.State.ROOM_CLEAR)

	# 2.2 秒后自动进入下一间
	await get_tree().create_timer(2.2).timeout
	_start_room()

# --- Projectile & word-matching core ---

func _on_player_fired(data: Dictionary) -> void:
	var proj := PROJECTILE_SCENE.instantiate()
	proj.setup(data)
	proj.area_entered.connect(_on_projectile_hit.bind(proj))
	proj.expired.connect(func(m): _return_meaning(m))
	$Entities.add_child(proj)

func _on_projectile_hit(area: Area2D, proj: Node) -> void:
	# Check if the area belongs to a monster's HitArea
	var monster := area.get_parent()
	if not monster is CharacterBody2D or not monster.has_method("take_hit"):
		return
	if monster in proj.hit_monsters:
		return
	proj.hit_monsters.append(monster)

	var result: Dictionary = monster.take_hit(proj.meaning, proj.universal)
	if result.correct:
		AudioManager.play("hit_correct")
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
	$Entities.add_child(ft)
	ft.show_text(text, pos, color)

func _return_meaning(meaning: String) -> void:
	if meaning.is_empty() or current_monsters.is_empty():
		return
	var correct: bool = current_monsters.any(func(m): return is_instance_valid(m) and m.entry.meaning == meaning)
	var token := MEANING_TOKEN_SCENE.instantiate()
	token.setup(meaning, correct)
	token.position = room_generator._random_free_position(20, player.position)
	$Entities.add_child(token)
	current_meanings.append(token)

func _on_player_picked_up(meaning: String) -> void:
	_add_float("拾取：" + meaning, player.position + Vector2(0, -30), Color(0.918, 0.937, 0.612))
