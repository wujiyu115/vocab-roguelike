# scripts/game/room_generator.gd
extends RefCounted

const OBSTACLE_SCENE := preload("res://scenes/game/obstacle.tscn")
const MEANING_TOKEN_SCENE := preload("res://scenes/game/meaning_token.tscn")
const CHEST_SCENE := preload("res://scenes/game/chest.tscn")

const W := 1280
const H := 720

var obstacles: Array[Rect2] = []

func generate_room(parent: Node2D, player_pos: Vector2) -> Dictionary:
	obstacles.clear()
	var result := {"obstacles": [], "meanings": [], "chests": [], "word_entries": []}

	# 障碍物生成
	var theme_index := GameManager.get_theme_index()
	var target := 6 + randi_range(0, 3) + mini(3, GameManager.room / 4)
	if theme_index == 7:
		target += 2
	for attempt in range(target * 18):
		if result.obstacles.size() >= target:
			break
		var obs_data := _create_random_obstacle(theme_index)
		if not _can_place_obstacle(obs_data, player_pos):
			continue
		obstacles.append(obs_data.bounds)
		if not _room_navigation_valid(player_pos):
			obstacles.pop_back()
			continue
		var obstacle := OBSTACLE_SCENE.instantiate()
		obstacle.setup(obs_data.kind, theme_index, obs_data.bounds)
		parent.add_child(obstacle)
		result.obstacles.append(obstacle)

	# 选词和生成怪物入口数据
	var room := GameManager.room
	var target_count := 3 + mini(3, room / 2)
	if GameManager.room_difficulty_scale > 1.15:
		target_count += 1
	if GameManager.selected_mode >= 4 and room > 3:
		target_count += 1
	if GameManager.selected_mode >= 6 and room > 5:
		target_count += 1
	target_count = mini(6, target_count)
	target_count = mini(target_count, maxi(1, WordBank.bank_words.size()))

	var chosen := WordBank.pick_room_words(target_count)
	result.word_entries = chosen

	# 生成释义词块
	var used_meanings: Array[String] = []
	for entry in chosen:
		var needed := _required_hits(entry)
		for i in range(needed):
			var token := MEANING_TOKEN_SCENE.instantiate()
			token.setup(entry.meaning, true)
			token.position = _random_free_position(20, player_pos)
			parent.add_child(token)
			result.meanings.append(token)
		used_meanings.append(entry.meaning)

	# 干扰词块
	var distractor_count := maxi(5, chosen.size() + 3)
	var distractors := WordBank.get_distractors(distractor_count, used_meanings)
	for d in distractors:
		var token := MEANING_TOKEN_SCENE.instantiate()
		token.setup(d.meaning, false)
		token.position = _random_free_position(20, player_pos)
		parent.add_child(token)
		result.meanings.append(token)

	# 宝箱
	if randf() < 0.52:
		var chest := CHEST_SCENE.instantiate()
		chest.position = _random_free_position(42, player_pos)
		parent.add_child(chest)
		result.chests.append(chest)

	return result

func _create_random_obstacle(theme_index: int) -> Dictionary:
	var width := 72.0 + randi_range(0, 70)
	var height := 44.0 + randi_range(0, 58)
	var kind := "障碍"
	# 对照 WordRogue.cs:1246-1330 各主题障碍物尺寸
	match theme_index:
		0: width = 46.0 + randi_range(0, 30); height = 46.0 + randi_range(0, 30); kind = "树木"
		1: width = 96.0 + randi_range(0, 54); height = 42.0 + randi_range(0, 32); kind = "办公桌"
		2: width = 54.0 + randi_range(0, 32); height = 118.0 + randi_range(0, 52); kind = "书架"
		3: width = 108.0 + randi_range(0, 54); height = 48.0 + randi_range(0, 34); kind = "实验桌"
		4: width = 70.0 + randi_range(0, 42); height = 78.0 + randi_range(0, 54); kind = "写字楼"
		5: width = 58.0 + randi_range(0, 34); height = 118.0 + randi_range(0, 54); kind = "书架"
		6: width = 96.0 + randi_range(0, 42); height = 48.0 + randi_range(0, 24); kind = "汽车"
		7: width = 40.0 + randi_range(0, 34); height = 34.0 + randi_range(0, 30); kind = "花草"

	var x := 72.0 + randi_range(0, maxi(1, int(W - 144 - width)))
	var y := 98.0 + randi_range(0, maxi(1, int(H - 170 - height)))
	return {"bounds": Rect2(x, y, width, height), "kind": kind}

func _can_place_obstacle(data: Dictionary, player_pos: Vector2) -> bool:
	var r: Rect2 = data.bounds
	var padded := r.grow(30)
	if padded.position.y < 78 or padded.position.x < 42:
		return false
	if padded.end.x > W - 42 or padded.end.y > H - 48:
		return false
	if padded.has_point(player_pos):
		return false
	if _distance_point_to_rect(player_pos, r) < 150:
		return false
	var start_area := Rect2(W / 2.0 - 95, H / 2.0 + 95, 190, 150)
	var center_area := Rect2(W / 2.0 - 100, H / 2.0 - 80, 200, 160)
	if r.intersects(start_area) or r.intersects(center_area):
		return false
	for existing in obstacles:
		if padded.intersects(existing):
			return false
	return true

func _room_navigation_valid(player_pos: Vector2) -> bool:
	# 对照 WordRogue.cs:1351-1398 flood-fill 验证
	const CELL := 40
	var cols := (W - 96) / CELL
	var rows := (H - 140) / CELL
	var blocked := {}
	var total_walkable := 0
	var start := Vector2i(-1, -1)
	var start_dist := 999999.0

	for x in range(cols):
		for y in range(rows):
			var center := Vector2(48 + x * CELL + CELL / 2, 82 + y * CELL + CELL / 2)
			var is_blocked := _is_point_blocked(center, 18)
			blocked[Vector2i(x, y)] = is_blocked
			if not is_blocked:
				total_walkable += 1
				var dist := center.distance_to(player_pos)
				if dist < start_dist:
					start_dist = dist
					start = Vector2i(x, y)

	if total_walkable < cols * rows * 0.62 or start.x < 0:
		return false

	var seen := {}
	var queue: Array[Vector2i] = [start]
	seen[start] = true
	var visited := 0
	while not queue.is_empty():
		var p := queue.pop_front()
		visited += 1
		for offset in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var n := p + offset
			if n.x < 0 or n.y < 0 or n.x >= cols or n.y >= rows:
				continue
			if blocked.get(n, true) or seen.get(n, false):
				continue
			seen[n] = true
			queue.append(n)

	return visited >= total_walkable * 0.9

func _is_point_blocked(center: Vector2, radius: float) -> bool:
	if center.x - radius < 34 or center.x + radius > W - 34:
		return true
	if center.y - radius < 66 or center.y + radius > H - 34:
		return true
	for obs_rect in obstacles:
		if _circle_intersects_rect(center, radius, obs_rect):
			return true
	return false

func _circle_intersects_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	var closest_x := clampf(center.x, rect.position.x, rect.end.x)
	var closest_y := clampf(center.y, rect.position.y, rect.end.y)
	var dx := center.x - closest_x
	var dy := center.y - closest_y
	return dx * dx + dy * dy <= radius * radius

func _distance_point_to_rect(point: Vector2, rect: Rect2) -> float:
	var dx := maxf(maxf(rect.position.x - point.x, 0), point.x - rect.end.x)
	var dy := maxf(maxf(rect.position.y - point.y, 0), point.y - rect.end.y)
	return sqrt(dx * dx + dy * dy)

func _random_free_position(radius: float, player_pos: Vector2) -> Vector2:
	for attempt in range(80):
		var p := Vector2(100 + randi_range(0, W - 200), 110 + randi_range(0, H - 210))
		if p.distance_to(player_pos) < 130:
			continue
		if _is_point_blocked(p, radius):
			continue
		return p
	# 网格回退
	for x in range(90, W - 90, 44):
		for y in range(110, H - 80, 44):
			var p := Vector2(x, y)
			if not _is_point_blocked(p, radius) and p.distance_to(player_pos) >= 90:
				return p
	return player_pos

func _required_hits(entry: Dictionary) -> int:
	var max_hp := 2.0 if (GameManager.room > 4 or entry.difficulty >= 4) else 1.0
	var needed := ceili(max_hp)
	if entry.get("shield", false):
		needed += 1
	return maxi(1, needed)
